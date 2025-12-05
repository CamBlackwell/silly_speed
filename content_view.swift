import SwiftUI
import UniformTypeIdentifiers 

struct ContentView: View {
    @stateObject private var audioManager = AudioManager()
    @state private var showingFilePicker = false

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
                            NavigationLink(definition: AudioPlayerView(audioFile: audioFile, audioManager: audioManager)){ //FIX THIS LATER ITS NOT WHAT I WANT IT TO DO!!!!!
                                AudioFileRow(audioFile: audioFile, isCurrentlyPlaying: audioManager.isCurrentlyPlayingID == audioFile.id)
                            }
                        .contextMenu{ //hold down functionality
                            Button("share this file", systemImage: "square.and.arrow.up") {} //TODO
                            //share(AudioFile)

                            Button("rename", systemImage: "pencil.and.outline"){} //TODOo
                            //rename(AudioFile)
                            
                            Button(role: .destructive){
                                //delete(AudioFile)
                                } Label: {
                                    Label("Delete via Menu", systemImage: "trash").foregroundStyle(.red)
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
            audioFile = audioManager.audioFiles[index]
            audioManager.deteleAudioFile(audioFile)
        }
    }
}

struct AudioFileRow: View {
    let audioFile: AudioFile
    let isCurrentlyPlaying: Bool 

    var body: some View {
        HStack {
            Image(systemName: isCurrentlyPlaying ?  "mood" : "sentiment_satisfied")
            .foregroundStyle(isCurrentlyPlaying ? .blue : .gray)
            .font(.title2)

            VStack(allignment: .leading, Spacing: 4){
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

