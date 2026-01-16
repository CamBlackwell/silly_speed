import Foundation
import AVFoundation

class AppleAudioEngine: NSObject, AudioEngineProtocol {
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let timePitch = AVAudioUnitTimePitch()
    private var audioFile: AVAudioFile?
    private let audioQueue = DispatchQueue(label: "audio.engine.queue", qos: .userInitiated)
    private var seekOffset: TimeInterval = 0
    
    var isPlaying: Bool{
        return playerNode.isPlaying
    }
    
    func getAudioEngine() -> AVAudioEngine? {
            return audioEngine
    }
    
    var currentTime: TimeInterval {
        guard let nodeTime = playerNode.lastRenderTime, let playerTime = playerNode.playerTime(forNodeTime: nodeTime) else { return seekOffset }
        let calculatedTime = seekOffset + (Double(playerTime.sampleTime) / playerTime.sampleRate)
        return min(calculatedTime, duration)
    }
    
    var duration: TimeInterval {
        guard let file = audioFile else {return 0}
        return Double(file.length) / file.fileFormat.sampleRate
    }
    
    override init() {
        super.init()
        setupAudioEngine()
    }
    
    private func setupAudioEngine() {
        audioEngine.attach(playerNode)
        audioEngine.attach(timePitch)
        
        audioEngine.connect(playerNode, to: timePitch, format: nil)
        audioEngine.connect(timePitch, to: audioEngine.mainMixerNode, format: nil)
        
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
            
            if !self.playerNode.isPlaying {
                if self.seekOffset > 0 {
                    let sampleRate = file.fileFormat.sampleRate
                    let startFrame = AVAudioFramePosition(self.seekOffset * sampleRate)
                    let frameCount = AVAudioFrameCount(file.length - startFrame)
                    
                    if startFrame < file.length {
                        self.playerNode.scheduleSegment(file, startingFrame: startFrame, frameCount: frameCount, at: nil)
                    }
                } else {
                    self.playerNode.scheduleFile(file, at: nil)
                }
            }
            
            self.playerNode.play()
        }
    }

    
    func pause() {
        playerNode.pause()
    }
    
    func stop() {
        audioQueue.async {
            self.playerNode.stop()
            self.seekOffset = 0
        }
    }

    
    func seek(to time: TimeInterval) {
        audioQueue.async {
            guard let file = self.audioFile else { return }
            
            let wasPlaying = self.playerNode.isPlaying
            self.playerNode.stop()
            self.seekOffset = time
            
            let sampleRate = file.fileFormat.sampleRate
            let startFrame = AVAudioFramePosition(time * sampleRate)
            let frameCount = AVAudioFrameCount(file.length - startFrame)
            
            guard startFrame >= 0 && startFrame < file.length else { return }
            
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
        
