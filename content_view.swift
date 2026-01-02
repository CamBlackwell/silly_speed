import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var audioManager = AudioManager()
    @State private var showingFilePicker = false
    @State private var navigateToPlayer = false
    @State private var selectedAudioFile: AudioFile?
    
    @State private var libraryFilter: LibraryFilter = .all
    @State private var showingCreatePlaylistAlert = false
    @State private var newPlaylistName = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.15, green: 0.15, blue: 0.15)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    HStack {
                        Menu {
                            Picker("Filter", selection: $libraryFilter) {
                                ForEach(LibraryFilter.allCases, id: \.self) { filter in
                                    Text(filter.rawValue).tag(filter)
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(libraryFilter.rawValue)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                Image(systemName: "chevron.down")
                                    .font(.subheadline)
                                    .foregroundStyle(.red)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Capsule())
                        }
                        .padding(.leading)
                        .padding(.top, 10)
                        
                        Spacer()
                    }
                    
                    if audioManager.audioFiles.isEmpty && audioManager.playlists.isEmpty {
                        EmptyStateView()
                    } else {
                        MixedLibraryList(
                            audioManager: audioManager,
                            filter: libraryFilter,
                            navigateToPlayer: $navigateToPlayer,
                            selectedAudioFile: $selectedAudioFile
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
                    Spacer()
                    HStack {
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
                                    .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                                
                                Image(systemName: "plus")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, audioManager.currentlyPlayingID != nil ? 90 : 20)
                    }
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
            .navigationDestination(isPresented: $navigateToPlayer) {
                 if let audioFile = selectedAudioFile {
                     AudioPlayerView(audioFile: audioFile, audioManager: audioManager)
                 }
            }
        }
        .tint(.red)
    }
}

struct MixedLibraryList: View {
    @ObservedObject var audioManager: AudioManager
    let filter: LibraryFilter
    @Binding var navigateToPlayer: Bool
    @Binding var selectedAudioFile: AudioFile?
    
    @State private var expandedPlaylists: Set<UUID> = []
    
    var mixedList: [LibraryItem] {
        var items: [LibraryItem] = []
        if filter == .all || filter == .songs {
            items.append(contentsOf: audioManager.audioFiles.map { .song($0) })
        }
        if filter == .all || filter == .playlists {
            items.append(contentsOf: audioManager.playlists.map { .playlist($0) })
        }
        return items.sorted { $0.dateAdded > $1.dateAdded }
    }
    
    var body: some View {
        List {
            ForEach(mixedList) { item in
                switch item {
                case .song(let audioFile):
                    AudioFileButton(
                        audioFile: audioFile,
                        audioManager: audioManager,
                        navigateToPlayer: $navigateToPlayer,
                        selectedAudioFile: $selectedAudioFile
                    )
                    .listRowBackground(Color(red: 0.15, green: 0.15, blue: 0.15))
                    .listRowSeparator(.hidden)

                case .playlist(let playlist):
                    PlaylistAccordionRow(
                        playlist: playlist,
                        isExpanded: expandedPlaylists.contains(playlist.id),
                        audioManager: audioManager,
                        navigateToPlayer: $navigateToPlayer,
                        selectedAudioFile: $selectedAudioFile,
                        toggleExpansion: {
                            if expandedPlaylists.contains(playlist.id) {
                                expandedPlaylists.remove(playlist.id)
                            } else {
                                expandedPlaylists.insert(playlist.id)
                            }
                        }
                    )
                    .listRowBackground(Color(red: 0.15, green: 0.15, blue: 0.15))
                    .listRowSeparator(.hidden)
                    .swipeActions {
                        Button(role: .destructive) {
                            audioManager.deletePlaylist(playlist)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(red: 0.15, green: 0.15, blue: 0.15))
    }
}

struct PlaylistAccordionRow: View {
    let playlist: Playlist
    let isExpanded: Bool
    @ObservedObject var audioManager: AudioManager
    @Binding var navigateToPlayer: Bool
    @Binding var selectedAudioFile: AudioFile?
    let toggleExpansion: () -> Void
    
    var playlistSongs: [AudioFile] {
        audioManager.getAudioFiles(for: playlist)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation(.spring()) { toggleExpansion() } }) {
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
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                if playlistSongs.isEmpty {
                    Text("No songs. Long press songs in main list to add.")
                        .font(.caption)
                        .foregroundStyle(.gray)
                        .padding(.leading, 40)
                        .padding(.bottom, 8)
                } else {
                    ForEach(playlistSongs) { file in
                        AudioFileButton(
                            audioFile: file,
                            audioManager: audioManager,
                            navigateToPlayer: $navigateToPlayer,
                            selectedAudioFile: $selectedAudioFile,
                            context: playlistSongs
                        )
                        .padding(.leading, 20)
                        .padding(.vertical, 4)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                audioManager.removeAudioFile(file, from: playlist)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }
                }
            }
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
        .frame(maxHeight: .infinity)
    }
}

struct AudioFileButton: View {
    let audioFile: AudioFile
    @ObservedObject var audioManager: AudioManager
    @Binding var navigateToPlayer: Bool
    @Binding var selectedAudioFile: AudioFile?
    
    var context: [AudioFile]? = nil
    
    var body: some View {
        Button {
            if audioManager.currentlyPlayingID == audioFile.id {
                selectedAudioFile = audioFile
                navigateToPlayer = true
            } else {
                audioManager.play(audioFile: audioFile, context: context)
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
