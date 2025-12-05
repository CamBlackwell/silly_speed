import Foundation 
import AVFoundation
import Combine

class AudioManager: NSObject, ObservableObject {
    @Published var audioFiles: [AudioFile] = []
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var currentlyPlayingID: UUID?

    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    private let fileDirectory: URL
    private let audioFilesKey = "savedAudioFiles"

    override init() {
        self.fileDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        super.init()
        loadAudioFiles()
        setupAudioSession()
        
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

    func importAudioFile(from url: URL){
        guard url.startAccessingSecurityScopedResource() else {
            print("failed to accesss file")
            return
        }
        defer {url.stopAccessingSecurityScopedResource()}

        let fileName = url.lastPathComponent
        let destinationURL = fileDirectory.appendingPathComponent(fileName)

        do {
            if FileManager.default.fileExists(atPath: destinationURL.path()){
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

    func deleteAudioFile(_ audioFile: AudioFile){
        if currentlyPlayingID == audioFile.id {
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
            audioFiles = loadedFiles.filter{FileManager.default.fileExists(atPath: $0.fileURL.path())}
        } catch {
            print("failed to load Audio Files \(error.localizedDescription)")
        }

    }



    func play(audioFile: AudioFile){
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioFile.fileURL)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()

            isPlaying = true
            currentlyPlayingID = audioFile.id
            duration = audioPlayer?.duration ?? 0
            startTimer()
        } catch {
            print("failed to play audio \(error.localizedDescription)")
        }
    }

    func stop(){
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentTime = 0
        currentPlayingID = nil
        stopTimer()
    }

    func togglePlayPause() {
        guard let player = audioPlayer else {return}

        if player.isPlaying {
            player.pause()
            isPlaying = false
            stopTimer()
        } else {
            player.play()
            isPlaying = true
            startTimer()
        }
    }

    func seek(to time: TimeInterval){
        audioPlayer?.currentTime = time
        currentTime = time
    }

    func setVolume(_ volume: Float){
        audioPlayer?.volume = volume
    }

    private func startTimer(){
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else {return}
            self.currentTime = player.currentTime
        }
    }

    private func stopTimer(){
        timer?.invalidate()
        timer = nil
    }
}
extension AudioManager: AVAudioPlayerDelegate{
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool){
        isPlaying = false
        currentlyPlayingID = nil
        currentTime = 0
        stopTimer()
    }
}

