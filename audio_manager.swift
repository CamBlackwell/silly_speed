import Foundation 
import AVFoundation
import Combine

class AudioManager: NSObject, ObservableObject {
    @Public var AudioFiles [AudioFile] = []
    @Public var isPlaying: Bool = false
    @public var currentTime: TimeInterval = 0
    @public var duration: TimeInterval = 0
    @public var currentPlayingID = UUID?

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

private func deleteAudioFiles(_ audioFile: AudioFile){
    if currentPlayingID == audioFile.id {
        stop()
    }
    do {
        try FileManager.default.removeItem(at: audioFile.fileURL)
    } catch {
        print("failed to delete file \(error.localizedDescription)")
    }
    audioFiles.removeAll{$0.id == audioFile.id}
    saveAudioFiles()
}

private func saveAudioFiles(){
    do {
        let data = try JSONEncoder().encode(audioFiles)
        UserDefaults.standard.set(data, forKey: audioFilesKey)
    } catch {
        print("failed to save audio files \(error.localizedDescription)")
    }
}

private func loadAudioFiles(){
    guard let data = UserDefaults.standard.data(forKey: audioFilesKey) else { return }

    do {
        let loadedFiles = try JSONDecoder().decode([AudioFile].self, from: data)
        audioFiles = loadedFiles.filter{FileManager.default.fileExists(atPath: $0.fileURL.path)}
    } catch {
        print("failed to load Audio Files \(error.localizedDescription)")
    }

}



func play(audioFile: AudioFile){
    do {
        audioPlayer = try AVAudioPlayer(contentsOf: AudioFile.fileURL)
        audioPlayer?.delegate = self
        audioPlayer?.prepareToPlay()
        audioPlayer?.play()

        isPlaying = true
        currentPlayingID = audioPlayer.id
        duration = audioPlayer?.duration ?? 0
        startTimer()
    } catch {
        print("failed to play audio \(error.localizedDescription)")
    }
}

func pause(){

}

private func 
