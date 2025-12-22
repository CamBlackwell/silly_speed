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
    @Published var goniometerManager = GoniometerManager()
    @Published var isLooping: Bool = false


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
        setupInterruptionObserver()
        setupRouteChangeObserver()
        setupConfigurationChangeObserver()
    }
    
    private func setupConfigurationChangeObserver() {
        NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, self.isPlaying else { return }
            
            if let engine = self.currentEngine?.getAudioEngine() {
                do {
                    engine.prepare()
                    try engine.start()
                } catch {
                    print("Failed to restart engine after config change: \(error)")
                }
            }
        }
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
            if self.audioFiles.first(where: { $0.id == self.currentlyPlayingID }) != nil {
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
    
    private func setupInterruptionObserver() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

            if type == .began {
                self.isPlaying = false
                self.stopTimer()
                self.currentEngine?.pause()
            } else if type == .ended {
                if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) {
                        do {
                            try AVAudioSession.sharedInstance().setActive(true)
                            self.currentEngine?.play()
                            self.isPlaying = true
                            self.startTimer()
                        } catch {
                            print("Resume error: \(error)")
                        }
                    }
                }
            }
        }
    }
    
    private func setupRouteChangeObserver() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

            if reason == .oldDeviceUnavailable { //headphones were disconnected
                DispatchQueue.main.async {
                    self?.togglePlayPause()
                }
            }
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
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? Double(tempo) : 0.0
        
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
        
        if let avEngine = currentEngine?.getAudioEngine() {
            goniometerManager.attach(to: avEngine)
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
        
        if let oldEngine = currentEngine?.getAudioEngine() {
            goniometerManager.detach(from: oldEngine)
        }
        
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
    



    func play(audioFile: AudioFile) {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            print("Could not activate session: \(error)")
            return
        }

        guard let engine = currentEngine else { return }
        
        stopTimer()
        self.currentTime = 0

        if currentlyPlayingID != audioFile.id {
            engine.stop()
        }

        engine.load(audioFile: audioFile)
        engine.setTempo(tempo)
        engine.setPitch(pitch)
        
        engine.play()

        isPlaying = true
        self.currentlyPlayingID = audioFile.id
        self.duration = TimeInterval(audioFile.audioDuration)
        startTimer()
        updateNowPlayingInfo()
    }

    func stop() {
        currentEngine?.stop()
        isPlaying = false
        currentTime = 0
        currentlyPlayingID = nil
        stopTimer()
        
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Deactivation failed: \(error)")
        }
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
                    return //if seeking dont update
                }
                
                
                self.currentTime = engine.currentTime
                self.updateNowPlayingInfo()
                
                if self.currentTime >= self.duration && self.duration > 0 {
                    self.skipNextSong()
                }
            }
        }


    private func stopTimer(){
        timer?.invalidate()
        timer = nil
    }
    
    func skipNextSong(){
        stopTimer()
        guard !audioFiles.isEmpty else {
            stop()
            return
        }
        if let currentIndex = audioFiles.firstIndex(where: { $0.id == currentlyPlayingID }) {
            let nextIndex = currentIndex + 1
            if nextIndex < audioFiles.count {
                let nextFile = audioFiles[nextIndex]
                play(audioFile: nextFile)
            } else {
                if isLooping {
                    if let firstFile = audioFiles.first {
                        play(audioFile: firstFile)
                    }
                } else {
                    stop()
                }
            }
        } else {
            if let firstFile = audioFiles.first {
                play(audioFile: firstFile)
            }
        }
        
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

