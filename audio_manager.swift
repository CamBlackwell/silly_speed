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
    do {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playback, mode: .default)
        try audioSession.setActive(true)
    } catch {
        print("failed to set up audio \(error.localizedDescription)")
    }
}

private func importAudioFiles(from url: URL){
    guard url.startAccessingSecurityScopedResource() else {
        print("failed to accesss file")
        return
    }
    defer {url.stopAccessingSecurityScopedResource()}

    let fileName = url.lastPathComponent
    let destinationURL = documentsDirectory.appendingPathComponent(fileName)

    do {
        if FileManager.default.fileExists(atPath: destinationURL.path){
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.copyItem(at: url, to: destinationURL)

        let audioFile = AudioFile(fileName: fileName, fileURL: destinationURL)
        audioFiles.append(audioFile)

        saveAudioFiles()
    } catch {
        print("failed to import file \(error.localizedDescription)")
    }

}



func play(){

}

func pause(){

}

