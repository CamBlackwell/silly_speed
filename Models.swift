import Foundation

struct AudioFile: Identifiable, Codable {
    let id: UUID
    let fileName: String
    let fileURL: URL
    let dateAdded: Date
    let audioDuration: Float
    let artworkImageName: String?
    
    init(fileName: String, fileURL: URL, audioDuration: Float, artworkImageName: String? = nil) {
        self.id = UUID()
        self.fileName = fileName
        self.fileURL = fileURL
        self.dateAdded = Date()
        self.audioDuration = audioDuration
        self.artworkImageName = artworkImageName
    }
    
    init(id: UUID, fileName: String, fileURL: URL, dateAdded: Date, audioDuration: Float, artworkImageName: String? = nil) {
        self.id = id
        self.fileName = fileName
        self.fileURL = fileURL
        self.dateAdded = dateAdded
        self.audioDuration = audioDuration
        self.artworkImageName = artworkImageName
    }
}

struct Playlist: Identifiable, Codable {
    let id: UUID
    var name: String
    var audioFileIDs: [UUID]
    let dateAdded: Date
    var artworkImageName: String?
    
    init(name: String, artworkImageName: String? = nil) {
        self.id = UUID()
        self.name = name
        self.audioFileIDs = []
        self.dateAdded = Date()
        self.artworkImageName = artworkImageName
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
