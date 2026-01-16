import Foundation
import AVFoundation
import Combine
import MediaPlayer
import SwiftUI

enum VisualisationMode: String, Codable, CaseIterable {
    case both
    case spectrumOnly
    case goniometerOnly
    case albumArt

    var icon: String {
        switch self {
        case .both: return "square.grid.2x2"
        case .spectrumOnly: return "waveform"
        case .goniometerOnly: return "circle.grid.cross"
        case .albumArt: return "photo"
        }
    }
}

@MainActor
class AudioManager: NSObject, ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var currentlyPlayingID: UUID?
    @Published var tempo: Float = 1.0
    @Published var pitch: Float = 0.0
    @Published var selectedAlgorithm: PitchAlgorithm = .apple
    @Published var isLooping: Bool = false
    @Published var visualisationMode: VisualisationMode = .both
    @Published var playingFromSongsTab: Bool = false
    @Published var displayedSongs: [AudioFile] = []
    @Published var isImporting: Bool = false
    @Published var importError: String?

    let playbackService: PlaybackService
    let libraryService: AudioLibraryService
    let importService: FileImportService
    let artworkStore: ArtworkStore
    let settingsStorage: SettingsStorage

    lazy var playbackCoordinator = PlaybackCoordinator(audioManager: self, playbackService: playbackService, libraryService: libraryService)
    lazy var libraryCoordinator = LibraryCoordinator(audioManager: self, libraryService: libraryService, playbackCoordinator: playbackCoordinator)
    lazy var importCoordinator = ImportCoordinator(audioManager: self, importService: importService, libraryService: libraryService, playbackCoordinator: playbackCoordinator)

    var audioAnalyzer: UnifiedAudioAnalyser {
        playbackService.audioAnalyzer
    }

    var audioFiles: [AudioFile] {
        libraryService.audioFiles
    }

    var playlists: [Playlist] {
        libraryService.playlists
    }

    var sortedAudioFiles: [AudioFile] {
        libraryService.sortedAudioFiles
    }

    var sortedPlaylists: [Playlist] {
        libraryService.sortedPlaylists
    }

    static let fileDirectory = FileDirectory.audioFiles

    override init() {
        let storage = LibraryStorage()
        let artworkStore = ArtworkStore(baseDirectory: AudioManager.fileDirectory)
        let settingsStorage = SettingsStorage()

        self.artworkStore = artworkStore
        self.settingsStorage = settingsStorage
        self.libraryService = AudioLibraryService(storage: storage, artworkStore: artworkStore)
        self.importService = FileImportService(fileDirectory: AudioManager.fileDirectory)
        self.playbackService = PlaybackService(settingsStorage: settingsStorage)

        super.init()

        Task { @MainActor in
            await self.initialize()
        }
    }

    private func initialize() async {
        await libraryService.initialize()
        await playbackService.initialize()
        playbackService.delegate = self

        let importedFiles = await importService.processPendingImports()
        for file in importedFiles {
            await libraryService.addAudioFile(file)
        }

        await importService.cleanupOrphanedFiles(trackedFiles: libraryService.audioFiles)

        displayedSongs = libraryService.sortedAudioFiles
        playbackCoordinator.setQueue(libraryService.sortedAudioFiles)

        visualisationMode = await settingsStorage.loadVisualisationMode()
        selectedAlgorithm = playbackService.selectedAlgorithm
        tempo = playbackService.tempo
        pitch = playbackService.pitch
        isLooping = playbackService.isLooping

        print(FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SharedConstants.appGroupIdentifier
        ) ?? "Failed to access AppGroup")
    }

    func saveVisualisationMode() {
        Task {
            await settingsStorage.saveVisualisationMode(visualisationMode)
        }
    }

    func reorderSongs(from source: IndexSet, to destination: Int) {
        libraryCoordinator.reorderSongs(from: source, to: destination)
    }

    func reorderPlaylistSongs(in playlist: Playlist, from source: IndexSet, to destination: Int) {
        libraryCoordinator.reorderPlaylistSongs(in: playlist, from: source, to: destination)
    }

    func changeAlgorithm(to algorithm: PitchAlgorithm) {
        guard algorithm.isImplemented else { return }
        let currentFile = libraryService.audioFiles.first { $0.id == currentlyPlayingID }
        Task {
            await playbackService.changeAlgorithm(to: algorithm, currentFile: currentFile)
            selectedAlgorithm = playbackService.selectedAlgorithm
        }
    }

    func importAudioFile(from url: URL) {
        importCoordinator.importAudioFile(from: url)
    }

    func deleteAudioFile(_ audioFile: AudioFile) {
        importCoordinator.deleteAudioFile(audioFile)
    }

    func processPendingImports(shouldAutoPlay: Bool = false) async {
        await importCoordinator.processPendingImports(shouldAutoPlay: shouldAutoPlay)
    }

    func renameAudioFile(_ audioFile: AudioFile, to newTitle: String) {
        libraryCoordinator.renameAudioFile(audioFile, to: newTitle)
    }

    func urlForSharing(_ audioFile: AudioFile) -> URL? {
        audioFile.fileURL
    }

    func createPlaylist(name: String) {
        libraryCoordinator.createPlaylist(name: name)
    }

    func deletePlaylist(_ playlist: Playlist) {
        libraryCoordinator.deletePlaylist(playlist)
    }

    func renamePlaylist(_ playlist: Playlist, to newName: String) {
        libraryCoordinator.renamePlaylist(playlist, to: newName)
    }

    func addAudioFile(_ audioFile: AudioFile, to playlist: Playlist) {
        libraryCoordinator.addAudioFile(audioFile, to: playlist)
    }

    func removeAudioFile(_ audioFile: AudioFile, from playlist: Playlist) {
        libraryCoordinator.removeAudioFile(audioFile, from: playlist)
    }

    func getAudioFiles(for playlist: Playlist) -> [AudioFile] {
        libraryService.getAudioFiles(for: playlist)
    }

    nonisolated func loadArtworkImage(_ name: String) async -> UIImage? {
        await artworkStore.load(name: name)
    }

    func setArtwork(_ image: UIImage, for audioFile: AudioFile) {
        Task {
            await libraryService.setArtwork(image, for: audioFile)
            displayedSongs = libraryService.sortedAudioFiles
        }
    }

    func setArtwork(_ image: UIImage, for playlist: Playlist) {
        Task {
            await libraryService.setArtwork(image, for: playlist)
        }
    }

    func removeArtwork(from audioFile: AudioFile) {
        Task {
            await libraryService.removeArtwork(from: audioFile)
        }
    }

    func removeArtwork(from playlist: Playlist) {
        Task {
            await libraryService.removeArtwork(from: playlist)
        }
    }

    func play(audioFile: AudioFile, context: [AudioFile]? = nil, fromSongsTab: Bool = false) {
        playbackCoordinator.play(audioFile: audioFile, context: context, fromSongsTab: fromSongsTab)
    }

    func stop() {
        playbackCoordinator.stop()
    }

    func togglePlayPause() {
        playbackCoordinator.togglePlayPause()
    }

    func playAsync(_ audioFile: AudioFile, context: [AudioFile]? = nil, fromSongsTab: Bool = false) async {
        playbackCoordinator.play(audioFile: audioFile, context: context, fromSongsTab: fromSongsTab)
    }

    func updatePlaylistOrder(_ playlist: Playlist, with ids: [UUID]) {
        libraryCoordinator.updatePlaylistOrder(playlist, with: ids)
    }

    func seek(to time: TimeInterval) {
        playbackCoordinator.seek(to: time)
    }

    func setVolume(_ volume: Float) {
        playbackCoordinator.setVolume(volume)
    }

    func setTempo(_ newTempo: Float) {
        playbackCoordinator.setTempo(newTempo)
    }

    func setPitch(_ newPitch: Float) {
        playbackCoordinator.setPitch(newPitch)
    }

    func skipPreviousSong() {
        playbackCoordinator.skipPreviousSong()
    }

    func skipNextSong() {
        playbackCoordinator.skipNextSong()
    }

    func reorderSelectedSongs(selectedIDs: [UUID], to destination: Int, in currentSongs: [AudioFile], playlist: Playlist? = nil) {
        libraryCoordinator.reorderSelectedSongs(selectedIDs: selectedIDs, to: destination, in: currentSongs, playlist: playlist)
    }
}

extension AudioManager: PlaybackServiceDelegate {
    func trackDidFinish() {
        skipNextSong()
    }

    func skipNextRequested() {
        skipNextSong()
    }

    func skipPreviousRequested() {
        skipPreviousSong()
    }

    func currentTimeChanged(to time: TimeInterval) {
        currentTime = time
    }

    func playbackStateChanged(isPlaying: Bool) {
        self.isPlaying = isPlaying
        updateNowPlayingInfoPlaybackRate()
    }

    func updateNowPlayingInfo(for file: AudioFile, currentTime: TimeInterval, duration: TimeInterval, isPlaying: Bool) {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = file.title
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

        if let artworkName = file.artworkImageName {
            Task {
                if let artworkImage = await loadArtworkImage(artworkName) {
                    await MainActor.run {
                        let artwork = MPMediaItemArtwork(boundsSize: artworkImage.size) { _ in artworkImage }
                        var updatedInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                        updatedInfo[MPMediaItemPropertyArtwork] = artwork
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = updatedInfo
                    }
                }
            }
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    func didEnterBackground() {
        if let currentFile = libraryService.audioFiles.first(where: { $0.id == currentlyPlayingID }) {
            updateNowPlayingInfo(for: currentFile, currentTime: currentTime, duration: duration, isPlaying: isPlaying)
        }
    }

    private func updateNowPlayingInfoPlaybackRate() {
        var updatedInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        updatedInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = updatedInfo
    }
}

extension AudioManager: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            isPlaying = false
            currentlyPlayingID = nil
            currentTime = 0
        }
    }
}
