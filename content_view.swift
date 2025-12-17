import SwiftUI
import UniformTypeIdentifiers 

struct ContentView: View {
    @StateObject private var audioManager = AudioManager()
    @State private var showingFilePicker = false

    var body: some View {
        NavigationStack{
            ZStack{
                Color(red: 0.15, green: 0.15, blue: 0.15)
                    .ignoresSafeArea()
                
                if audioManager.audioFiles.isEmpty{
                    VStack(spacing: 20){
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
                } else {
                    List{
                        ForEach(audioManager.audioFiles) {audioFile in
                            NavigationLink(destination: AudioPlayerView(audioFile: audioFile, audioManager: audioManager)){ //FIX THIS LATER ITS NOT WHAT I WANT IT TO DO!!!!!
                                AudioFileRow(audioFile: audioFile, isCurrentlyPlaying: audioManager.currentlyPlayingID == audioFile.id)
                            }
                            .simultaneousGesture(TapGesture().onEnded{ audioManager.play(audioFile: audioFile)})
                        .contextMenu{ //hold down functionality
                            Button("share this file", systemImage: "square.and.arrow.up") {} //TODO
                            //share(AudioFile)

                            Button("rename", systemImage: "pencil.and.outline"){} //TODOo
                            //rename(AudioFile)
                            
                            Button(role: .destructive){
                                audioManager.deleteAudioFile(audioFile)
                                } label: {
                                    Label("Delete via Menu", systemImage: "trash")
                                }
                            }
                        }
                        .onDelete(perform: deleteFiles)
                        .listRowBackground(Color(red: 0.15, green: 0.15, blue: 0.15))
                    }
                    
                    .scrollContentBackground(.hidden)
                    .background(Color(red: 0.15, green: 0.15, blue: 0.15))
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar){
                    Spacer()
                    Spacer()
                    Button(action: {showingFilePicker = true}) {
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
    private func deleteFiles(at offsets: IndexSet){
        for index in offsets {
            let audioFile = audioManager.audioFiles[index]
            audioManager.deleteAudioFile(audioFile)
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
