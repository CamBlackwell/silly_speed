import Foundation
import UIKit
actor ArtworkStore {
    private let artworkDirectory: URL
    init(baseDirectory: URL) {
        self.artworkDirectory = baseDirectory.appendingPathComponent("Artwork", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: artworkDirectory,
            withIntermediateDirectories: true
        )
    }
    
    func save(image: UIImage) -> String? {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            return nil
        }
        
        let filename = "artwork_\(UUID().uuidString).jpg"
        let fileURL = artworkDirectory.appendingPathComponent(filename)
        
        do {
            try imageData.write(to: fileURL)
            return filename
        } catch {
            print("Failed to save artwork: \(error)")
            return nil
        }
    }
    
    func load(name: String) -> UIImage? {
        let url = artworkDirectory.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return UIImage(data: data)
    }
    
    func delete(name: String) {
        let fileURL = artworkDirectory.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    func deleteIfUnused(_ imageName: String?, usedBy files: [AudioFile], playlists: [Playlist]) {
        guard let imageName = imageName else { return }
        
        let audioFileUsage = files.filter { $0.artworkImageName == imageName }.count
        let playlistUsage = playlists.filter { $0.artworkImageName == imageName }.count
        
        if audioFileUsage == 0 && playlistUsage == 0 {
            delete(name: imageName)
        }
    }
}
