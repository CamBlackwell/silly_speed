import Foundation
import AVFoundation
import AudioKit
import Combine

// REMOVE the MixerNodeWrapper block from this file if it is already defined
// in UnifiedAudioAnalyser.swift to fix the "Invalid redeclaration" error.

class SpectrumManager: ObservableObject {
    @Published var node: Node?
    
    func attach(to audioEngine: AVAudioEngine) {
        // AudioKitUI views attach directly to the node
        // We use the wrapper defined in your other file
        self.node = MixerNodeWrapper(audioEngine.mainMixerNode)
    }
}
