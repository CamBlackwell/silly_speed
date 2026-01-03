import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var audioManager = AudioManager()
    @State private var showingFilePicker = false
    @State private var navigateToPlayer = false
    @State private var selectedAudioFile: AudioFile?
    
    @State private var libraryFilter: LibraryFilter = .songs
    @State private var showingCreatePlaylistAlert = false
    @State private var newPlaylistName = ""
    @State private var showingRenameAlert = false
    @State private var renamingAudioFile: AudioFile?
    @State private var newFileName = ""
    @State private var showingRenamePlaylistAlert = false
    @State private var renamingPlaylist: Playlist?
    @State private var newPlaylistNameRename = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.15, green: 0.15, blue: 0.15)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if audioManager.audioFiles.isEmpty && audioManager.playlists.isEmpty {
                        EmptyStateView()
                    } else {
                        LibraryListView(
                            audioManager: audioManager,
                            filter: libraryFilter,
                            navigateToPlayer: $navigateToPlayer,
                            selectedAudioFile: $selectedAudioFile,
                            showingRenameAlert: $showingRenameAlert,
                            renamingAudioFile: $renamingAudioFile,
                            newFileName: $newFileName,
                            showingRenamePlaylistAlert: $showingRenamePlaylistAlert,
                            renamingPlaylist: $renamingPlaylist,
                            newPlaylistNameRename: $newPlaylistNameRename
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
                
                VStack {
                    HStack {
                        Button(action: {
                            libraryFilter = libraryFilter == .songs ? .playlists : .songs
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: libraryFilter == .songs ? "music.note" : "music.note.list")
                                    .font(.title2)
                                    .foregroundStyle(.red)
                                Text(libraryFilter.rawValue)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .glassEffect()
                            .foregroundStyle(.clear)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.leading, 20)
                        .padding(.top, 10)

                        Spacer()
                        
                        Menu {
                            Button {
                                showingFilePicker = true
                            } label: {
                                Label("Add Songs", systemImage: "music.note.list")
                            }
                            Button {
                                newPlaylistName = ""
                                showingCreatePlaylistAlert = true
                            } label: {
                                Label("Create Playlist", systemImage: "text.badge.plus")
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .opacity(0.50)
                                    .frame(width: 60, height: 60)
                                    .glassEffect()
                                    .foregroundStyle(.clear)
                                
                                Image(systemName: "plus")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding(.trailing, 20)
                        .padding(.top, 10)
                    }
                    
                    Spacer()
                }
            }
            .sheet(isPresented: $showingFilePicker) {
                DocumentPicker(audioManager: audioManager)
            }
            .alert("New Playlist", isPresented: $showingCreatePlaylistAlert) {
                TextField("Playlist Name", text: $newPlaylistName)
                Button("Cancel", role: .cancel) { }
                Button("Create") {
                    if !newPlaylistName.isEmpty {
                        audioManager.createPlaylist(name: newPlaylistName)
                    }
                }
            }
            .alert("Rename File", isPresented: $showingRenameAlert) {
                TextField("New Name", text: $newFileName)
                Button("Cancel", role: .cancel) {
                    renamingAudioFile = nil
                    newFileName = ""
                }
                Button("Rename") {
                    if let audioFile = renamingAudioFile, !newFileName.isEmpty {
                        audioManager.renameAudioFile(audioFile, to: newFileName)
                    }
                    renamingAudioFile = nil
                    newFileName = ""
                }
            } message: {
                if let audioFile = renamingAudioFile {
                    Text("Enter a new name for '\(audioFile.fileName)'")
                }
            }
            .alert("Rename Playlist", isPresented: $showingRenamePlaylistAlert) {
                TextField("New Name", text: $newPlaylistNameRename)
                Button("Cancel", role: .cancel) {
                    renamingPlaylist = nil
                    newPlaylistNameRename = ""
                }
                Button("Rename") {
                    if let playlist = renamingPlaylist, !newPlaylistNameRename.isEmpty {
                        audioManager.renamePlaylist(playlist, to: newPlaylistNameRename)
                    }
                    renamingPlaylist = nil
                    newPlaylistNameRename = ""
                }
            } message: {
                if let playlist = renamingPlaylist {
                    Text("Enter a new name for '\(playlist.name)'")
                }
            }
            .navigationDestination(isPresented: $navigateToPlayer) {
                if let audioFile = selectedAudioFile {
                    AudioPlayerView(audioFile: audioFile, audioManager: audioManager)
                }
            }
        }
        .navigationBarHidden(true)
        .tint(.red)
    }
}

struct LibraryListView: View {
    @ObservedObject var audioManager: AudioManager
    let filter: LibraryFilter
    @Binding var navigateToPlayer: Bool
    @Binding var selectedAudioFile: AudioFile?
    @Binding var showingRenameAlert: Bool
    @Binding var renamingAudioFile: AudioFile?
    @Binding var newFileName: String
    @Binding var showingRenamePlaylistAlert: Bool
    @Binding var renamingPlaylist: Playlist?
    @Binding var newPlaylistNameRename: String
    
    var body: some View {
        switch filter {
        case .songs:
            SongsListView(
                audioManager: audioManager,
                navigateToPlayer: $navigateToPlayer,
                selectedAudioFile: $selectedAudioFile,
                showingRenameAlert: $showingRenameAlert,
                renamingAudioFile: $renamingAudioFile,
                newFileName: $newFileName
            )
        case .playlists:
            PlaylistsListView(
                audioManager: audioManager,
                navigateToPlayer: $navigateToPlayer,
                selectedAudioFile: $selectedAudioFile,
                showingRenameAlert: $showingRenameAlert,
                renamingAudioFile: $renamingAudioFile,
                newFileName: $newFileName,
                showingRenamePlaylistAlert: $showingRenamePlaylistAlert,
                renamingPlaylist: $renamingPlaylist,
                newPlaylistNameRename: $newPlaylistNameRename
            )
        }
    }
}

struct SongsListView: View {
    @ObservedObject var audioManager: AudioManager
    @Binding var navigateToPlayer: Bool
    @Binding var selectedAudioFile: AudioFile?
    @Binding var showingRenameAlert: Bool
    @Binding var renamingAudioFile: AudioFile?
    @Binding var newFileName: String
    
    var sortedSongs: [AudioFile] {
        audioManager.sortedAudioFiles
    }
    
    var body: some View {
        List {
            
            Color.clear
                .frame(height: 30)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            
            ForEach(sortedSongs) { audioFile in
                AudioFileButton(
                    audioFile: audioFile,
                    audioManager: audioManager,
                    navigateToPlayer: $navigateToPlayer,
                    selectedAudioFile: $selectedAudioFile,
                    showingRenameAlert: $showingRenameAlert,
                    renamingAudioFile: $renamingAudioFile,
                    newFileName: $newFileName,
                    context: sortedSongs,
                    isFromSongsTab: true
                )
                .listRowBackground(Color(red: 0.15, green: 0.15, blue: 0.15))
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(red: 0.15, green: 0.15, blue: 0.15))
    }
}

struct PlaylistsListView: View {
    @ObservedObject var audioManager: AudioManager
    @Binding var navigateToPlayer: Bool
    @Binding var selectedAudioFile: AudioFile?
    @Binding var showingRenameAlert: Bool
    @Binding var renamingAudioFile: AudioFile?
    @Binding var newFileName: String
    @Binding var showingRenamePlaylistAlert: Bool
    @Binding var renamingPlaylist: Playlist?
    @Binding var newPlaylistNameRename: String
    
    var sortedPlaylists: [Playlist] {
        audioManager.playlists.sorted { $0.dateAdded > $1.dateAdded }
    }
    
    var body: some View {
        List {
            Color.clear
                .frame(height: 30)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            
            ForEach(sortedPlaylists) { playlist in
                NavigationLink(destination: PlaylistDetailView(
                    playlist: playlist,
                    audioManager: audioManager,
                    navigateToPlayer: $navigateToPlayer,
                    selectedAudioFile: $selectedAudioFile,
                    showingRenameAlert: $showingRenameAlert,
                    renamingAudioFile: $renamingAudioFile,
                    newFileName: $newFileName
                )) {
                    PlaylistRowView(playlist: playlist, audioManager: audioManager)
                }
                .listRowBackground(Color(red: 0.15, green: 0.15, blue: 0.15))
                .listRowSeparator(.hidden)
                .contextMenu {
                    Button("rename", systemImage: "pencil.and.outline") {
                        renamingPlaylist = playlist
                        newPlaylistNameRename = playlist.name
                        showingRenamePlaylistAlert = true
                    }
                    
                    Button(role: .destructive) {
                        audioManager.deletePlaylist(playlist)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions {
                    Button(role: .destructive) {
                        audioManager.deletePlaylist(playlist)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(red: 0.15, green: 0.15, blue: 0.15))
    }
}

struct PlaylistRowView: View {
    let playlist: Playlist
    @ObservedObject var audioManager: AudioManager
    
    var playlistSongs: [AudioFile] {
        audioManager.getAudioFiles(for: playlist)
    }
    
    var body: some View {
        HStack {
            Image(systemName: "music.note.list")
                .font(.title2)
                .foregroundStyle(.red)
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(playlist.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("\(playlistSongs.count) songs")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundStyle(.gray)
        }
        .padding(.vertical, 8)
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
        .frame(maxHeight: .infinity)
    }
}

struct AudioFileButton: View {
    let audioFile: AudioFile
    @ObservedObject var audioManager: AudioManager
    @Binding var navigateToPlayer: Bool
    @Binding var selectedAudioFile: AudioFile?
    @Binding var showingRenameAlert: Bool
    @Binding var renamingAudioFile: AudioFile?
    @Binding var newFileName: String
    
    var context: [AudioFile]? = nil
    var isFromSongsTab: Bool = false
    
    var body: some View {
        Button {
            let isSameSong = audioManager.currentlyPlayingID == audioFile.id
            let isSameContext = audioManager.playingFromSongsTab == isFromSongsTab
            
            if isSameSong && isSameContext {
                selectedAudioFile = audioFile
                navigateToPlayer = true
            } else {
                audioManager.play(audioFile: audioFile, context: context, fromSongsTab: isFromSongsTab)
            }
        } label: {
            AudioFileRow(
                audioFile: audioFile,
                isCurrentlyPlaying: audioManager.currentlyPlayingID == audioFile.id && audioManager.playingFromSongsTab == isFromSongsTab
            )
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            AudioFileContextMenu(
                audioFile: audioFile,
                audioManager: audioManager,
                showingRenameAlert: $showingRenameAlert,
                renamingAudioFile: $renamingAudioFile,
                newFileName: $newFileName
            )
        }
    }
}

struct AudioFileContextMenu: View {
    let audioFile: AudioFile
    @ObservedObject var audioManager: AudioManager
    @Binding var showingRenameAlert: Bool
    @Binding var renamingAudioFile: AudioFile?
    @Binding var newFileName: String
    
    
    var body: some View {
        Button("share this file", systemImage: "square.and.arrow.up") {}
        Button("rename", systemImage: "pencil.and.outline") {
            renamingAudioFile = audioFile
            newFileName = audioFile.fileName
            showingRenameAlert = true
        }
        
        Menu {
            ForEach(audioManager.playlists) { playlist in
                Button(playlist.name) {
                    audioManager.addAudioFile(audioFile, to: playlist)
                }
            }
        } label: {
            Label("Add to Playlist", systemImage: "plus")
        }

        Button(role: .destructive) {
            audioManager.deleteAudioFile(audioFile)
        } label: {
            Label("Delete via Menu", systemImage: "trash")
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
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(audioFile.fileName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                                .foregroundStyle(.primary)
                            
                            HStack {
                                Text(formatTime(Float(audioManager.currentTime)))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                 
                                Text(formatTime(audioFile.audioDuration))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(height: 3)
                                     
                                    Rectangle()
                                        .fill(Color.red)
                                        .frame(width: geometry.size.width * progressPercentage, height: 3)
                                }
                            }
                            .frame(height: 3)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)

                        }
                         
                        Spacer()
                         
                        HStack(spacing: 20) {
                            Button(action: { audioManager.skipPreviousSong()}) {
                                Image(systemName: "backward.fill")
                                    .font(.title)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                             
                            Button {
                                audioManager.togglePlayPause()
                            } label: {
                                Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.title2)
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(PlainButtonStyle())
                             
                            Button(action: { audioManager.skipNextSong() }) {
                                Image(systemName: "forward.fill")
                                    .font(.title)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                   
                }
            }
            .buttonStyle(PlainButtonStyle())
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .padding(.bottom, 8)
            .padding(.horizontal, 4)
        }

    }
    
    private var progressPercentage: CGFloat {
        guard audioManager.duration > 0 else { return 0 }
        return CGFloat(audioManager.currentTime / audioManager.duration)
    }
    
    private func formatTime(_ time: Float) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
