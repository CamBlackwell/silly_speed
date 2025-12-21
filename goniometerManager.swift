import Foundation
import AVFoundation
import AudioKit
import Combine

class GoniometerManager: ObservableObject {
    @Published var leftSamples: [Float] = []
    @Published var rightSamples: [Float] = []
    @Published var phaseCorrelation: Float = 0.0
    
    private var leftTap: BaseTap?
    private var rightTap: BaseTap?
    private let bufferSize: AVAudioFrameCount = 512
    private let maxPoints = 100  // Keep last 100 points for trails
    
    func attach(to audioEngine: AVAudioEngine) {
        let mixer = audioEngine.mainMixerNode
        let format = mixer.outputFormat(forBus: 0)
        
        // Install tap to capture audio
        mixer.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, time in
            self?.processBuffer(buffer)
        }
    }
    
    func detach(from audioEngine: AVAudioEngine) {
        audioEngine.mainMixerNode.removeTap(onBus: 0)
    }
    
    private func processBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        
        // Get left and right channels
        let leftChannel = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))
        let rightChannel = channelCount > 1 ?
            Array(UnsafeBufferPointer(start: channelData[1], count: frameLength)) : leftChannel
        
        // Downsample for visualization (take every Nth sample)
        let downsample = max(1, frameLength / 50)  // Get ~50 points
        var newLeftSamples: [Float] = []
        var newRightSamples: [Float] = []
        
        for i in stride(from: 0, to: frameLength, by: downsample) {
            newLeftSamples.append(leftChannel[i])
            newRightSamples.append(rightChannel[i])
        }
        
        // Calculate phase correlation
        let correlation = calculatePhaseCorrelation(left: leftChannel, right: rightChannel)
        
        // Update on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Keep only last N points for trailing effect
            self.leftSamples = (self.leftSamples + newLeftSamples).suffix(self.maxPoints)
            self.rightSamples = (self.rightSamples + newRightSamples).suffix(self.maxPoints)
            self.phaseCorrelation = correlation
        }
    }
    
    private func calculatePhaseCorrelation(left: [Float], right: [Float]) -> Float {
        guard left.count == right.count, !left.isEmpty else { return 0 }
        
        var sumLR: Float = 0
        var sumLL: Float = 0
        var sumRR: Float = 0
        
        for i in 0..<left.count {
            sumLR += left[i] * right[i]
            sumLL += left[i] * left[i]
            sumRR += right[i] * right[i]
        }
        
        let denominator = sqrt(sumLL * sumRR)
        guard denominator > 0 else { return 0 }
        
        return sumLR / denominator
    }
}
