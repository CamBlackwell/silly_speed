import Foundation

struct AudioFile: Identifiable, Codable {
    let id: UUID
    let fileName: String
    let fileURL: URL
    let dateAdded: Date
    let audioDuration: Float
    
    init(fileName: String, fileURL: URL, audioDuration: Float) {
        self.id = UUID()
        self.fileName = fileName
        self.fileURL = fileURL
        self.dateAdded = Date()
        self.audioDuration = audioDuration
    }
    
    init(id: UUID, fileName: String, fileURL: URL, dateAdded: Date, audioDuration: Float) {
        self.id = id
        self.fileName = fileName
        self.fileURL = fileURL
        self.dateAdded = dateAdded
        self.audioDuration = audioDuration
    }
}

struct Playlist: Identifiable, Codable {
    let id: UUID
    var name: String
    var audioFileIDs: [UUID]
    let dateAdded: Date
    
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.audioFileIDs = []
        self.dateAdded = Date()
    }
}

enum LibraryFilter: String, CaseIterable {
    case songs = "Songs"
    case playlists = "Playlists"
}

enum LibraryItem: Identifiable {
    case song(AudioFile)
    case playlist(Playlist)
    
    var id: UUID {
        switch self {
        case .song(let s): return s.id
        case .playlist(let p): return p.id
        }
    }
    
    var dateAdded: Date {
        switch self {
        case .song(let s): return s.dateAdded
        case .playlist(let p): return p.dateAdded
        }
    }
}
