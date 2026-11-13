//
//  audioprocesor.swift
//  mbvisualizer
//
//  Created by Stephen Paul on 8/9/26.
//

import Cocoa
import Accelerate
import SwiftUI

class AudioProcesor {
    private static let fftSize = 512
    private static let binCount = 256

    /// Hann window cached
    private static let hannWindow: [Float] = {
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        return window
    }()

    static func dfft_filtered(data: UnsafePointer<Float>, fTable: [Float], aTable: [Float], setup: OpaquePointer, cielingMultiplier: Float, biquad: inout vDSP.Biquad<Float>?, barCount: Int) -> [Float] {
        var realIn = [Float](repeating: 0, count: fftSize)
        var imagIn = [Float](repeating: 0, count: fftSize)

        var realOut = [Float](repeating: 0, count: fftSize)
        var imagOut = [Float](repeating: 0, count: fftSize)
        
        let dataBuffer = UnsafeBufferPointer(start: data, count: fftSize)
        var dataBufferArray = Array(dataBuffer)
        
        biquad?.apply(input: dataBufferArray, output: &dataBufferArray)
        
        // Window before FFT to reduce spectral leakage into low/high bins.
        vDSP_vmul(dataBufferArray, 1, hannWindow, 1, &realIn, 1, vDSP_Length(fftSize))

        vDSP_DFT_Execute(setup, &realIn, &imagIn, &realOut, &imagOut)

        var complex = DSPSplitComplex(realp: &realOut, imagp: &imagOut)
        var magnitudes = [Float](repeating: 0, count: binCount)
        vDSP_zvabs(&complex, 1, &magnitudes, 1, vDSP_Length(binCount))

        // Disp signal from first/last bin, drop for response prettiness
        magnitudes[0] = 0
        
        var aWeightedMagnitudes = [Float](repeating: 0, count: binCount)
        vDSP_vmul(&magnitudes, 1, aTable, 1, &aWeightedMagnitudes, 1, vDSP_Length(binCount))
        
        var normalizedMagnitudes = [Float](repeating: 0, count: binCount)
        var scalingFactor = Float((25.0 * (1 / cielingMultiplier)) / Float(binCount))
        vDSP_vsmul(&aWeightedMagnitudes, 1, &scalingFactor, &normalizedMagnitudes, 1, vDSP_Length(binCount))

        return logBinnedMagnitudes(normalizedMagnitudes, barCount: max(1, barCount))
    }
    
    /// This is inout for thematic reasons and because the code looks prettier
    static func lerp(attack: Float, decay: Float, old: [Float], new: inout [Float]) {
        if new.count != old.count {
            return
        }
        for i in new.indices {
            if new[i] > old[i] {
                new[i] = attack * new[i] + (1-attack) * old[i]
            } else {
                new[i] = decay * new[i] + (1-decay) * old[i]
            }
        }
        return
    }
    
    static func createFrequencyTable(_ sameplRate: Float) -> [Float] {
        var fTable = [Float](repeating: 0, count: binCount)
        for i in 0..<binCount {
            fTable[i] = Float(i) * sameplRate / Float(fftSize)
        }
        return fTable
    }
    
    /// Normalized by 1000 (precomputed)
    static func createAWFilterTable(_ fTable: [Float]) -> [Float] {
        let n: Float = 0.7943412 // R_A(1000) to float accuracy
        
        // A-weight function realisation https://en.wikipedia.org/wiki/A-weighting#A
        let a_sq: Float = 20.6 * 20.6
        let b_sq: Float = 107.7 * 107.7
        let c_sq: Float = 737.9 * 737.9
        let d_sq: Float = 12194 * 12194
        
        // f tables
        let inter_sq = vDSP.multiply(fTable, fTable)
        let inter_tes = vDSP.multiply(inter_sq, inter_sq)
        
        // num
        let num = vDSP.multiply(d_sq, inter_tes)
        
        // den
        let den1 = vDSP.add(a_sq, inter_sq)
        let den2_1 = vDSP.add(b_sq, inter_sq)
        let den2_2 = vDSP.add(c_sq, inter_sq)
        let den2_3 = vDSP.multiply(den2_1, den2_2)
        let den2 = vForce.sqrt(den2_3)
        let den3 = vDSP.add(d_sq, inter_sq)
        let den_mid = vDSP.multiply(den2, den3)
        let den = vDSP.multiply(den1, den_mid)
        
        //normalization
        let prenormal = vDSP.divide(num, den)
        let normal = vDSP.divide(prenormal, n)
        
        return normal
    }
    
    static func createParaBiquad(_ sameplRate: Float, ctrl_pts: [ControlPoint]) -> vDSP.Biquad<Float>? {
        var coeffs: [Double] = []
        for pt in ctrl_pts {
            //intermediates
            let a = pow(10, Double(pt.gain)/40.0)
            let om = 2 * Double.pi * (Double(pt.frequency) / Double(sameplRate))
            let alpha = sin(om) / (2 * Double(pt.q.rawValue))
            let a0 = (1 + alpha / a)
            //coefficients
            coeffs.append((1 + alpha * a)/a0)
            coeffs.append((-2 * cos(om))/a0)
            coeffs.append((1 - alpha * a)/a0)
            coeffs.append((-2 * cos(om))/a0)
            coeffs.append((1 - alpha/a)/a0)
        }
        return vDSP.Biquad(coefficients: coeffs, channelCount: 1, sectionCount: UInt(ctrl_pts.count), ofType: Float.self)
    }

    private static func logBinnedMagnitudes(_ magnitudes: [Float], barCount: Int) -> [Float] {
        let minBin = 1
        let maxBin = magnitudes.count - 1
        guard barCount > 0, maxBin > minBin else {
            return [Float](repeating: 0, count: max(barCount, 0))
        }

        let logMin = logf(Float(minBin))
        let logMax = logf(Float(maxBin))
        var bars = [Float](repeating: 0, count: barCount)
        var previousEdge = minBin

        for bar in 0..<barCount {
            let t1 = Float(bar + 1) / Float(barCount)
            var end = Int(floorf(expf(logMin + (logMax - logMin) * t1))) + 1
            if bar == barCount - 1 {
                end = maxBin + 1
            }

            let start = previousEdge
            end = max(end, start + 1)
            end = min(end, maxBin + 1)

            var max: Float = 0
            var avg: Float = 0
            for bin in start..<end {
                if bar != barCount-1 {
                    let val = magnitudes[bin]
                    if val > max {
                        max = val
                    }
                } else {
                    avg+=magnitudes[bin]
                }
            }
            let range = Float(end-start)
            bars[bar] = avg != 0 ? avg/range : log1p(max)
            previousEdge = end
        }

        return bars
    }
}
