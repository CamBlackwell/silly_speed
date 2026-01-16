import Foundation
import SwiftUI
import Combine

@MainActor
final class AudioLibraryService: ObservableObject {
    @Published private(set) var audioFiles: [AudioFile] = []
    @Published private(set) var playlists: [Playlist] = []
    @Published private(set) var masterPlaylistID: UUID?
    private let storage: LibraryStorage
    private let artworkStore: ArtworkStore
    
    init(storage: LibraryStorage, artworkStore: ArtworkStore) {
        self.storage = storage
        self.artworkStore = artworkStore
    }
    
    func initialize() async {
        audioFiles = await storage.loadAudioFiles()
        playlists = await storage.loadPlaylists()
        masterPlaylistID = await storage.loadMasterPlaylistID()
        
        if masterPlaylistID == nil || !playlists.contains(where: { $0.id == masterPlaylistID }) {
            await createMasterPlaylist()
        }
    }
    
    private func createMasterPlaylist() async {
        await storage.clearAll()
        playlists = []
        
        let masterPlaylist = Playlist(name: "__MASTER_SONGS__")
        masterPlaylistID = masterPlaylist.id
        playlists.append(masterPlaylist)
        
        for audioFile in audioFiles {
            if let index = playlists.firstIndex(where: { $0.id == masterPlaylistID }) {
                playlists[index].audioFileIDs.append(audioFile.id)
            }
        }
        
        try? await storage.savePlaylists(playlists)
        if let id = masterPlaylistID {
            try? await storage.saveMasterPlaylistID(id)
        }
    }
    
    var sortedAudioFiles: [AudioFile] {
        guard let masterID = masterPlaylistID,
              let masterPlaylist = playlists.first(where: { $0.id == masterID }) else {
            return audioFiles.sorted { $0.dateAdded > $1.dateAdded }
        }
        
        return masterPlaylist.audioFileIDs
            .compactMap { id in audioFiles.first { $0.id == id } }
            .sorted { $0.dateAdded > $1.dateAdded }
    }
    
    var sortedPlaylists: [Playlist] {
        playlists
            .filter { $0.id != masterPlaylistID }
            .sorted { $0.dateAdded > $1.dateAdded }
    }
    
    func addAudioFile(_ file: AudioFile) async {
        audioFiles.append(file)
        try? await storage.saveAudioFiles(audioFiles)
        
        if let masterID = masterPlaylistID,
           let index = playlists.firstIndex(where: { $0.id == masterID }) {
            playlists[index].audioFileIDs.append(file.id)
            try? await storage.savePlaylists(playlists)
        }
    }
    
    func deleteAudioFile(_ file: AudioFile) async {
        let url = file.fileURL
        try? FileManager.default.removeItem(at: url)
        
        audioFiles.removeAll { $0.id == file.id }
        try? await storage.saveAudioFiles(audioFiles)
        
        for i in 0..<playlists.count {
            playlists[i].audioFileIDs.removeAll { $0 == file.id }
        }
        try? await storage.savePlaylists(playlists)
        
        await artworkStore.deleteIfUnused(file.artworkImageName, usedBy: audioFiles, playlists: playlists)
    }
    
    func renameAudioFile(_ file: AudioFile, to newTitle: String) async {
        guard let index = audioFiles.firstIndex(where: { $0.id == file.id }) else { return }
        
        let updatedFile = AudioFile(
            id: file.id,
            fileName: file.fileName,
            dateAdded: file.dateAdded,
            audioDuration: file.audioDuration,
            artworkImageName: file.artworkImageName,
            title: newTitle
        )
        
        audioFiles[index] = updatedFile
        try? await storage.saveAudioFiles(audioFiles)
    }
    
    func setArtwork(_ image: UIImage, for file: AudioFile) async {
        guard let index = audioFiles.firstIndex(where: { $0.id == file.id }) else { return }
        
        let oldArtwork = audioFiles[index].artworkImageName
        guard let newFilename = await artworkStore.save(image: image) else { return }
        
        let updatedFile = AudioFile(
            id: file.id,
            fileName: file.fileName,
            dateAdded: file.dateAdded,
            audioDuration: file.audioDuration,
            artworkImageName: newFilename,
            title: file.title
        )
        
        audioFiles[index] = updatedFile
        try? await storage.saveAudioFiles(audioFiles)
        await artworkStore.deleteIfUnused(oldArtwork, usedBy: audioFiles, playlists: playlists)
    }
    
    func removeArtwork(from file: AudioFile) async {
        guard let index = audioFiles.firstIndex(where: { $0.id == file.id }) else { return }
        
        let oldArtwork = audioFiles[index].artworkImageName
        
        let updatedFile = AudioFile(
            id: file.id,
            fileName: file.fileName,
            dateAdded: file.dateAdded,
            audioDuration: file.audioDuration,
            artworkImageName: nil,
            title: file.title
        )
        
        audioFiles[index] = updatedFile
        try? await storage.saveAudioFiles(audioFiles)
        await artworkStore.deleteIfUnused(oldArtwork, usedBy: audioFiles, playlists: playlists)
    }
    
    func createPlaylist(name: String) async {
        let newPlaylist = Playlist(name: name)
        playlists.append(newPlaylist)
        try? await storage.savePlaylists(playlists)
    }
    
    func deletePlaylist(_ playlist: Playlist) async {
        playlists.removeAll { $0.id == playlist.id }
        try? await storage.savePlaylists(playlists)
        await artworkStore.deleteIfUnused(playlist.artworkImageName, usedBy: audioFiles, playlists: playlists)
    }
    
    func renamePlaylist(_ playlist: Playlist, to newName: String) async {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        playlists[index].name = newName
        try? await storage.savePlaylists(playlists)
    }
    
    func setArtwork(_ image: UIImage, for playlist: Playlist) async {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        
        let oldArtwork = playlists[index].artworkImageName
        guard let newFilename = await artworkStore.save(image: image) else { return }
        
        playlists[index].artworkImageName = newFilename
        try? await storage.savePlaylists(playlists)
        await artworkStore.deleteIfUnused(oldArtwork, usedBy: audioFiles, playlists: playlists)
    }
    
    func removeArtwork(from playlist: Playlist) async {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        
        let oldArtwork = playlists[index].artworkImageName
        playlists[index].artworkImageName = nil
        try? await storage.savePlaylists(playlists)
        await artworkStore.deleteIfUnused(oldArtwork, usedBy: audioFiles, playlists: playlists)
    }
    
    func addToPlaylist(file: AudioFile, playlist: Playlist) async {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        if !playlists[index].audioFileIDs.contains(file.id) {
            playlists[index].audioFileIDs.append(file.id)
            try? await storage.savePlaylists(playlists)
        }
    }
    
    func removeFromPlaylist(file: AudioFile, playlist: Playlist) async {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        playlists[index].audioFileIDs.removeAll { $0 == file.id }
        try? await storage.savePlaylists(playlists)
    }
    
    func getAudioFiles(for playlist: Playlist) -> [AudioFile] {
        playlist.audioFileIDs.compactMap { id in audioFiles.first { $0.id == id } }
    }
    
    func reorderMasterPlaylist(from source: IndexSet, to destination: Int) async {
        guard let masterID = masterPlaylistID,
              let index = playlists.firstIndex(where: { $0.id == masterID }) else { return }
        
        var ids = playlists[index].audioFileIDs
        ids.move(fromOffsets: source, toOffset: destination)
        playlists[index].audioFileIDs = ids
        try? await storage.savePlaylists(playlists)
    }
    
    func reorderPlaylist(_ playlist: Playlist, from source: IndexSet, to destination: Int) async {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        
        var updatedPlaylist = playlists[index]
        updatedPlaylist.audioFileIDs.move(fromOffsets: source, toOffset: destination)
        playlists[index] = updatedPlaylist
        try? await storage.savePlaylists(playlists)
    }
    
    func updatePlaylistOrder(_ playlist: Playlist, with ids: [UUID]) async {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        playlists[index].audioFileIDs = ids
        try? await storage.savePlaylists(playlists)
    }
    
    func reorderSelectedSongs(selectedIDs: [UUID], to destination: Int, in currentSongs: [AudioFile], playlist: Playlist?) async {
        let selectedIndices = currentSongs.enumerated()
            .filter { selectedIDs.contains($0.element.id) }
            .map { $0.offset }
            .sorted()
        
        let selectedSongs = selectedIndices.map { currentSongs[$0] }
        var songs = currentSongs
        
        for index in selectedIndices.reversed() {
            songs.remove(at: index)
        }
        
        let adjustedDestination = destination - selectedIndices.filter { $0 < destination }.count
        songs.insert(contentsOf: selectedSongs, at: adjustedDestination)
        
        if let playlist = playlist {
            guard let playlistIndex = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
            let reorderedIDs = songs.map { $0.id }
            playlists[playlistIndex].audioFileIDs = reorderedIDs
            try? await storage.savePlaylists(playlists)
        } else {
            guard let masterID = masterPlaylistID,
                  let index = playlists.firstIndex(where: { $0.id == masterID }) else { return }
            let reorderedIDs = songs.map { $0.id }
            playlists[index].audioFileIDs = reorderedIDs
            try? await storage.savePlaylists(playlists)
        }
    }
    
    nonisolated func loadArtworkImage(_ name: String) async -> UIImage? {
        await artworkStore.load(name: name)
    }
}
