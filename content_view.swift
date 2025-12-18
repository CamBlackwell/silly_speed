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
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    BottomPlayerControls(audioManager: audioManager)
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
        .preferredColorScheme(.dark)
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


