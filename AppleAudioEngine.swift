import Foundation
import AVFoundation

class AppleAudioEngine: NSObject, AudioEngineProtocol {
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let timePitch = AVAudioUnitTimePitch()
    private var audioFile: AVAudioFile?
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
        
    func load(audioFile: AudioFile){
        do {
            self.audioFile = try AVAudioFile(forReading: audioFile.fileURL)
            seekOffset = 0
        } catch {
            print("failed to load audioFile: \(error)")
        }
        
    }
    
    func play() {
        guard let file = audioFile else { return }
        
        if !audioEngine.isRunning {
            do {
                audioEngine.prepare()
                try audioEngine.start()
            } catch {
                print("Could not start engine: \(error)")
                return
            }
        }
        
        if !playerNode.isPlaying {
            if seekOffset > 0 {
                let sampleRate = file.fileFormat.sampleRate
                let startFrame = AVAudioFramePosition(seekOffset * sampleRate)
                let frameCount = AVAudioFrameCount(file.length - startFrame)
                
                if startFrame < file.length {
                    playerNode.scheduleSegment(file, startingFrame: startFrame, frameCount: frameCount, at: nil)
                }
            } else {
                playerNode.scheduleFile(file, at: nil)
            }
        }
        
        playerNode.play()
    }
    
    func pause() {
        playerNode.pause()
    }
    
    func stop() {
        playerNode.stop()
        seekOffset = 0
    }
    
    func seek(to time: TimeInterval) {
        guard let file = audioFile else { return }
        
        let wasPlaying = playerNode.isPlaying
        playerNode.stop()
        seekOffset = time
        
        let sampleRate = file.fileFormat.sampleRate
        let startFrame = AVAudioFramePosition(time * sampleRate)
        let frameCount = AVAudioFrameCount(file.length - startFrame)
        
        guard startFrame >= 0 && startFrame < file.length else { return }
        
        playerNode.scheduleSegment(
            file,
            startingFrame: startFrame,
            frameCount: frameCount,
            at: nil
        )
        
        if wasPlaying {
            playerNode.play()  // Resume if it was playing
        }
    }
    
    func setVolume(_ volume: Float) {
        playerNode.volume = volume
    }
    
    func setTempo(_ tempo: Float){
        timePitch.rate = tempo
        //refreshAudio()
    }
    
    func setPitch(_ pitch: Float){
        timePitch.pitch = pitch
        //refreshAudio()
    }
}
        
