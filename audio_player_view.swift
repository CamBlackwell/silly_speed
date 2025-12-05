import SwiftUI

struct AudioPlayerView: View {
    let audioFile: AudioFile
    @ObservedObject var audioManager: AudioManager
    @State private var volume: Float = 1.0
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [.blue, .purple]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 200, height: 200)
                
                Image(systemName: "music.note")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
            }
            .shadow(radius: 10)
            
            VStack(spacing: 8) {
                Text(audioFile.fileName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text("Audio Player")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            Spacer()
            
            VStack(spacing: 8) {
                Slider(
                    value: Binding(
                        get: { audioManager.currentTime },
                        set: { audioManager.seek(to: $0) }
                    ),
                    in: 0...max(audioManager.duration, 0.01)
                )
                .disabled(audioManager.currentlyPlayingID != audioFile.id)
                
                HStack {
                    Text(formatTime(audioManager.currentTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(formatTime(audioManager.duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            
            HStack(spacing: 40) {
                Button(action: {}) {
                    Image(systemName: "backward.fill")
                        .font(.title)
                        .foregroundColor(.secondary)
                }
                .disabled(true)
                
                Button(action: {
                    if audioManager.currentlyPlayingID == audioFile.id {
                        audioManager.togglePlayPause()
                    } else {
                        audioManager.play(audioFile: audioFile)
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 70, height: 70)
                        
                        Image(systemName: isThisFilePlaying ? "pause.fill" : "play.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                }
                
                Button(action: {}) {
                    Image(systemName: "forward.fill")
                        .font(.title)
                        .foregroundColor(.secondary)
                }
                .disabled(true)
            }
            
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "speaker.fill")
                        .foregroundColor(.secondary)
                    
                    Slider(value: $volume, in: 0...1)
                        .onChange(of: volume) { newValue in
                            audioManager.setVolume(newValue)
                        }
                    
                    Image(systemName: "speaker.wave.3.fill")
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var isThisFilePlaying: Bool {
        audioManager.currentlyPlayingID == audioFile.id && audioManager.isPlaying
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}