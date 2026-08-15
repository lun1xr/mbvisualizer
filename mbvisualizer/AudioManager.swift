//
//  AudioManager.swift
//  mbvisualizer
//
//  Created by Stephen Paul on 8/10/26.
//

import CoreAudio
import Cocoa
import Accelerate
import AVFoundation
import SwiftUI
import Combine

final class AudioManager: ObservableObject {
    @Published var data: [Float] = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
    @AppStorage("BarCount") private var barCount: Int = 10
    @AppStorage("Cieling") private var cielingMultiplier: Double = 1.0
    @AppStorage("Decay") private var decay: Double = 0.1
    @AppStorage("Attack") private var attack: Double = 0.9
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioDeviceID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?
    private var tapFormat: AudioStreamBasicDescription?
    private let lock = NSLock()
    private var newDataAvailable: Bool = false
    private var lastFrameData: [Float] = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
    private var latestData: [Float] = []
    private var timer: Timer?
    private var aTable: [Float] = []

    init() {
        setupAudio()
        startTimer()
    }
    
    func setupAudio() {
        print("Audio Setup Started")
        let tapDescription = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
        tapDescription.uuid = UUID()
        tapDescription.muteBehavior = .unmuted
        tapDescription.isPrivate = true
        tapDescription.name = "mbvistap"
        let tapUID = tapDescription.uuid.uuidString

        var tapID = AudioObjectID(kAudioObjectUnknown)
        guard AudioHardwareCreateProcessTap(tapDescription, &tapID) == noErr,
              tapID != kAudioObjectUnknown else {
            print("Failed to create process tap")
            return
        }
        self.tapID = tapID

        var asbd = AudioStreamBasicDescription()
        var asbdSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        var formatAddress = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyFormat,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectGetPropertyData(tapID, &formatAddress, 0, nil, &asbdSize, &asbd) == noErr {
            tapFormat = asbd
        }

        var outputDevice = AudioDeviceID(0)
        var outputDeviceSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var outputAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &outputAddress,
            0,
            nil,
            &outputDeviceSize,
            &outputDevice
        ) == noErr, outputDevice != kAudioObjectUnknown else {
            print("Failed to get default output device")
            return
        }

        var deviceUIDRef: Unmanaged<CFString>?
        var uidSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        var uidAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(
            outputDevice,
            &uidAddress,
            0,
            nil,
            &uidSize,
            &deviceUIDRef
        ) == noErr, let deviceUIDRef else {
            print("Failed to get output device UID")
            return
        }
        let outputDeviceUID = deviceUIDRef.takeRetainedValue() as String

        let aggregateDesc: [String: Any] = [
            kAudioAggregateDeviceNameKey:        "mbvistapdevice",
            kAudioAggregateDeviceUIDKey:         "lun1xr.mbvisualizer.app.tap.\(UUID().uuidString)",
            kAudioAggregateDeviceMainSubDeviceKey: outputDeviceUID,
            kAudioAggregateDeviceIsPrivateKey:   true,
            kAudioAggregateDeviceIsStackedKey:   false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [
                [kAudioSubDeviceUIDKey: outputDeviceUID]
            ],
            kAudioAggregateDeviceTapListKey: [
                [
                    kAudioSubTapUIDKey:               tapUID,
                    kAudioSubTapDriftCompensationKey: true
                ]
            ],
        ]
        var aggregateID = AudioDeviceID(0)
        guard AudioHardwareCreateAggregateDevice(aggregateDesc as CFDictionary, &aggregateID) == noErr,
              aggregateID != kAudioObjectUnknown else {
            print("Failed to create aggregate device")
            return
        }
        self.aggregateID = aggregateID

        let ioQueue = DispatchQueue(label: "lun1xr.mbvisualizer.app.tap-io", qos: .userInteractive)
        var ioProcID: AudioDeviceIOProcID?
        guard AudioDeviceCreateIOProcIDWithBlock(&ioProcID, aggregateID, ioQueue, {
            [weak self] _, inInputData, _, _, _ in
            self?.handleIOProc(inInputData: inInputData)
        }) == noErr, let ioProcID else {
            print("Failed to create IOProc")
            return
        }
        self.ioProcID = ioProcID
        
        guard let sampleRate = tapFormat?.mSampleRate else {
            print("Failed to get sample rate")
            return
        }
        
        aTable = AudioProcesor.createAWFilterTable(Float(sampleRate))

        guard AudioDeviceStart(aggregateID, ioProcID) == noErr else {
            print("Failed to start aggregate device")
            return
        }
    }
    
    func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/90.0, repeats: true) { [weak self] _ in
            self?.updateUI()
        }
    }
    
    func updateUI() {
        lock.lock()
        guard newDataAvailable else {
            lock.unlock()
            return
        }
        let temp = latestData
        newDataAvailable = false
        lock.unlock()
        data = temp
    }

    func handleIOProc(inInputData: UnsafePointer<AudioBufferList>) {
        guard var asbd = tapFormat,
              let format = AVAudioFormat(streamDescription: &asbd),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: inInputData, deallocator: nil)
        else { print("Cast failed"); return }

        processAudioData(buffer: buffer)
    }
    
    let fftSetup = vDSP_DFT_zop_CreateSetup(nil, 512, vDSP_DFT_Direction.FORWARD)

    func processAudioData(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { print("No channel data"); return }
        let frames = buffer.frameLength
        guard frames >= 512 else { print("Frame count incorrect. Expected at least 512, actual: \(frames)"); return }
        if barCount == 0 || cielingMultiplier == 0 || attack == 0 || decay == 0 {
            return
        }
        let fftMagnitudes = AudioProcesor.dfft(data: channelData, aTable: aTable, setup: fftSetup!, cielingMultiplier: Float(cielingMultiplier), barCount: barCount)
        lock.lock()
        if latestData.count > 0 {
            lastFrameData = latestData
        }
        latestData = fftMagnitudes
        AudioProcesor.lerp(attack: Float(attack), decay: Float(decay), old: lastFrameData, new: &latestData)
        newDataAvailable = true
        lock.unlock()
    }
}
