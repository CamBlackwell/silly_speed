import Foundation

@MainActor
final class PlaybackCoordinator {
    unowned let audioManager: AudioManager
    let playbackService: PlaybackService
    let libraryService: AudioLibraryService

    private var playbackQueue: [AudioFile] = []

    init(audioManager: AudioManager, playbackService: PlaybackService, libraryService: AudioLibraryService) {
        self.audioManager = audioManager
        self.playbackService = playbackService
        self.libraryService = libraryService
    }

    func setQueue(_ queue: [AudioFile]) {
        playbackQueue = queue
    }

    func removeFromQueue(_ file: AudioFile) {
        playbackQueue.removeAll { $0.id == file.id }
    }

    func play(audioFile: AudioFile, context: [AudioFile]? = nil, fromSongsTab: Bool) {
        if let context = context {
            playbackQueue = context
        } else if playbackQueue.isEmpty || !playbackQueue.contains(where: { $0.id == audioFile.id }) {
            playbackQueue = libraryService.sortedAudioFiles
        }

        audioManager.playingFromSongsTab = fromSongsTab
        playbackService.play(audioFile: audioFile)
    }

    func stop() {
        playbackService.stop()
    }

    func togglePlayPause() {
        playbackService.togglePlayPause()
    }

    func seek(to time: TimeInterval) {
        playbackService.seek(to: time)
    }

    func setVolume(_ volume: Float) {
        playbackService.setVolume(volume)
    }

    func setTempo(_ newTempo: Float) {
        let clamped = max(0.1, min(4.0, newTempo))
        audioManager.tempo = clamped
        playbackService.tempo = clamped
    }

    func setPitch(_ newPitch: Float) {
        let clamped = max(-2400, min(2400, newPitch))
        audioManager.pitch = clamped
        playbackService.pitch = clamped
    }

    func skipPreviousSong() {
        if audioManager.currentTime > 3.0 {
            restartCurrentSong()
            return
        }

        guard let currentID = audioManager.currentlyPlayingID,
              let currentIndex = playbackQueue.firstIndex(where: { $0.id == currentID }) else {
            return
        }

        let previousIndex = currentIndex - 1
        if previousIndex >= 0 {
            play(audioFile: playbackQueue[previousIndex], context: playbackQueue, fromSongsTab: audioManager.playingFromSongsTab)
        } else {
            restartCurrentSong()
        }
    }

    private func restartCurrentSong() {
        playbackService.seek(to: 0)
        if !audioManager.isPlaying {
            playbackService.togglePlayPause()
        }
        audioManager.currentTime = 0
    }

    func skipNextSong() {
        guard !playbackQueue.isEmpty else {
            stop()
            return
        }

        if let currentID = audioManager.currentlyPlayingID,
           let currentIndex = playbackQueue.firstIndex(where: { $0.id == currentID }) {
            let nextIndex = currentIndex + 1
            if nextIndex < playbackQueue.count {
                play(audioFile: playbackQueue[nextIndex], context: playbackQueue, fromSongsTab: audioManager.playingFromSongsTab)
            } else {
                if audioManager.isLooping {
                    if let firstFile = playbackQueue.first {
                        play(audioFile: firstFile, context: playbackQueue, fromSongsTab: audioManager.playingFromSongsTab)
                    }
                } else {
                    stop()
                }
            }
        } else {
            if let firstFile = playbackQueue.first {
                play(audioFile: firstFile, context: playbackQueue, fromSongsTab: audioManager.playingFromSongsTab)
            }
        }
    }
}
