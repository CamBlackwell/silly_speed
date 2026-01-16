import Foundation
actor LibraryStorage {
    private let audioFilesKey = "savedAudioFiles"
    private let playlistsKey = "savedPlaylists"
    private let masterPlaylistKey = "masterPlaylistID"
    func loadAudioFiles() -> [AudioFile] {
        guard let data = UserDefaults.standard.data(forKey: audioFilesKey),
              let files = try? JSONDecoder().decode([AudioFile].self, from: data) else {
            return []
        }
        
        return files.filter { file in
            FileManager.default.fileExists(atPath: file.fileURL.path())
        }
    }
    
    func saveAudioFiles(_ files: [AudioFile]) throws {
        let data = try JSONEncoder().encode(files)
        UserDefaults.standard.set(data, forKey: audioFilesKey)
    }
    
    func loadPlaylists() -> [Playlist] {
        guard let data = UserDefaults.standard.data(forKey: playlistsKey),
              let playlists = try? JSONDecoder().decode([Playlist].self, from: data) else {
            return []
        }
        return playlists
    }
    
    func savePlaylists(_ playlists: [Playlist]) throws {
        let data = try JSONEncoder().encode(playlists)
        UserDefaults.standard.set(data, forKey: playlistsKey)
    }
    
    func loadMasterPlaylistID() -> UUID? {
        guard let data = UserDefaults.standard.data(forKey: masterPlaylistKey) else {
            return nil
        }
        return try? JSONDecoder().decode(UUID.self, from: data)
    }
    
    func saveMasterPlaylistID(_ id: UUID) throws {
        let data = try JSONEncoder().encode(id)
        UserDefaults.standard.set(data, forKey: masterPlaylistKey)
    }
    
    func clearAll() {
        UserDefaults.standard.removeObject(forKey: audioFilesKey)
        UserDefaults.standard.removeObject(forKey: playlistsKey)
        UserDefaults.standard.removeObject(forKey: masterPlaylistKey)
    }
}
