import Foundation 
import AVFoundation
import Combine
import MediaPlayer

class AudioManager: NSObject, ObservableObject {
    @Published var audioFiles: [AudioFile] = []
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var currentlyPlayingID: UUID?
    @Published var tempo: Float = 1.0
    @Published var pitch: Float = 0.0
    @Published var selectedAlgorithm: PitchAlgorithm = .apple
    

    private var currentEngine: AudioEngineProtocol?
    private var timer: Timer?
    private let fileDirectory: URL
    private let audioFilesKey = "savedAudioFiles"
    private let algorithmKey = "selectedAlgorithm"
    private var isSeeking = false

    override init() {
        self.fileDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        super.init()
        loadAudioFiles()
        loadSelectedAlgorithm()
        setupAudioSession()
        initialiseEngine()
        
    }
    
    private func loadSelectedAlgorithm(){
        if let saved = UserDefaults.standard.string(forKey: algorithmKey),
           let algorithm = PitchAlgorithm(rawValue: saved),
           algorithm.isImplemented {
            selectedAlgorithm = algorithm
        }
    }
    
    private func saveSelectedAlgorithm(){
        UserDefaults.standard.set(selectedAlgorithm.rawValue, forKey: algorithmKey)
    }

    private func setupAudioSession(){
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
            UIApplication.shared.beginReceivingRemoteControlEvents()
                    setupRemoteTransportControls()
        } catch {
            print("failed to set up audio \(error.localizedDescription)")
        }
    }
    
    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            if let currentFile = self.audioFiles.first(where: { $0.id == self.currentlyPlayingID }) {
                self.togglePlayPause()
                return .success
            }
            return .commandFailed
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] event in
            self?.togglePlayPause()
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self,
                  let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self.seek(to: positionEvent.positionTime)
            return .success
        }
    }
    
    private func updateNowPlayingInfo() {
        guard let currentFile = audioFiles.first(where: { $0.id == currentlyPlayingID }) else {
            return
        }
        
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = currentFile.fileName
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private func initialiseEngine(){
        switch selectedAlgorithm {
        case .apple:
            currentEngine = AppleAudioEngine() //TODO ADD engines
        case .rubberBand:
            currentEngine = nil
        case .soundTouch:
            currentEngine = nil
        case .signalSmith:
            currentEngine = nil
        }
    }
    
    func changeAlgorithm(to algorithm: PitchAlgorithm){
        guard algorithm.isImplemented else {
            print ("Algorithm \(algorithm.rawValue) not implemented yet")
            return
        }
        
        let wasPlaying = isPlaying
        let currentAudioFile = audioFiles.first { $0.id == currentlyPlayingID }
        let savedTime = currentTime
        
        stop()
        
        selectedAlgorithm = algorithm
        saveSelectedAlgorithm()
        initialiseEngine()
        
        if let audioFile = currentAudioFile {
            currentEngine?.load(audioFile: audioFile)
            currentEngine?.setTempo(tempo)
            currentEngine?.setPitch(pitch)
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.currentEngine?.seek(to: savedTime)
                if wasPlaying {
                    self.play(audioFile: audioFile)
                }
            }
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
            
            Task {
                let asset = AVURLAsset(url: destinationURL, options: nil)
                do {
                    let duration = try await asset.load(.duration)
                    let durationInSeconds = Float(CMTimeGetSeconds(duration))
                    
                    
                    let audioFile = AudioFile(fileName: fileName, fileURL: destinationURL, audioDuration: durationInSeconds)
                    await MainActor.run {
                        audioFiles.append(audioFile)
                        saveAudioFiles()
                    }
            } catch {
                print("failed to load duration \(error)")
            }
        }
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
            guard let engine = currentEngine else {
                print("No engine available")
                return
            }
            
            if currentlyPlayingID != audioFile.id {
                stop()
            }
            
            engine.load(audioFile: audioFile)
            engine.setTempo(tempo)
            engine.setPitch(pitch)
            engine.play()
            
            isPlaying = true
            currentlyPlayingID = audioFile.id
            duration = TimeInterval(audioFile.audioDuration)
            startTimer()
            updateNowPlayingInfo()
        }
    }

    func stop(){
        currentEngine?.stop()
        isPlaying = false
        currentTime = 0
        currentlyPlayingID = nil
        stopTimer()
    }

    func togglePlayPause() {
        guard let engine = currentEngine else {return}

        if engine.isPlaying {
            engine.pause()
            isPlaying = false
            stopTimer()
            updateNowPlayingInfo()
        } else {
            engine.play()
            isPlaying = true
            startTimer()
            updateNowPlayingInfo()
        }
    }

    func seek(to time: TimeInterval){
            isSeeking = true
            currentEngine?.seek(to: time)
            currentTime = time

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.isSeeking = false
            }
        }

    func setVolume(_ volume: Float){
        currentEngine?.setVolume(volume)
    }
    
    func setTempo(_ newTempo: Float){
        tempo = max(0.1, min(4.0, newTempo))
        currentEngine?.setTempo(tempo)
    }
    
    func setPitch(_ newPitch: Float){
        pitch = max(-2400, min(2400, newPitch))
        currentEngine?.setPitch(pitch)
    }
    


    private func startTimer(){
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self, let engine = self.currentEngine else { return }
                
                if self.isSeeking {
                    return  // Don't update while seeking
                }
                
                self.currentTime = engine.currentTime
                self.updateNowPlayingInfo()
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

