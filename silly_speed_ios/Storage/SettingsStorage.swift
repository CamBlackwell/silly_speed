import Foundation
import Combine

actor SettingsStorage {
    private let algorithmKey = "selectedAlgorithm"
    private let visualisationModeKey = "visualisationMode"
    @MainActor
    func loadAlgorithm() -> PitchAlgorithm {
        guard let saved = UserDefaults.standard.string(forKey: algorithmKey),
              let algorithm = PitchAlgorithm(rawValue: saved),
              algorithm.isImplemented else {
            return .apple
        }
        return algorithm
    }
    
    func saveAlgorithm(_ algorithm: PitchAlgorithm) {
        UserDefaults.standard.set(algorithm.rawValue, forKey: algorithmKey)
    }
    
    func loadVisualisationMode() -> VisualisationMode {
        guard let saved = UserDefaults.standard.string(forKey: visualisationModeKey),
              let mode = VisualisationMode(rawValue: saved) else {
            return .both
        }
        return mode
    }
    
    func saveVisualisationMode(_ mode: VisualisationMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: visualisationModeKey)
    }
}
