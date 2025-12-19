import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var audioManager = AudioManager()
    @State private var showingFilePicker = false
    @State private var navigateToPlayer = false
    @State private var selectedAudioFile: AudioFile?

    var body: some View {
        NavigationStack{
            ZStack{
                Color(red: 0.15, green: 0.15, blue: 0.15)
                                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if audioManager.audioFiles.isEmpty {
                        EmptyStateView()
                    } else {
                        AudioFilesList(
                            audioManager: audioManager,
                            navigateToPlayer: $navigateToPlayer,
                            selectedAudioFile: $selectedAudioFile,
                            onDelete: deleteFiles
                        )
                    }
                    
                    if audioManager.currentlyPlayingID != nil {
                        MiniPlayerBar(
                            audioManager: audioManager,
                            navigateToPlayer: $navigateToPlayer,
                            selectedAudioFile: $selectedAudioFile
                        )
                    }
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: { showingFilePicker = true }) {
                        Image(systemName: "plus")
                    }
                    .foregroundStyle(.red)
                }
            }
            .sheet(isPresented: $showingFilePicker) {
                DocumentPicker(audioManager: audioManager)
            }
        }
        .tint(.red)
    }
    private func deleteFiles(at offsets: IndexSet) {
        for index in offsets {
            audioManager.deleteAudioFile(audioManager.audioFiles[index])
        }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 60))
                .foregroundStyle(.red.opacity(0.8))
            
            Text("No audio Files .·°՞(¯□¯)՞°·.")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.red.opacity(0.8))
            
            Text("press the + to add files")
                .foregroundStyle(.red.opacity(0.8))
        }
    }
}

struct AudioFilesList: View {
    @ObservedObject var audioManager: AudioManager
    @Binding var navigateToPlayer: Bool
    @Binding var selectedAudioFile: AudioFile?
    let onDelete: (IndexSet) -> Void
    
    var body: some View {
        List {
            ForEach(audioManager.audioFiles) { audioFile in
                AudioFileButton(
                    audioFile: audioFile,
                    audioManager: audioManager,
                    navigateToPlayer: $navigateToPlayer,
                    selectedAudioFile: $selectedAudioFile
                )
            }
            .onDelete(perform: onDelete)
            .listRowBackground(Color(red: 0.15, green: 0.15, blue: 0.15))
        }
        .navigationDestination(isPresented: $navigateToPlayer) {
            if let audioFile = selectedAudioFile {
                AudioPlayerView(audioFile: audioFile, audioManager: audioManager)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(red: 0.15, green: 0.15, blue: 0.15))
    }
}

struct AudioFileButton: View {
    let audioFile: AudioFile
    @ObservedObject var audioManager: AudioManager
    @Binding var navigateToPlayer: Bool
    @Binding var selectedAudioFile: AudioFile?
    
    var body: some View {
        Button {
            if audioManager.currentlyPlayingID == audioFile.id {
                selectedAudioFile = audioFile
                navigateToPlayer = true
            } else {
                audioManager.play(audioFile: audioFile)
            }
        } label: {
            AudioFileRow(
                audioFile: audioFile,
                isCurrentlyPlaying: audioManager.currentlyPlayingID == audioFile.id
            )
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            AudioFileContextMenu(audioFile: audioFile, audioManager: audioManager)
        }
    }
}

struct AudioFileContextMenu: View {
    let audioFile: AudioFile
    @ObservedObject var audioManager: AudioManager
    
    var body: some View {
        Button("share this file", systemImage: "square.and.arrow.up") {}
        Button("rename", systemImage: "pencil.and.outline") {}
        Button(role: .destructive) {
            audioManager.deleteAudioFile(audioFile)
        } label: {
            Label("Delete via Menu", systemImage: "trash")
        }
    }
}

struct BottomPlayerControls: View {
    @ObservedObject var audioManager: AudioManager
    
    var body: some View {
        if audioManager.currentlyPlayingID != nil {
            Button(action: {}) {
                Image(systemName: "backward.fill")
                    .font(.title)
                    .foregroundStyle(.secondary)
            }
            .disabled(true)
            
            Spacer()
            
            Button {
                audioManager.togglePlayPause()
            } label: {
                Image(systemName: audioManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
            }
            
            Spacer()
            
            Button(action: {}) {
                Image(systemName: "pencil.and.outline")
                    .font(.title)
                    .foregroundStyle(.secondary)
            }
            .disabled(true)
        }
    }
}

struct AudioFileRow: View {
    let audioFile: AudioFile
    let isCurrentlyPlaying: Bool

    var body: some View {
        HStack {
            Image(systemName: isCurrentlyPlaying ?  "face.smiling.fill" : "face.smiling")
            .foregroundStyle(isCurrentlyPlaying ? .red : .gray)
            .font(.title2)

            VStack(alignment: .leading, spacing: 4){
                Text(audioFile.fileName)
                    .font(.headline)
                    .foregroundStyle(isCurrentlyPlaying ? .red : .gray)

                
                HStack{
                    Text(audioFile.dateAdded, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatTime(audioFile.audioDuration))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if isCurrentlyPlaying{
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundStyle(.red)
                .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
    private func formatTime(_ time: Float) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct DocumentPicker: UIViewControllerRepresentable{
    let audioManager: AudioManager
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController{
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.audio])
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker

        init(_ parent: DocumentPicker){
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]){
            for url in urls {
                parent.audioManager.importAudioFile(from: url)
            }
            parent.dismiss()
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController){
            parent.dismiss()
        }

    }
}

struct MiniPlayerBar: View {
    @ObservedObject var audioManager: AudioManager
    @Binding var navigateToPlayer: Bool
    @Binding var selectedAudioFile: AudioFile?
    
    var currentAudioFile: AudioFile? {
        audioManager.audioFiles.first { $0.id == audioManager.currentlyPlayingID }
    }
    
    var body: some View {
        if let audioFile = currentAudioFile {
            Button {
                selectedAudioFile = audioFile
                navigateToPlayer = true
            } label: {
                HStack(spacing: 12) {
                    // Artwork
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [.red, .pink]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "music.note")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }
                    
                    // Track info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(audioFile.fileName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                            .foregroundStyle(.primary)
                        
                        Text(formatTime(audioFile.audioDuration))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    // Controls
                    HStack(spacing: 20) {
                        Button {
                            // Skip backward (disabled for now)
                        } label: {
                            Image(systemName: "backward.fill")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                        .disabled(true)
                        .buttonStyle(PlainButtonStyle())
                        
                        Button {
                            audioManager.togglePlayPause()
                        } label: {
                            Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title2)
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button {
                            // Skip forward (disabled for now)
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                        .disabled(true)
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.1), radius: 10, y: -5)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
    
    private func formatTime(_ time: Float) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}


