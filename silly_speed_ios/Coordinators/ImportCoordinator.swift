import Foundation

@MainActor
final class ImportCoordinator {
    unowned let audioManager: AudioManager
    let importService: FileImportService
    let libraryService: AudioLibraryService
    let playbackCoordinator: PlaybackCoordinator

    init(audioManager: AudioManager, importService: FileImportService, libraryService: AudioLibraryService, playbackCoordinator: PlaybackCoordinator) {
        self.audioManager = audioManager
        self.importService = importService
        self.libraryService = libraryService
        self.playbackCoordinator = playbackCoordinator
    }

    func importAudioFile(from url: URL) {
        audioManager.isImporting = true
        audioManager.importError = nil

        Task {
            do {
                let audioFile = try await importService.importFromPicker(url: url)
                await libraryService.addAudioFile(audioFile)

                audioManager.displayedSongs = libraryService.sortedAudioFiles

                let currentCount = playbackCoordinatorQueueCount()
                if currentCount == libraryService.audioFiles.count - 1 {
                    playbackCoordinator.setQueue(libraryService.sortedAudioFiles)
                }

                audioManager.isImporting = false
            } catch {
                audioManager.isImporting = false

                let nsError = error as NSError
                if nsError.domain == NSCocoaErrorDomain {
                    switch nsError.code {
                    case NSFileReadNoPermissionError:
                        audioManager.importError = "No permission to read this file"
                    case NSFileReadNoSuchFileError:
                        audioManager.importError = "File not found or still downloading"
                    case NSFileReadUnknownError:
                        audioManager.importError = "Cannot read this file type"
                    default:
                        audioManager.importError = "Failed to import: \(error.localizedDescription)"
                    }
                } else {
                    audioManager.importError = error.localizedDescription
                }
            }
        }
    }

    func deleteAudioFile(_ audioFile: AudioFile) {
        if audioManager.currentlyPlayingID == audioFile.id {
            playbackCoordinator.stop()
        }

        Task {
            await libraryService.deleteAudioFile(audioFile)
            audioManager.displayedSongs = libraryService.sortedAudioFiles
            playbackCoordinator.removeFromQueue(audioFile)
        }
    }

    func processPendingImports(shouldAutoPlay: Bool = false) async {
        let importedFiles = await importService.processPendingImports()

        for file in importedFiles {
            await libraryService.addAudioFile(file)
        }

        if !importedFiles.isEmpty {
            audioManager.displayedSongs = libraryService.sortedAudioFiles
            playbackCoordinator.setQueue(libraryService.sortedAudioFiles)

            if shouldAutoPlay, let firstFile = importedFiles.first {
                playbackCoordinator.play(audioFile: firstFile, context: libraryService.sortedAudioFiles, fromSongsTab: true)
            }
        }
    }

    private func playbackCoordinatorQueueCount() -> Int {
        0
    }
}
