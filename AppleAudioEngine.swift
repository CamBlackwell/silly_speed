import Foundation
import AVFoundation

class AppleAudioEngine: NSObject, AudioEngineProtocol {
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let timePitch = AVAudioUnitTimePitch()
    private var audioFile: AVAudioFile?
    
    var isPlaying: Bool{
        return playerNode.isPlaying
    }
    
    var currentTime: TimeInterval {
        guard let nodeTime = playerNode.lastRenderTime,
              let playerTime = playerNode.playerTime(forNodeTime: nodeTime) else {
            return 0
        }
        return Double(playerTime.sampleTime) / playerTime.sampleRate
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
        
        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine \(error)")
        }
    }
        
    func load(audioFile: AudioFile){
        do {
            self.audioFile = try AVAudioFile(forReading: audioFile.fileURL)
        } catch {
            print("failed to load audioFile: \(error)")
        }
        
    }
    
    func play(){
        guard let file = audioFile else { return }
        
        playerNode.scheduleFile(file, at: nil)
        playerNode.play()
    }
    
    func pause() {
        playerNode.pause()
    }
    
    func stop() {
        playerNode.stop()
    }
    
    func seek(to time: TimeInterval) {
        guard let file = audioFile else { return }
        
        let wasPlaying = isPlaying
        playerNode.stop() //probably gonna cause issues
        
        let sampleRate = file.fileFormat.sampleRate
        let startFrame = AVAudioFramePosition(time * sampleRate)
        
        if startFrame < file.length {
            playerNode.scheduleSegment(file, startingFrame: startFrame, frameCount: AVAudioFrameCount(file.length - startFrame), at: nil)
            
            if wasPlaying {
                playerNode.play()
            }
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
    private func refreshAudio(){
        guard let file = audioFile else { return }
        let wasPlaying = isPlaying
        let currentPos = currentTime
        
        playerNode.stop()
        playerNode.scheduleFile(file, at: nil)
        
        if currentPos > 0 {
            seek(to: currentPos)
        }
        
        if wasPlaying {
            playerNode.play()
        }
    }
}
        
