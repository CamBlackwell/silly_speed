import SwiftUI
import UniformTypeIdentifiers 

struct ContentView: View {
    @StateObject private var audioManager = AudioManager()
    @State private var showingFilePicker = false

    var body: some View {
        NavigationStack{
            ZStack{
                if audioManager.audioFiles.isEmpty{
                    VStack(spacing: 20){
                        Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)

                        Text("No audio Files .·°՞(¯□¯)՞°·.")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                        Text("press the + to add files")
                        .foregroundStyle(.secondary)
                    }
                } else {
                    List{
                        ForEach(audioManager.audioFiles) {audioFile in
                            NavigationLink(destination: AudioPlayerView(audioFile: audioFile, audioManager: audioManager)){ //FIX THIS LATER ITS NOT WHAT I WANT IT TO DO!!!!!
                                AudioFileRow(audioFile: audioFile, isCurrentlyPlaying: audioManager.currentlyPlayingID == audioFile.id)
                            }
                        .contextMenu{ //hold down functionality
                            Button("share this file", systemImage: "square.and.arrow.up") {} //TODO
                            //share(AudioFile)

                            Button("rename", systemImage: "pencil.and.outline"){} //TODOo
                            //rename(AudioFile)
                            
                            Button(role: .destructive){
                                //delete(AudioFile)
                                } label: {
                                    Label("Delete via Menu", systemImage: "trash")
                                }
                            }
                        }
                        .onDelete(perform: deleteFiles)
                    }
                }
            }
            .navigationTitle("Audio Player or whatever")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing){
                    Button(action: {showingFilePicker = true}) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingFilePicker) {
                DocumentPicker(audioManager: audioManager)
            }
        }
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
            .foregroundStyle(isCurrentlyPlaying ? .blue : .gray)
            .font(.title2)

            VStack(alignment: .leading, spacing: 4){
                Text(audioFile.fileName)
                    .font(.headline)

                Text(audioFile.dateAdded, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isCurrentlyPlaying{
                Image(systemName: "speaker.wave.2.fill")
                .foregroundStyle(.blue)
                .font(.caption)
            }
        }
        .padding(.vertical, 4)
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