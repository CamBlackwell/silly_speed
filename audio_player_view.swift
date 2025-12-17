import SwiftUI

struct AudioPlayerView: View {
    let audioFile: AudioFile
    @ObservedObject var audioManager: AudioManager
    @State private var volume: Float = 1.0
    @State var color: Color = .blue
    @State private var isScrubbing: Bool = false
    
    var body: some View {
        ZStack {
            Color(red: 0.15, green: 0.15, blue: 0.15)
                .ignoresSafeArea()
            
            ScrollView {
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
                    
                    timeSlider
                    
                    playbackControls
                    
                    pitchControl
                    
                    tempoControl
                    
                    resetButton
                    
                    Spacer()
                }
                .padding()
            }
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
    
    private var algorithmSelector: some View {
        Menu {
            ForEach(PitchAlgorithm.allCases, id: \.self) { algorithm in
                Button(action: {
                    audioManager.changeAlgorithm(to: algorithm)
                }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(algorithm.rawValue)
                            if !algorithm.isImplemented {
                                Text("Coming Soon")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if audioManager.selectedAlgorithm == algorithm {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                //.disabled(!algorithm.isImplemented)
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Algorithm")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(audioManager.selectedAlgorithm.rawValue)
                        .font(.subheadline)
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(10)
        }
        .padding(.horizontal)
    }
    
    private var timeSlider: some View {
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
    }
    
    private var playbackControls: some View {
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
    }
    
    private var tempoControl: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Speed")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(audioManager.tempo, specifier: "%.2f")x")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            Slider(value: Binding(
                get: { audioManager.tempo },
                set: { audioManager.setTempo($0) }
            ), in: 0.25...4.0)
            .tint(.red)
            
            HStack {
                Text("0.25x")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("1.0x")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("4.0x")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }
    
    private var pitchControl: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Pitch")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(audioManager.pitch / 100, specifier: "%.1f") semitones")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            Slider(value: Binding(
                get: { audioManager.pitch },
                set: { audioManager.setPitch($0) }
            ), in: -2400...2400)
            .tint(.red)
            
            HStack {
                Text("-2 oct")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Normal")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("+2 oct")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }
    
    private var volumeControl: some View {
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
    }
    
    private var resetButton: some View {
        HStack {
            Button(action: {
                audioManager.setTempo(1.0)
                
            }) {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset Speed")
                }
                .font(.subheadline)
                .foregroundStyle(.red)
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
            }
            .padding(.horizontal)
            Button(action: {
                audioManager.setPitch(0.0)
                
            }) {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset Pitch")
                }
                .font(.subheadline)
                .foregroundStyle(.red)
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
            }
            .padding(.horizontal)
        }
    }
}
