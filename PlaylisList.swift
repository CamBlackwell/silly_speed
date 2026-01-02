import SwiftUI

struct PlaylistDetailView: View {
    let playlist: Playlist
    @ObservedObject var audioManager: AudioManager
    @Binding var navigateToPlayer: Bool
    @Binding var selectedAudioFile: AudioFile?
    
    var playlistSongs: [AudioFile] {
        audioManager.getAudioFiles(for: playlist)
    }
    
    var body: some View {
        VStack {
            if playlistSongs.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 60))
                        .foregroundStyle(.red.opacity(0.8))
                    Text("This playlist is empty")
                        .foregroundStyle(.gray)
                    Text("Long press a song in the main list to add it here")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(playlistSongs) { audioFile in
                        AudioFileButton(
                            audioFile: audioFile,
                            audioManager: audioManager,
                            navigateToPlayer: $navigateToPlayer,
                            selectedAudioFile: $selectedAudioFile,
                            context: playlistSongs // Pass context here
                        )
                        .swipeActions {
                            Button(role: .destructive) {
                                audioManager.removeAudioFile(audioFile, from: playlist)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }
                    .listRowBackground(Color(red: 0.15, green: 0.15, blue: 0.15))
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color(red: 0.15, green: 0.15, blue: 0.15))
        .navigationTitle(playlist.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
