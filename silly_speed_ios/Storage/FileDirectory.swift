import Foundation

enum FileDirectory {
    static let audioFiles: URL = {
        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SharedConstants.appGroupIdentifier
        ) {
            let dir = groupURL.appendingPathComponent("AudioFiles", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        }

        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }()
}
