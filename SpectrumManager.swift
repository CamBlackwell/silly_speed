import Foundation
import AVFoundation
import AudioKit
import Combine

// Required to bridge native AVAudioMixerNode to AudioKit's FFTTap
extension AVAudioMixerNode: Node {
    public var connections: [Node] { [] }
    public var avAudioNode: AVAudioNode { self }
}

class SpectrumManager: ObservableObject {
    @Published var amplitudes: [Float] = Array(repeating: 0.0, count: 60)
    @Published var peaks: [Float] = Array(repeating: 0.0, count: 60)
    
    private var fftTap: FFTTap?
    private let binCount = 60
    
    func attach(to audioEngine: AVAudioEngine) {
        // Attach the tap to the main mixer
        fftTap = FFTTap(audioEngine.mainMixerNode) { fftData in
            self.processFFT(data: fftData)
        }
        fftTap?.start()
    }
    
    func detach() {
        fftTap?.stop()
        fftTap = nil
    }
    
    private func processFFT(data: [Float]) {
        var newAmplitudes: [Float] = []
        var newPeaks: [Float] = []
        
        for i in 0..<binCount {
            let fractionalIndex = Float(i) / Float(binCount)
            // Logarithmic mapping
            let startSample = Int(pow(fractionalIndex, 2.5) * Float(data.count / 2))
            let endSample = Int(pow(Float(i + 1) / Float(binCount), 2.5) * Float(data.count / 2))
            
            let range = data[max(0, startSample)..<min(data.count, max(startSample + 1, endSample))]
            let avg = range.reduce(0, +) / Float(range.count)
            
            // Convert to dB and normalize (adjust 60 for sensitivity)
            let normalized = max(0, (20 * log10(avg + 0.00001) + 60) / 60)
            newAmplitudes.append(normalized)
            
            // Peak Hold Logic
            let previousPeak = peaks.indices.contains(i) ? peaks[i] : 0
            let decayedPeak = max(normalized, previousPeak - 0.004) // Adjust fall speed here
            newPeaks.append(decayedPeak)
        }
        
        DispatchQueue.main.async {
            self.amplitudes = newAmplitudes
            self.peaks = newPeaks
        }
    }
}
