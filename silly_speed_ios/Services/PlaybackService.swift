import Foundation
import AVFoundation
import MediaPlayer
import Combine



@MainActor
final class PlaybackService: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var currentlyPlayingID: UUID?
    @Published var tempo: Float = 1.0 {
        didSet { currentEngine?.setTempo(tempo) }
    }
    
    @Published var pitch: Float = 0.0 {
        didSet { currentEngine?.setPitch(pitch) }
    }
    
    @Published var isLooping = false
    @Published var selectedAlgorithm: PitchAlgorithm = .apple
    
    let audioAnalyzer = UnifiedAudioAnalyser()
    
    private var currentEngine: AudioEngineProtocol?
    private var timer: Timer?
    private var isSeeking = false
    private var observerTokens: [NSObjectProtocol] = []
    private let settingsStorage: SettingsStorage
    
    weak var delegate: PlaybackServiceDelegate?
    
    init(settingsStorage: SettingsStorage) {
        self.settingsStorage = settingsStorage
    }
    
    func initialize() async {
        selectedAlgorithm = settingsStorage.loadAlgorithm()
        
        setupAudioSession()
        initializeEngine()
        setupSystemObservers()
        setupRemoteControls()
    }
    
    deinit {
        MainActor.assumeIsolated {
            cleanup()
        }
    }
    func cleanup() {
        timer?.invalidate()
        timer = nil
        
        for token in observerTokens {
            NotificationCenter.default.removeObserver(token)
        }
        observerTokens.removeAll()
        
        currentEngine?.stop()
        try? AVAudioSession.sharedInstance().setActive(false)
    }
    
    private func initializeEngine() {
        switch selectedAlgorithm {
        case .apple:
            currentEngine = AppleAudioEngine()
        case .rubberBand, .soundTouch, .signalSmith:
            currentEngine = nil
        }
        
        if let avEngine = currentEngine?.getAudioEngine() {
            audioAnalyzer.attach(to: avEngine)
        }
    }
    
    func changeAlgorithm(to algorithm: PitchAlgorithm, currentFile: AudioFile?) async {
        guard algorithm.isImplemented else { return }
        
        let wasPlaying = isPlaying
        let savedTime = currentTime
        
        if let oldEngine = currentEngine?.getAudioEngine() {
            audioAnalyzer.detach(from: oldEngine)
        }
        
        stop()
        
        selectedAlgorithm = algorithm
        await settingsStorage.saveAlgorithm(algorithm)
        initializeEngine()
        
        if let audioFile = currentFile {
            currentEngine?.load(audioFile: audioFile)
            currentEngine?.setTempo(tempo)
            currentEngine?.setPitch(pitch)
            currentEngine?.seek(to: savedTime)
            
            if wasPlaying {
                play(audioFile: audioFile)
            }
        }
    }
    
    func play(audioFile: AudioFile) {
        setupAudioSessionActive()
        
        guard let engine = currentEngine else { return }
        
        let isSameSong = currentlyPlayingID == audioFile.id
        
        if !isSameSong {
            stopTimer()
            currentEngine?.stop()
            
            engine.load(audioFile: audioFile)
            engine.setTempo(tempo)
            engine.setPitch(pitch)
        }
        
        engine.play()
        
        isPlaying = true
        currentlyPlayingID = audioFile.id
        duration = TimeInterval(audioFile.audioDuration)
        if !isSameSong { currentTime = 0 }
        
        startTimer()
        delegate?.updateNowPlayingInfo(for: audioFile, currentTime: currentTime, duration: duration, isPlaying: true)
    }
    
    func stop() {
        currentEngine?.stop()
        
        isPlaying = false
        currentTime = 0
        currentlyPlayingID = nil
        stopTimer()
        
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    
    func togglePlayPause() {
        guard let engine = currentEngine else { return }
        
        if engine.isPlaying {
            engine.pause()
            isPlaying = false
            stopTimer()
        } else {
            engine.play()
            isPlaying = true
            startTimer()
        }
        
        delegate?.playbackStateChanged(isPlaying: isPlaying)
    }
    
    func seek(to time: TimeInterval) {
        isSeeking = true
        currentEngine?.seek(to: time)
        currentTime = time
        
        Task {
            try? await Task.sleep(nanoseconds: 150_000_000)
            isSeeking = false
        }
    }
    
    func setVolume(_ volume: Float) {
        currentEngine?.setVolume(volume)
    }
    
    private func startTimer() {
        stopTimer()
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor in
                guard let engine = self.currentEngine, !self.isSeeking else { return }
                
                let engineTime = engine.currentTime
                let previousSecond = Int(self.currentTime)
                self.currentTime = engineTime
                
                if Int(engineTime) != previousSecond {
                    self.delegate?.currentTimeChanged(to: self.currentTime)
                }
                
                if self.currentTime >= self.duration && self.duration > 0 {
                    self.delegate?.trackDidFinish()
                }
            }
        }
        
        RunLoop.main.add(timer!, forMode: .common)
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            UIApplication.shared.beginReceivingRemoteControlEvents()
        } catch {
            print("Audio session setup failed: \(error)")
        }
    }
    
    private func setupAudioSessionActive() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to activate audio session: \(error)")
        }
    }
    
    private func setupRemoteControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.delegate?.skipPreviousRequested()
            return .success
        }
        
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.delegate?.skipNextRequested()
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self?.seek(to: positionEvent.positionTime)
            return .success
        }
    }
    
    private func setupSystemObservers() {
        let interruptionToken = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let userInfo = notification.userInfo
            let typeValue = userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let optionsValue = userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt

            Task { @MainActor [weak self] in
                guard let self = self,
                      let typeValue = typeValue,
                      let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

                switch type {
                case .began:
                    self.isPlaying = false
                    self.stopTimer()
                    self.currentEngine?.pause()

                case .ended:
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue ?? 0)

                    if options.contains(.shouldResume) {
                        try? AVAudioSession.sharedInstance().setActive(true)
                        self.currentEngine?.play()
                        self.isPlaying = true
                        self.startTimer()
                    }

                @unknown default:
                    break
                }
            }
        }
        observerTokens.append(interruptionToken)

        
        let routeChangeToken = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            let userInfo = notification.userInfo
            let reasonValue = userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt

            Task { @MainActor [weak self] in
                guard let self = self,
                      let reasonValue = reasonValue,
                      let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

                if reason == .oldDeviceUnavailable {
                    self.togglePlayPause()
                }
            }
        }
        observerTokens.append(routeChangeToken)

        
        let configChangeToken = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isPlaying,
                      let engine = self.currentEngine?.getAudioEngine() else { return }
                
                do {
                    engine.prepare()
                    try engine.start()
                } catch {
                    print("Failed to restart engine after config change: \(error)")
                }
            }
        }
        observerTokens.append(configChangeToken)
        
        let bgToken = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if !self.isPlaying {
                    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                }
                self.delegate?.didEnterBackground()
            }
        }
        observerTokens.append(bgToken)
        
        let fgToken = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.currentlyPlayingID != nil {
                    try? AVAudioSession.sharedInstance().setActive(true)
                }
            }
        }
        observerTokens.append(fgToken)
    }
}
protocol PlaybackServiceDelegate: AnyObject {
    func trackDidFinish()
    func skipNextRequested()
    func skipPreviousRequested()
    func currentTimeChanged(to time: TimeInterval)
    func playbackStateChanged(isPlaying: Bool)
    func updateNowPlayingInfo(for file: AudioFile, currentTime: TimeInterval, duration: TimeInterval, isPlaying: Bool)
    func didEnterBackground()
}
