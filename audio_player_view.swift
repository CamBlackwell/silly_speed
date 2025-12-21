import SwiftUI

struct AudioPlayerView: View {
    let audioFile: AudioFile
    @ObservedObject var audioManager: AudioManager
    @State private var volume: Float = 1.0
    @State var color: Color = .blue
    @State private var isScrubbing: Bool = false
    @State private var sliderValue: Double = 0
    @State private var isDragging = false
    
    var body: some View {
        ZStack {
            Color(red: 0.15, green: 0.15, blue: 0.15)
                .ignoresSafeArea()
            
                VStack(spacing: 8) {
                    
                    Text(audioFile.fileName)
                        .font(.title2)
                        .fontDesign(.serif)
                        .fontWeight(.heavy)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)

                    algorithmSelector
                    
                    Spacer()
                    
                    GoniometerView(manager: audioManager.goniometerManager)
                    
                    Spacer()

                    tempoControl
                    
                    pitchControl
                    
                    timeSlider
                    
                    playbackControls
                    
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
    
    private var algorithmSelector: some View {
        let implementedAlgorithms = PitchAlgorithm.allCases.filter { $0.isImplemented }
        
        return Menu {
            ForEach(implementedAlgorithms, id: \.self) { algorithm in
                Button(action: {
                    audioManager.changeAlgorithm(to: algorithm)
                }) {
                    HStack {
                        Text(algorithm.rawValue)
                        Spacer()
                        if audioManager.selectedAlgorithm == algorithm {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                Text("\(audioManager.selectedAlgorithm.rawValue)")
                    .font(.subheadline)
                    .tint(.white)
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .tint(.white)
            }
            .padding()
            .glassEffect(.clear)
            //.background(Color.white.opacity(0.1))
            //.cornerRadius(12)
        }
        .padding(.horizontal)
    }



    private var timeSlider: some View {
        VStack(spacing: 8) {
            Slider(
                value: $sliderValue,
                in: 0...max(audioManager.duration, 0.01),
                onEditingChanged: { editing in
                    isDragging = editing
                    if !editing {
                        audioManager.seek(to: sliderValue)
                    }
                }
            )
            .tint(.red)
            .disabled(audioManager.currentlyPlayingID != audioFile.id)
            .onChange(of: audioManager.currentTime) {
                if !isDragging {
                    sliderValue = audioManager.currentTime
                }
            }
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
                        //.glassEffect(.clear.tint(.red).interactive())
                    
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
                Spacer()
                resetTempoButton
            }
            
            Slider(value: Binding(
                get: { audioManager.tempo },
                set: { audioManager.setTempo($0) }
            ), in: 0.1...1.9)
            .tint(.red)

            HStack {
                Text("0.1x")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("1.0x")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("2.0x")
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
                Spacer()
                resetPitchButton
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
    
    private var resetTempoButton: some View {
        HStack {
            Button(action: {
                audioManager.setTempo(1.0)
                
            }) {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    //Text("Reset Speed")
                }
                .font(.subheadline)
                .foregroundStyle(.red)
            }
            .padding(.horizontal)
        }
    }
    
    private var resetPitchButton: some View {
        HStack {
            Button(action: {
                audioManager.setPitch(1.0)
                
            }) {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    //Text("Reset Pitch")
                }
                .font(.subheadline)
                .foregroundStyle(.red)
            }
            .padding(.horizontal)
        }
    }
}
