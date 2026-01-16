import Foundation
import AVFoundation

class AppleAudioEngine: NSObject, AudioEngineProtocol {
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let timePitch = AVAudioUnitTimePitch()
    private var audioFile: AVAudioFile?
    private let audioQueue = DispatchQueue(label: "audio.engine.queue", qos: .userInitiated)
    private var seekOffset: TimeInterval = 0

    var isPlaying: Bool {
        return playerNode.isPlaying
    }

    func getAudioEngine() -> AVAudioEngine? {
        return audioEngine
    }

    var currentTime: TimeInterval {
        guard
            let nodeTime = playerNode.lastRenderTime,
            let playerTime = playerNode.playerTime(forNodeTime: nodeTime)
        else {
            return seekOffset
        }

        let calculatedTime = seekOffset + (Double(playerTime.sampleTime) / playerTime.sampleRate)
        return min(calculatedTime, duration)
    }

    var duration: TimeInterval {
        guard let file = audioFile else { return 0 }
        return Double(file.length) / file.fileFormat.sampleRate
    }

    override init() {
        super.init()
        setupAudioEngine()
    }

    private func setupAudioEngine() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setPreferredIOBufferDuration(0.023)
            try session.setPreferredSampleRate(44100)
            try session.setActive(true)
        } catch {
            print("AudioSession error: \(error)")
        }

        audioEngine.attach(playerNode)
        audioEngine.attach(timePitch)

        let format = audioEngine.mainMixerNode.outputFormat(forBus: 0)

        audioEngine.connect(playerNode, to: timePitch, format: format)
        audioEngine.connect(timePitch, to: audioEngine.mainMixerNode, format: format)

        audioEngine.prepare()

        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine \(error)")
        }
    }

    func load(audioFile: AudioFile) {
        audioQueue.async {
            do {
                self.audioFile = try AVAudioFile(forReading: audioFile.fileURL)
                self.seekOffset = 0
            } catch {
                print("failed to load audioFile: \(error) at \(audioFile.fileURL.path())")
            }
        }
    }

    func play() {
        audioQueue.async {
            guard let file = self.audioFile else { return }

            if !self.audioEngine.isRunning {
                do {
                    self.audioEngine.prepare()
                    try self.audioEngine.start()
                } catch {
                    print("Could not start engine: \(error)")
                    return
                }
            }

            self.playerNode.stop()
            self.playerNode.reset()

            let sampleRate = file.fileFormat.sampleRate
            let clampedOffset = max(0, min(self.seekOffset, self.duration))
            let startFrame = AVAudioFramePosition(clampedOffset * sampleRate)
            guard startFrame >= 0 && startFrame < file.length else { return }
            let frameCount = AVAudioFrameCount(file.length - startFrame)

            self.playerNode.scheduleSegment(file, startingFrame: startFrame, frameCount: frameCount, at: nil)
            self.playerNode.play()
        }
    }

    func pause() {
        playerNode.pause()
    }

    func stop() {
        audioQueue.async {
            self.playerNode.stop()
            self.playerNode.reset()
            self.seekOffset = 0
        }
    }

    func seek(to time: TimeInterval) {
        audioQueue.async {
            guard let file = self.audioFile else { return }

            let clampedTime = max(0, min(time, self.duration))
            let wasPlaying = self.playerNode.isPlaying

            self.playerNode.stop()
            self.playerNode.reset()
            self.seekOffset = clampedTime

            let sampleRate = file.fileFormat.sampleRate
            let startFrame = AVAudioFramePosition(clampedTime * sampleRate)
            guard startFrame >= 0 && startFrame < file.length else { return }
            let frameCount = AVAudioFrameCount(file.length - startFrame)

            self.playerNode.scheduleSegment(file, startingFrame: startFrame, frameCount: frameCount, at: nil)

            if wasPlaying {
                self.playerNode.play()
            }
        }
    }

    func setVolume(_ volume: Float) {
        playerNode.volume = volume
    }

    func setTempo(_ tempo: Float) {
        audioQueue.async {
            self.timePitch.rate = tempo
        }
    }

    func setPitch(_ pitch: Float) {
        audioQueue.async {
            self.timePitch.pitch = pitch
        }
    }
}
