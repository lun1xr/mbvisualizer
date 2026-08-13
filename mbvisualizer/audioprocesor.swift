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

    static func fft(data: UnsafePointer<Float>, aTable: [Float], setup: OpaquePointer, cielingMultiplier: Float, barCount: Int) -> [Float] {
        var realIn = [Float](repeating: 0, count: fftSize)
        var imagIn = [Float](repeating: 0, count: fftSize)

        var realOut = [Float](repeating: 0, count: fftSize)
        var imagOut = [Float](repeating: 0, count: fftSize)

        // Window before FFT to reduce spectral leakage into low/high bins.
        vDSP_vmul(data, 1, hannWindow, 1, &realIn, 1, vDSP_Length(fftSize))

        vDSP_DFT_Execute(setup, &realIn, &imagIn, &realOut, &imagOut)

        var complex = DSPSplitComplex(realp: &realOut, imagp: &imagOut)
        var magnitudes = [Float](repeating: 0, count: binCount)
        vDSP_zvabs(&complex, 1, &magnitudes, 1, vDSP_Length(binCount))

        // Disp signal from first bin, drop for response prettiness
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
    
    static func createAWFilterTable(_ sameplRate: Float) -> [Float] {
        var result = [Float](repeating: 0, count: binCount)
        for i in 0..<binCount {
            let binFreq = Float(i) * sameplRate / Float(fftSize)
            result[i] = calcAW_F(binFreq)
        }
        return result
    }
    
    /// Normalized by 1000 (precomputed)
    private static func calcAW_F(_ f: Float) -> Float {
        let f_sq = f * f
        let f_tes = f_sq * f_sq
        
        let n: Float = 0.7943412 // R_A(1000)
        
        // A-weight function realisation https://en.wikipedia.org/wiki/A-weighting#A
        let a_sq: Float = 20.6 * 20.6
        let b_sq: Float = 107.7 * 107.7
        let c_sq: Float = 737.9 * 737.9
        let d_sq: Float = 12194 * 12194
        let num = f_tes * d_sq
        let den = (f_sq + a_sq) * sqrt((f_sq + b_sq) * (f_sq + c_sq)) * (f_sq + d_sq)
        
        let prenormal_f = num/den
        return prenormal_f/n
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
                if bar != bars.count-1 {
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
