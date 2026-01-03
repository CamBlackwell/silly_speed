import SwiftUI

struct PlaylistDetailView: View {
    let playlist: Playlist
    @ObservedObject var audioManager: AudioManager
    @Binding var navigateToPlayer: Bool
    @Binding var selectedAudioFile: AudioFile?
    @Binding var showingRenameAlert: Bool
    @Binding var renamingAudioFile: AudioFile?
    @Binding var newFileName: String
    
    var playlistSongs: [AudioFile] {
        audioManager.getAudioFiles(for: playlist)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.15, green: 0.15, blue: 0.15)
                    .ignoresSafeArea()
                
                
                VStack {
                    if playlistSongs.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 60))
                                .foregroundStyle(.red.opacity(0.8))
                            Text("This playlist is empty")
                                .foregroundStyle(.gray)
                            Text("Go to Songs view and use the context menu to add songs here")
                                .font(.caption)
                                .foregroundStyle(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
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
                                    showingRenameAlert: $showingRenameAlert,
                                    renamingAudioFile: $renamingAudioFile,
                                    newFileName: $newFileName,
                                    context: playlistSongs,
                                    isFromSongsTab: false
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
                        
                        if audioManager.currentlyPlayingID != nil {
                            MiniPlayerBar(
                                audioManager: audioManager,
                                navigateToPlayer: $navigateToPlayer,
                                selectedAudioFile: $selectedAudioFile
                            )
                        }
                    }
                }
                .background(Color(red: 0.15, green: 0.15, blue: 0.15))
                .navigationTitle(playlist.name)
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}
