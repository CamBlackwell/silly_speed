import Foundation
import AVFoundation

actor FileImportService {

    private let fileDirectory: URL

    init(fileDirectory: URL) {
        self.fileDirectory = fileDirectory
    }

    func importFromPicker(url: URL) async throws -> AudioFile {
        guard url.startAccessingSecurityScopedResource() else {
            throw ImportError.noPermission
        }
        defer { url.stopAccessingSecurityScopedResource() }

        let uniqueFileName = generateUniqueFileName(for: url.lastPathComponent)
        let destinationURL = fileDirectory.appendingPathComponent(uniqueFileName)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let coordinator = NSFileCoordinator()
            var error: NSError?

            coordinator.coordinate(
                readingItemAt: url,
                options: [.withoutChanges],
                error: &error
            ) { coordinatedURL in
                do {
                    try FileManager.default.copyItem(at: coordinatedURL, to: destinationURL)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            if let error = error {
                continuation.resume(throwing: error)
            }
        }

        let duration = try await loadDuration(from: destinationURL)

        return AudioFile(
            fileName: uniqueFileName,
            audioDuration: duration
        )
    }

    func processPendingImports() async -> [AudioFile] {

        guard
            let groupURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: SharedConstants.appGroupIdentifier
            ),
            let groupDefaults = UserDefaults(suiteName: SharedConstants.appGroupIdentifier),
            let pendingFiles = groupDefaults.stringArray(forKey: SharedConstants.pendingFilesKey),
            !pendingFiles.isEmpty
        else {
            return []
        }

        let pendingDirectory = groupURL.appendingPathComponent("PendingImports", isDirectory: true)
        var importedFiles: [AudioFile] = []

        for fileName in pendingFiles {
            let sourceURL = pendingDirectory.appendingPathComponent(fileName)
            guard FileManager.default.fileExists(atPath: sourceURL.path) else { continue }

            let uniqueFileName = generateUniqueFileName(for: fileName)
            let destinationURL = fileDirectory.appendingPathComponent(uniqueFileName)

            do {
                try FileManager.default.moveItem(at: sourceURL, to: destinationURL)

                let duration = try await loadDuration(from: destinationURL)

                let audioFile = AudioFile(
                    fileName: uniqueFileName,
                    audioDuration: duration
                )

                importedFiles.append(audioFile)

            } catch {
                print("Error importing \(fileName): \(error)")
            }
        }

        groupDefaults.removeObject(forKey: SharedConstants.pendingFilesKey)
        groupDefaults.synchronize()

        try? FileManager.default.removeItem(at: pendingDirectory)

        return importedFiles
    }

    func cleanupOrphanedFiles(trackedFiles: [AudioFile]) {
        let trackedNames = Set(trackedFiles.map { $0.fileName })

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: fileDirectory,
            includingPropertiesForKeys: nil
        ) else { return }

        for fileURL in files {
            let fileName = fileURL.lastPathComponent
            if fileName != "Artwork" && !trackedNames.contains(fileName) {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }

    private func loadDuration(from url: URL) async throws -> Float {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let seconds = Float(CMTimeGetSeconds(duration))

        guard seconds > 0 && !seconds.isNaN && !seconds.isInfinite else {
            try? FileManager.default.removeItem(at: url)
            throw ImportError.invalidFile
        }

        return seconds
    }

    private func generateUniqueFileName(for originalName: String) -> String {
        let baseURL = fileDirectory.appendingPathComponent(originalName)

        if !FileManager.default.fileExists(atPath: baseURL.path()) {
            return originalName
        }

        let nameWithoutExtension = (originalName as NSString).deletingPathExtension
        let fileExtension = (originalName as NSString).pathExtension

        var counter = 2

        while true {
            let newName = fileExtension.isEmpty
                ? "\(nameWithoutExtension) \(counter)"
                : "\(nameWithoutExtension) \(counter).\(fileExtension)"

            let newURL = fileDirectory.appendingPathComponent(newName)

            if !FileManager.default.fileExists(atPath: newURL.path()) {
                return newName
            }

            counter += 1
        }
    }

    enum ImportError: LocalizedError {
        case noPermission
        case invalidFile

        var errorDescription: String? {
            switch self {
            case .noPermission:
                return "No permission to access this file"
            case .invalidFile:
                return "Invalid or corrupted audio file"
            }
        }
    }
}
