import SwiftUI
import PhotosUI

struct PlaylistDetailView: View {
    let playlist: Playlist
    @ObservedObject var audioManager: AudioManager
    @Binding var navigateToPlayer: Bool
    @Binding var selectedAudioFile: AudioFile?
    @Binding var showingRenameAlert: Bool
    @Binding var renamingAudioFile: AudioFile?
    @Binding var newFileName: String
    @State private var isReorderMode = false
    @State private var showingShareSheet = false
    @State private var shareURL: URL?
    @State private var showingAudioArtworkPicker = false
    @State private var artworkAudioFile: AudioFile?
    
    var playlistSongs: [AudioFile] {
        audioManager.getAudioFiles(for: playlist)
    }
    
    var body: some View {
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
                                isFromSongsTab: false,
                                isReorderMode: isReorderMode,
                                showingShareSheet: $showingShareSheet,
                                shareURL: $shareURL,
                                showingAudioArtworkPicker: $showingAudioArtworkPicker,
                                artworkAudioFile: $artworkAudioFile
                            )
                            .swipeActions {
                                if !isReorderMode {
                                    Button(role: .destructive) {
                                        audioManager.removeAudioFile(audioFile, from: playlist)
                                    } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .onMove { source, destination in
                            var songs = playlistSongs
                            songs.move(fromOffsets: source, toOffset: destination)
                            let reorderedIDs = songs.map { $0.id }
                            audioManager.updatePlaylistOrder(playlist, with: reorderedIDs)
                        }
                        .listRowBackground(Color(red: 0.15, green: 0.15, blue: 0.15))
                    }
                    .scrollContentBackground(.hidden)
                    .environment(\.editMode, isReorderMode ? .constant(.active) : .constant(.inactive))
                    
                    if audioManager.currentlyPlayingID != nil {
                        MiniPlayerBar(
                            audioManager: audioManager,
                            navigateToPlayer: $navigateToPlayer,
                            selectedAudioFile: $selectedAudioFile
                        )
                    }
                }
            }
        }
        .background(Color(red: 0.15, green: 0.15, blue: 0.15))
        .navigationTitle(playlist.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isReorderMode ? "Done" : "Reorder") {
                    isReorderMode.toggle()
                }
                .foregroundStyle(.red)
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = shareURL {
                ShareSheet(activityItems: [url])
            }
        }
        .sheet(isPresented: $showingAudioArtworkPicker) {
            if let audioFile = artworkAudioFile {
                PhotoPicker{ (image: UIImage) in audioManager.setArtwork(image, for: audioFile)}
            }
        }
    }
}
