import Foundation
import SwiftUI

@MainActor
final class LibraryCoordinator {
    unowned let audioManager: AudioManager
    let libraryService: AudioLibraryService
    let playbackCoordinator: PlaybackCoordinator

    init(audioManager: AudioManager, libraryService: AudioLibraryService, playbackCoordinator: PlaybackCoordinator) {
        self.audioManager = audioManager
        self.libraryService = libraryService
        self.playbackCoordinator = playbackCoordinator
    }

    func reorderSongs(from source: IndexSet, to destination: Int) {
        audioManager.displayedSongs.move(fromOffsets: source, toOffset: destination)

        Task {
            await libraryService.reorderMasterPlaylist(from: source, to: destination)
            if audioManager.playingFromSongsTab {
                playbackCoordinator.setQueue(audioManager.displayedSongs)
            }
        }
    }

    func reorderPlaylistSongs(in playlist: Playlist, from source: IndexSet, to destination: Int) {
        Task {
            await libraryService.reorderPlaylist(playlist, from: source, to: destination)
        }
    }

    func renameAudioFile(_ audioFile: AudioFile, to newTitle: String) {
        Task {
            await libraryService.renameAudioFile(audioFile, to: newTitle)
            audioManager.displayedSongs = libraryService.sortedAudioFiles
        }
    }

    func createPlaylist(name: String) {
        Task {
            await libraryService.createPlaylist(name: name)
        }
    }

    func deletePlaylist(_ playlist: Playlist) {
        Task {
            await libraryService.deletePlaylist(playlist)
        }
    }

    func renamePlaylist(_ playlist: Playlist, to newName: String) {
        Task {
            await libraryService.renamePlaylist(playlist, to: newName)
        }
    }

    func addAudioFile(_ audioFile: AudioFile, to playlist: Playlist) {
        Task {
            await libraryService.addToPlaylist(file: audioFile, playlist: playlist)
        }
    }

    func removeAudioFile(_ audioFile: AudioFile, from playlist: Playlist) {
        Task {
            await libraryService.removeFromPlaylist(file: audioFile, playlist: playlist)
        }
    }

    func updatePlaylistOrder(_ playlist: Playlist, with ids: [UUID]) {
        Task {
            await libraryService.updatePlaylistOrder(playlist, with: ids)

            if !audioManager.playingFromSongsTab {
                let reorderedSongs = ids.compactMap { id in libraryService.audioFiles.first { $0.id == id } }
                playbackCoordinator.setQueue(reorderedSongs)
            }
        }
    }

    func reorderSelectedSongs(selectedIDs: [UUID], to destination: Int, in currentSongs: [AudioFile], playlist: Playlist? = nil) {
        Task {
            await libraryService.reorderSelectedSongs(selectedIDs: selectedIDs, to: destination, in: currentSongs, playlist: playlist)

            if playlist == nil {
                audioManager.displayedSongs = libraryService.sortedAudioFiles
                if audioManager.playingFromSongsTab {
                    playbackCoordinator.setQueue(audioManager.displayedSongs)
                }
            } else if !audioManager.playingFromSongsTab {
                let songs = currentSongs.filter { selectedIDs.contains($0.id) }
                playbackCoordinator.setQueue(songs)
            }
        }
    }
}
