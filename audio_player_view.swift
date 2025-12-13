import SwiftUI

struct AudioPlayerView: View {
    let audioFile: AudioFile
    @ObservedObject var audioManager: AudioManager
    @State private var volume: Float = 1.0
    @State var color: Color = .blue
    
    var body: some View {
        ZStack {
            Color(red: 0.15, green: 0.15, blue: 0.15)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [.red, .pink]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 200, height: 200)
                    
                    Image(systemName: "music.note")
                        .font(.system(size: 80))
                        .foregroundStyle(.white)
                }
                .shadow(radius: 10)
                
                VStack(spacing: 8) {
                    Text(audioFile.fileName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
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
                    .tint(.red)
                    .disabled(audioManager.currentlyPlayingID != audioFile.id)
                    
                    HStack {
                        Text(formatTime(audioManager.currentTime))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Text(formatTime(audioManager.duration))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
                
                HStack(spacing: 40) {
                    Button(action: {}) {
                        Image(systemName: "backward.fill")
                            .font(.title)
                            .foregroundStyle(.secondary)
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
                                .fill(Color.red)
                                .frame(width: 70, height: 70)
                            
                            Image(systemName: isThisFilePlaying ? "pause.fill" : "play.fill")
                                .font(.title)
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .animation(.none, value: isThisFilePlaying)
                    
                    Button(action: {}) {
                        Image(systemName: "forward.fill")
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }
                    .disabled(true)
                }
                
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "speaker.fill")
                            .foregroundStyle(.secondary)
                        
                        Slider(value: $volume, in: 0...1)
                            .onChange(of: volume) {
                                audioManager.setVolume(volume)
                            }
                            .tint(.red)
                        
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
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
