import Foundation 
import AVFoundation
import Combine

class AudioManager: NSObject, ObservableObject {
    @Public var AudioFiles [AudioFile] = []
    @Public var isPlaying: Bool = false
    @public var currentTime: TimeInterval = 0
    @public var duration: TimeInterval = 0
    @public var currentPlayingUUID = UUID?

    private var audioPlayer = AVAudioPlayer
    private var timer: Timer?
    private let fileDirectory: URL
    private let audioFilesKey = "savedAudioFiles"

    override init() {
        self.fileDirectory = FileManager.default.urls(for: .fileDirectory, in: .userDomainMask)
        super.init()
        loadAudioFiles()
        setupAudioSession()
        
    }
}



private func setupAudioSession(){

}

private func loadAudioFiles(){

}



func play(){

}

func pause(){

}

