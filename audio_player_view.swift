import SwiftUI
import Combine

struct AudioPlayerView: View {
    let audioFile: AudioFile
    @ObservedObject var audioManager: AudioManager
    @State private var volume: Float = 1.0
    @State private var isScrubbing: Bool = false
    @State private var sliderValue: Double = 0
    @State private var isDragging = false
   

    var body: some View {
        ZStack {
            Color(red: 0.15, green: 0.15, blue: 0.15)
                .ignoresSafeArea()
            
            
            VStack(spacing: 8) {
                Text(activeFile?.fileName ?? audioFile.fileName)
                    .font(.title2)
                    .fontDesign(.serif)
                    .fontWeight(.heavy)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                HStack {
                    algorithmSelector
                    visualizationSelector
                }
                
                visualizationView
                
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
        .onChange(of: audioManager.currentlyPlayingID) { oldID, newID in
            if let newID = newID, newID != audioFile.id {
                sliderValue = 0
            }
        }
    }
    
    
    // MARK: - Visualization Selector
    private var visualizationSelector: some View {
        Menu {
            ForEach(VisualizationMode.allCases, id: \.self) { mode in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        audioManager.visualizationMode = mode
                        audioManager.saveVisualizationMode()
                    }
                }) {
                    HStack {
                        Label(mode.rawValue, systemImage: mode.icon)
                        Spacer()
                        if audioManager.visualizationMode == mode {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                Image(systemName: audioManager.visualizationMode.icon)
                    .font(.subheadline)
                    .tint(.white)
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .tint(.white)
            }
            .padding()
        }
    }
    

    
    // MARK: - Dynamic Visualization View
    @ViewBuilder
    private var visualizationView: some View {
        switch audioManager.visualizationMode {
        case .both:
            VStack(spacing: 20) {
                SpectrumView(analyzer: audioManager.audioAnalyzer)
                    .frame(height: 140)
                    .transition(.move(edge: .top).combined(with: .opacity))
                
                GoniometerView(analyzer: audioManager.audioAnalyzer)
                    .frame(height: 150)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
        case .spectrumOnly:
            SpectrumView(analyzer: audioManager.audioAnalyzer)
                .frame(maxHeight: .infinity)
                .transition(.scale.combined(with: .opacity))
            
        case .goniometerOnly:
            GoniometerView(analyzer: audioManager.audioAnalyzer)
                .frame(maxHeight: .infinity)
                .transition(.scale.combined(with: .opacity))
        }
    }
    
    private var activeFile: AudioFile? {
        audioManager.audioFiles.first(where: { $0.id == audioManager.currentlyPlayingID })
    }
    
    private var isThisFilePlaying: Bool {
        audioManager.isPlaying && audioManager.currentlyPlayingID != nil
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
        }
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
            .disabled(audioManager.currentlyPlayingID == nil)
            .onChange(of: audioManager.currentTime) { oldTime, newTime in
                if !isDragging {
                    sliderValue = newTime
                }
            }
            .onAppear { sliderValue = audioManager.currentTime }
            HStack {
                Text(formatTime(isDragging ? sliderValue : audioManager.currentTime))
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
        ZStack {
            HStack(spacing: 40) {
                Button(action: { audioManager.skipPreviousSong()}) {
                    Image(systemName: "backward.fill")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    if audioManager.currentlyPlayingID != nil {
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
                
                Button(action: { audioManager.skipNextSong() }) {
                    Image(systemName: "forward.fill")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(audioManager.audioFiles.count < 2)
            }
            
            HStack {
                Spacer()
                Button(action: {
                    audioManager.isLooping.toggle()
                }) {
                    Image(systemName: audioManager.isLooping ? "repeat.1" : "repeat")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(audioManager.isLooping ? .red : .secondary)
                        .padding(10)
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }
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
    
    private var resetTempoButton: some View {
        Button(action: {
            audioManager.setTempo(1.0)
        }) {
            Image(systemName: "arrow.counterclockwise")
                .font(.subheadline)
                .foregroundStyle(.red)
        }
        .padding(.horizontal)
    }
    
    private var resetPitchButton: some View {
        Button(action: {
            audioManager.setPitch(0.0)
        }) {
            Image(systemName: "arrow.counterclockwise")
                .font(.subheadline)
                .foregroundStyle(.red)
        }
        .padding(.horizontal)
    }
    
}



