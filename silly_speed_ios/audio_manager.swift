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


class AudioManager: NSObject, ObservableObject {
    @Published var audioFiles: [AudioFile] = []
    @Published var playlists: [Playlist] = []
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var currentlyPlayingID: UUID?
    @Published var tempo: Float = 1.0
    @Published var pitch: Float = 0.0
    @Published var selectedAlgorithm: PitchAlgorithm = .apple
    @Published var audioAnalyzer = UnifiedAudioAnalyser()
    @Published var isLooping: Bool = false
    @Published var visualisationMode: VisualisationMode = .both
    @Published var playingFromSongsTab: Bool = false
    @Published var displayedSongs: [AudioFile] = []
    @Published var isImporting: Bool = false
    @Published var importError: String?
    
    private var currentEngine: AudioEngineProtocol?
    private var timer: Timer?
    private let artworkDirectory: URL
    private let audioFilesKey = "savedAudioFiles"
    private let playlistsKey = "savedPlaylists"
    private let algorithmKey = "selectedAlgorithm"
    private let visualisationModeKey = "visualisationMode"
    private var isSeeking = false
    private let masterPlaylistKey = "masterPlaylistID"
    private(set) var masterPlaylistID: UUID?
    
    private var playbackQueue: [AudioFile] = []
    private var observerTokens: [Any] = []
    
    static let fileDirectory: URL = {
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedConstants.appGroupIdentifier){
            let dir = groupURL.appendingPathComponent("AudioFiles", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        } else {
            return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask) [0]
        }
    } ()
    
    var sortedAudioFiles: [AudioFile] {
        guard let masterID = masterPlaylistID,
              let masterPlaylist = playlists.first(where: { $0.id == masterID }) else {
            return audioFiles.sorted { $0.dateAdded > $1.dateAdded }
        }
        
        return masterPlaylist.audioFileIDs
            .compactMap { id in audioFiles.first { $0.id == id } }
            .sorted { $0.dateAdded > $1.dateAdded }
    }
    
    var sortedPlaylists: [Playlist] {
        playlists
            .filter { $0.id != masterPlaylistID }
            .sorted { $0.dateAdded > $1.dateAdded }
    }
    
    override init() {
        self.artworkDirectory = AudioManager.fileDirectory.appendingPathComponent("Artwork", isDirectory: true)
        super.init()
        try? FileManager.default.createDirectory(at: artworkDirectory, withIntermediateDirectories: true)
        loadAudioFiles()
        cleanupOrphanedFiles()
        loadOrCreateMasterPlaylist()
        loadPlaylists()
        self.displayedSongs = self.sortedAudioFiles
        loadSelectedAlgorithm()
        loadVisualisationMode()
        setupAudioSession()
        initialiseEngine()
        setupInterruptionObserver()
        setupRouteChangeObserver()
        setupConfigurationChangeObserver()
        
        self.playbackQueue = self.sortedAudioFiles
        
        let bgToken = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            
            if !self.isPlaying {
                try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            }
            self.updateNowPlayingInfo()
        }
        observerTokens.append(bgToken)
        
        let fgToken = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            
            if self.currentlyPlayingID != nil {
                try? AVAudioSession.sharedInstance().setActive(true)
            }
        }
        observerTokens.append(fgToken)
        
        Task { [weak self] in
            await self?.processPendingImports()
        }
    }
    
    deinit {
        timer?.invalidate()
        timer = nil
        for token in observerTokens {
            NotificationCenter.default.removeObserver(token)
        }
        observerTokens.removeAll()
        currentEngine?.stop()
        try? AVAudioSession.sharedInstance().setActive(false)
    }
    
    private func loadVisualisationMode() {
        if let saved = UserDefaults.standard.string(forKey: visualisationModeKey),
           let mode = VisualisationMode(rawValue: saved) {
            visualisationMode = mode
        }
    }
    
    func saveVisualisationMode() {
        UserDefaults.standard.set(visualisationMode.rawValue, forKey: visualisationModeKey)
    }
    
    private func setupConfigurationChangeObserver() {
        let token = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, self.isPlaying else { return }
            
            if let engine = self.currentEngine?.getAudioEngine() {
                do {
                    engine.prepare()
                    try engine.start()
                } catch {
                    print("Failed to restart engine after config change: \(error)")
                }
            }
        }
        observerTokens.append(token)
    }
    
    private func loadSelectedAlgorithm(){
        if let saved = UserDefaults.standard.string(forKey: algorithmKey),
           let algorithm = PitchAlgorithm(rawValue: saved),
           algorithm.isImplemented {
            selectedAlgorithm = algorithm
        }
    }
    
    private func clearZombiePlaylists() {
        playlists = []
        savePlaylists()
        UserDefaults.standard.removeObject(forKey: masterPlaylistKey)
    }
    
    private func loadOrCreateMasterPlaylist() {
        if let data = UserDefaults.standard.data(forKey: masterPlaylistKey),
           let id = try? JSONDecoder().decode(UUID.self, from: data),
           playlists.contains(where: { $0.id == id }) {
            masterPlaylistID = id
        } else {
            clearZombiePlaylists()
            let masterPlaylist = Playlist(name: "__MASTER_SONGS__")
            masterPlaylistID = masterPlaylist.id
            playlists.append(masterPlaylist)
            
            for audioFile in audioFiles {
                if let index = playlists.firstIndex(where: { $0.id == masterPlaylistID }) {
                    playlists[index].audioFileIDs.append(audioFile.id)
                }
            }
            
            savePlaylists()
            if let data = try? JSONEncoder().encode(masterPlaylistID) {
                UserDefaults.standard.set(data, forKey: masterPlaylistKey)
            }
        }
    }
    
    func reorderSongs(from source: IndexSet, to destination: Int) {
        displayedSongs.move(fromOffsets: source, toOffset: destination)
        
        guard let masterID = masterPlaylistID,
              let index = playlists.firstIndex(where: { $0.id == masterID }) else { return }
        
        let reorderedIDs = displayedSongs.map { $0.id }
        playlists[index].audioFileIDs = reorderedIDs
        savePlaylists()
        
        if playingFromSongsTab {
            playbackQueue = displayedSongs
        }
    }
    
    func reorderPlaylistSongs(in playlist: Playlist, from source: IndexSet, to destination: Int) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        
        var updatedPlaylist = playlists[index]
        updatedPlaylist.audioFileIDs.move(fromOffsets: source, toOffset: destination)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.playlists[index] = updatedPlaylist
            self.savePlaylists()
        }
    }
    
    private func saveSelectedAlgorithm(){
        UserDefaults.standard.set(selectedAlgorithm.rawValue, forKey: algorithmKey)
    }
    
    private func setupAudioSession(){
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
            UIApplication.shared.beginReceivingRemoteControlEvents()
            setupRemoteTransportControls()
        } catch {
            print("failed to set up audio \(error.localizedDescription)")
        }
    }
    
    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            if self.audioFiles.first(where: { $0.id == self.currentlyPlayingID }) != nil {
                self.togglePlayPause()
                return .success
            }
            return .commandFailed
        }
        
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            self.skipPreviousSong()
            return .success
        }
        
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            self.skipNextSong()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] event in
            self?.togglePlayPause()
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self,
                  let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self.seek(to: positionEvent.positionTime)
            return .success
        }
    }
    
    private func setupInterruptionObserver() {
        let token = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
            
            if type == .began {
                self.isPlaying = false
                self.stopTimer()
                self.currentEngine?.pause()
            } else if type == .ended {
                if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) {
                        do {
                            try AVAudioSession.sharedInstance().setActive(true)
                            self.currentEngine?.play()
                            self.isPlaying = true
                            self.startTimer()
                        } catch {
                            print("Resume error: \(error)")
                        }
                    }
                }
            }
        }
        observerTokens.append(token)
    }
    
    private func setupRouteChangeObserver() {
        let token = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
            
            if reason == .oldDeviceUnavailable {
                DispatchQueue.main.async {
                    self?.togglePlayPause()
                }
            }
        }
        observerTokens.append(token)
    }
    
    private func updateNowPlayingInfo() {
        guard let currentFile = audioFiles.first(where: { $0.id == currentlyPlayingID }) else {
            return
        }
        
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = currentFile.title
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        if let artworkName = currentFile.artworkImageName,
           let artworkImage = loadArtworkImage(artworkName) {
            let artwork = MPMediaItemArtwork(boundsSize: artworkImage.size) { size in
                return artworkImage
            }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private func initialiseEngine(){
        switch selectedAlgorithm {
        case .apple:
            currentEngine = AppleAudioEngine()
        case .rubberBand:
            currentEngine = nil
        case .soundTouch:
            currentEngine = nil
        case .signalSmith:
            currentEngine = nil
        }
        
        if let avEngine = currentEngine?.getAudioEngine() {
            audioAnalyzer.attach(to: avEngine)
        }
    }
    
    func changeAlgorithm(to algorithm: PitchAlgorithm){
        guard algorithm.isImplemented else {
            print ("Algorithm \(algorithm.rawValue) not implemented yet")
            return
        }
        
        let wasPlaying = isPlaying
        let currentAudioFile = audioFiles.first { $0.id == currentlyPlayingID }
        let savedTime = currentTime
        
        if let oldEngine = currentEngine?.getAudioEngine() {
            audioAnalyzer.detach(from: oldEngine)
        }
        
        stop()
        
        selectedAlgorithm = algorithm
        saveSelectedAlgorithm()
        initialiseEngine()
        
        if let audioFile = currentAudioFile {
            currentEngine?.load(audioFile: audioFile)
            currentEngine?.setTempo(tempo)
            currentEngine?.setPitch(pitch)
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.currentEngine?.seek(to: savedTime)
                if wasPlaying {
                    self.play(audioFile: audioFile)
                }
            }
        }
    }
    
    func importAudioFile(from url: URL) {
        isImporting = true
        importError = nil
        
        Task {
            do {
                print("Importing from: \(url)")
                
                guard url.startAccessingSecurityScopedResource() else {
                    throw NSError(domain: "AudioImport", code: 1, userInfo: [NSLocalizedDescriptionKey: "No permission to access this file"])
                }
                
                defer {
                    url.stopAccessingSecurityScopedResource()
                    print("Released security scope")
                }
                
                let originalFileName = url.lastPathComponent
                let uniqueFileName = generateUniqueFileName(for: originalFileName)
                let destinationURL = AudioManager.fileDirectory.appendingPathComponent(uniqueFileName)
                
                print("Copying to: \(destinationURL)")
                
                let fileCoordinator = NSFileCoordinator()
                
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    var coordinationError: NSError?
                    
                    fileCoordinator.coordinate(readingItemAt: url, options: [.withoutChanges], error: &coordinationError) { coordinatedURL in
                        do {
                            try FileManager.default.copyItem(at: coordinatedURL, to: destinationURL)
                            continuation.resume(returning: ())
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                    
                    if let error = coordinationError {
                        continuation.resume(throwing: error)
                    }
                }
                
                print("File copied successfully")
                
                let asset = AVURLAsset(url: destinationURL, options: nil)
                let duration = try await asset.load(.duration)
                let durationInSeconds = Float(CMTimeGetSeconds(duration))
                
                guard durationInSeconds > 0 && !durationInSeconds.isNaN && !durationInSeconds.isInfinite else {
                    try? FileManager.default.removeItem(at: destinationURL)
                    throw NSError(domain: "AudioImport", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid or corrupted audio file"])
                }
                
                let audioFile = AudioFile(fileName: uniqueFileName, audioDuration: durationInSeconds)
                
                await MainActor.run {
                    audioFiles.append(audioFile)
                    saveAudioFiles()
                    
                    if let masterID = self.masterPlaylistID,
                       let index = self.playlists.firstIndex(where: { $0.id == masterID }) {
                        self.playlists[index].audioFileIDs.append(audioFile.id)
                        self.displayedSongs = self.sortedAudioFiles
                        self.savePlaylists()
                    }
                    
                    if playbackQueue.count == audioFiles.count - 1 {
                        playbackQueue = sortedAudioFiles
                    }
                    
                    print("Import complete: \(uniqueFileName)")
                    isImporting = false
                }
                
            } catch {
                await MainActor.run {
                    isImporting = false
                    
                    print("Import error: \(error)")
                    
                    let nsError = error as NSError
                    if nsError.domain == NSCocoaErrorDomain {
                        switch nsError.code {
                        case NSFileReadNoPermissionError:
                            importError = "No permission to read this file"
                        case NSFileReadNoSuchFileError:
                            importError = "File not found or still downloading"
                        case NSFileReadUnknownError:
                            importError = "Cannot read this file type"
                        default:
                            importError = "Failed to import: \(error.localizedDescription)"
                        }
                    } else {
                        importError = error.localizedDescription
                    }
                }
            }
        }
    }
    private func generateUniqueFileName(for originalName: String) -> String {
        let baseURL = AudioManager.fileDirectory.appendingPathComponent(originalName)
        
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
            
            let newURL = AudioManager.fileDirectory.appendingPathComponent(newName)
            
            if !FileManager.default.fileExists(atPath: newURL.path()) {
                return newName
            }
            
            counter += 1
        }
    }
    
    private func cleanupOrphanedFiles() {
        let trackedFileNames = Set(audioFiles.map { $0.fileName })
        
        guard let files = try? FileManager.default.contentsOfDirectory(at: AudioManager.fileDirectory, includingPropertiesForKeys: nil) else {
            return
        }
        
        for fileURL in files {
            let fileName = fileURL.lastPathComponent
            if fileName != "Artwork" && !trackedFileNames.contains(fileName) {
                print("Deleting orphaned file: \(fileName)")
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }
    
    func deleteAudioFile(_ audioFile: AudioFile){
        if currentlyPlayingID == audioFile.id {
            stop()
        }
        
        let url = audioFile.fileURL
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            print("failed to delete file \(error.localizedDescription)")
        }
        
        audioFiles.removeAll{$0.id == audioFile.id}
        deleteArtworkIfUnused(audioFile.artworkImageName)
        saveAudioFiles()
        displayedSongs = sortedAudioFiles
        
        for i in 0..<playlists.count {
            playlists[i].audioFileIDs.removeAll { $0 == audioFile.id }
        }
        savePlaylists()
        
        if playbackQueue.contains(where: { $0.id == audioFile.id }) {
            playbackQueue.removeAll { $0.id == audioFile.id }
        }
    }
    
    private func saveAudioFiles(){
        do {
            let data = try JSONEncoder().encode(audioFiles)
            UserDefaults.standard.set(data, forKey: audioFilesKey)
        } catch {
            print("failed to save audio files \(error.localizedDescription)")
        }
    }
    
    private func loadAudioFiles(){
        guard let data = UserDefaults.standard.data(forKey: audioFilesKey) else { return }
        
        do {
            let loadedFiles = try JSONDecoder().decode([AudioFile].self, from: data)
            audioFiles = loadedFiles.filter { file in
                let url = file.fileURL
                let exists = FileManager.default.fileExists(atPath: url.path())
                if !exists {
                    print("File missing: \(file.fileName) at \(url.path())")
                }
                return exists
            }
            print("Loaded \(audioFiles.count) audio files")
        } catch {
            print("failed to load Audio Files \(error.localizedDescription)")
        }
    }
    
    func processPendingImports(shouldAutoPlay: Bool = false) async {
        guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedConstants.appGroupIdentifier),
              let groupDefaults = UserDefaults(suiteName: SharedConstants.appGroupIdentifier),
              let pendingFiles = groupDefaults.stringArray(forKey: SharedConstants.pendingFilesKey),
              !pendingFiles.isEmpty else {
            return
        }
        
        let pendingDirectory = groupURL.appendingPathComponent("PendingImports", isDirectory: true)
        var importedFiles: [AudioFile] = []
        
        for fileName in pendingFiles {
            let sourceURL = pendingDirectory.appendingPathComponent(fileName)
            
            guard FileManager.default.fileExists(atPath: sourceURL.path) else { continue }
            
            let uniqueFileName = generateUniqueFileName(for: fileName)
            let destinationURL = AudioManager.fileDirectory.appendingPathComponent(uniqueFileName)
            
            do {
                try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
                
                let asset = AVURLAsset(url: destinationURL)
                let duration = try await asset.load(.duration)

                let durationInSeconds = Float(CMTimeGetSeconds(duration))

                guard durationInSeconds > 0 && !durationInSeconds.isNaN && !durationInSeconds.isInfinite else {
                    try? FileManager.default.removeItem(at: destinationURL)
                    continue
                }
                let audioFile = AudioFile(fileName: uniqueFileName, audioDuration: durationInSeconds)
                audioFiles.append(audioFile)
                importedFiles.append(audioFile)
                
                if let masterID = masterPlaylistID,
                   let index = playlists.firstIndex(where: { $0.id == masterID }) {
                    playlists[index].audioFileIDs.append(audioFile.id)
                }
                
                print("Imported from share: \(uniqueFileName)")
            } catch {
                print("Error importing \(fileName): \(error)")
            }
        }
        
        if !importedFiles.isEmpty {
            saveAudioFiles()
            savePlaylists()
            displayedSongs = sortedAudioFiles
            playbackQueue = sortedAudioFiles
            
            if shouldAutoPlay, let firstFile = importedFiles.first {
                play(audioFile: firstFile, context: sortedAudioFiles, fromSongsTab: true)
            }
        }
        
        groupDefaults.removeObject(forKey: SharedConstants.pendingFilesKey)
        groupDefaults.synchronize()
        
        try? FileManager.default.removeItem(at: pendingDirectory)
    }
    
    func renameAudioFile(_ audioFile: AudioFile, to newTitle: String) {
        guard let index = audioFiles.firstIndex(where: { $0.id == audioFile.id }) else { return }
        
        let updatedFile = AudioFile(
            id: audioFile.id,
            fileName: audioFile.fileName,
            dateAdded: audioFile.dateAdded,
            audioDuration: audioFile.audioDuration,
            artworkImageName: audioFile.artworkImageName,
            title: newTitle
        )
        
        audioFiles[index] = updatedFile
        saveAudioFiles()
        displayedSongs = sortedAudioFiles
    }
    
    func urlForSharing(_ audioFile: AudioFile) -> URL? {
        audioFile.fileURL
    }
    
    func createPlaylist(name: String) {
        let newPlaylist = Playlist(name: name)
        playlists.append(newPlaylist)
        savePlaylists()
    }
    
    func deletePlaylist(_ playlist: Playlist) {
        playlists.removeAll { $0.id == playlist.id }
        deleteArtworkIfUnused(playlist.artworkImageName)
        savePlaylists()
    }
    
    func renamePlaylist(_ playlist: Playlist, to newName: String) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        playlists[index].name = newName
        savePlaylists()
    }
    
    func addAudioFile(_ audioFile: AudioFile, to playlist: Playlist) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        if !playlists[index].audioFileIDs.contains(audioFile.id) {
            playlists[index].audioFileIDs.append(audioFile.id)
            savePlaylists()
        }
    }
    
    func removeAudioFile(_ audioFile: AudioFile, from playlist: Playlist) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        playlists[index].audioFileIDs.removeAll { $0 == audioFile.id }
        savePlaylists()
    }
    
    func getAudioFiles(for playlist: Playlist) -> [AudioFile] {
        return playlist.audioFileIDs
            .compactMap { id in audioFiles.first { $0.id == id } }
    }
    
    private func savePlaylists() {
        do {
            let data = try JSONEncoder().encode(playlists)
            UserDefaults.standard.set(data, forKey: playlistsKey)
        } catch {
            print("failed to save playlists \(error.localizedDescription)")
        }
    }
    
    private func loadPlaylists() {
        guard let data = UserDefaults.standard.data(forKey: playlistsKey) else { return }
        do {
            playlists = try JSONDecoder().decode([Playlist].self, from: data)
        } catch {
            print("failed to load playlists \(error.localizedDescription)")
        }
    }
    
    func saveArtwork(from image: UIImage) -> String? {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return nil }
        let filename = "artwork_\(UUID().uuidString).jpg"
        let fileURL = artworkDirectory.appendingPathComponent(filename)
        
        do {
            if !FileManager.default.fileExists(atPath: artworkDirectory.path) {
                try FileManager.default.createDirectory(at: artworkDirectory, withIntermediateDirectories: true)
            }
            try imageData.write(to: fileURL)
            return filename
        } catch {
            print("Failed to save artwork: \(error)")
            return nil
        }
    }
    
    func loadArtworkImage(_ imageName: String) -> UIImage? {
        let imageURL = artworkDirectory.appendingPathComponent(imageName)
        if let data = try? Data(contentsOf: imageURL) {
            return UIImage(data: data)
        }
        return nil
    }
    
    
    func setArtwork(_ image: UIImage, for audioFile: AudioFile) {
        guard let index = audioFiles.firstIndex(where: { $0.id == audioFile.id }) else { return }
        
        let oldArtwork = audioFiles[index].artworkImageName
        guard let newFilename = saveArtwork(from: image) else { return }
        
        let updatedFile = AudioFile(
            id: audioFile.id,
            fileName: audioFile.fileName,
            dateAdded: audioFile.dateAdded,
            audioDuration: audioFile.audioDuration,
            artworkImageName: newFilename,
            title: audioFile.title
        )
        
        audioFiles[index] = updatedFile
        displayedSongs = sortedAudioFiles
        saveAudioFiles()
        deleteArtworkIfUnused(oldArtwork)
    }
    
    func setArtwork(_ image: UIImage, for playlist: Playlist) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        
        let oldArtwork = playlists[index].artworkImageName
        
        guard let newFilename = saveArtwork(from: image) else { return }
        
        playlists[index].artworkImageName = newFilename
        savePlaylists()
        
        deleteArtworkIfUnused(oldArtwork)
    }
    
    func removeArtwork(from audioFile: AudioFile) {
        guard let index = audioFiles.firstIndex(where: { $0.id == audioFile.id }) else { return }
        
        let oldArtwork = audioFiles[index].artworkImageName
        
        let updatedFile = AudioFile(
            id: audioFile.id,
            fileName: audioFile.fileName,
            dateAdded: audioFile.dateAdded,
            audioDuration: audioFile.audioDuration,
            artworkImageName: nil,
            title: audioFile.title
        )
        
        audioFiles[index] = updatedFile
        saveAudioFiles()
        deleteArtworkIfUnused(oldArtwork)
    }
    func removeArtwork(from playlist: Playlist) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        
        let oldArtwork = playlists[index].artworkImageName
        
        playlists[index].artworkImageName = nil
        savePlaylists()
        
        deleteArtworkIfUnused(oldArtwork)
    }
    
    private func deleteArtworkIfUnused(_ imageName: String?) {
        guard let imageName = imageName else { return }
        
        let audioFileUsage = audioFiles.filter { $0.artworkImageName == imageName }.count
        let playlistUsage = playlists.filter { $0.artworkImageName == imageName }.count
        
        if audioFileUsage == 0 && playlistUsage == 0 {
            let fileURL = artworkDirectory.appendingPathComponent(imageName)
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
    
    func play(audioFile: AudioFile, context: [AudioFile]? = nil, fromSongsTab: Bool = false) {
        let isSameSong = currentlyPlayingID == audioFile.id
        
        if let context = context {
            self.playbackQueue = context
        } else if playbackQueue.isEmpty || !playbackQueue.contains(where: { $0.id == audioFile.id }) {
            self.playbackQueue = sortedAudioFiles
        }
        
        self.playingFromSongsTab = fromSongsTab
        
        if isSameSong {
            updateNowPlayingInfo()
            return
        }
        
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            print("Could not activate session: \(error)")
            return
        }
        
        guard let engine = currentEngine else { return }
        
        stopTimer()
        self.currentTime = 0
        
        if currentlyPlayingID != audioFile.id {
            engine.stop()
        }
        
        engine.load(audioFile: audioFile)
        engine.setTempo(tempo)
        engine.setPitch(pitch)
        
        engine.play()
        
        isPlaying = true
        self.currentlyPlayingID = audioFile.id
        self.duration = TimeInterval(audioFile.audioDuration)
        startTimer()
        updateNowPlayingInfo()
    }
    
    func stop() {
        currentEngine?.stop()
        isPlaying = false
        currentTime = 0
        currentlyPlayingID = nil
        stopTimer()
        
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Deactivation failed: \(error)")
        }
    }
    
    func togglePlayPause() {
        guard let engine = currentEngine else {return}
        
        if engine.isPlaying {
            engine.pause()
            isPlaying = false
            stopTimer()
            updateNowPlayingInfo()
        } else {
            engine.play()
            isPlaying = true
            startTimer()
            updateNowPlayingInfo()
        }
    }
    
    func updatePlaylistOrder(_ playlist: Playlist, with ids: [UUID]) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        playlists[index].audioFileIDs = ids
        savePlaylists()
        
        if !playingFromSongsTab {
            let reorderedSongs = ids.compactMap { id in audioFiles.first { $0.id == id } }
            playbackQueue = reorderedSongs
        }
    }
    
    func seek(to time: TimeInterval){
        isSeeking = true
        currentEngine?.seek(to: time)
        currentTime = time
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.isSeeking = false
        }
    }
    
    func setVolume(_ volume: Float){
        currentEngine?.setVolume(volume)
    }
    
    func setTempo(_ newTempo: Float){
        tempo = max(0.1, min(4.0, newTempo))
        currentEngine?.setTempo(tempo)
    }
    
    func setPitch(_ newPitch: Float){
        pitch = max(-2400, min(2400, newPitch))
        currentEngine?.setPitch(pitch)
    }
    
    private func startTimer(){
        var lastSecond = -1
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self = self, let engine = self.currentEngine else { return }
            
            if self.isSeeking { return }
            
            let engineTime = engine.currentTime
            let currentSecond = Int(engineTime)
            
            self.currentTime = engineTime
            
            if currentSecond != lastSecond {
                lastSecond = currentSecond
                self.updateNowPlayingInfo()
            }
            
            if self.currentTime >= self.duration && self.duration > 0 {
                self.skipNextSong()
            }
        }
    }
    
    private func stopTimer(){
        timer?.invalidate()
        timer = nil
    }
    
    func skipPreviousSong() {
        if currentTime > 3.0 {
            restartCurrentSong()
            return
        }
        stopTimer()
        guard let currentIndex = playbackQueue.firstIndex(where: { $0.id == currentlyPlayingID }) else {
            return
        }
        
        let previousIndex = currentIndex - 1
        if previousIndex >= 0 {
            play(audioFile: playbackQueue[previousIndex], context: playbackQueue, fromSongsTab: playingFromSongsTab)
        } else {
            restartCurrentSong()
        }
    }
    
    private func restartCurrentSong(){
        seek(to: 0)
        
        if !isPlaying {
            currentEngine?.play()
            isPlaying = true
        }
        
        if timer == nil {
            startTimer()
        }
        self.currentTime = 0
        updateNowPlayingInfo()
    }
    
    func skipNextSong(){
        stopTimer()
        guard !playbackQueue.isEmpty else {
            stop()
            return
        }
        
        if let currentIndex = playbackQueue.firstIndex(where: { $0.id == currentlyPlayingID }) {
            let nextIndex = currentIndex + 1
            if nextIndex < playbackQueue.count {
                play(audioFile: playbackQueue[nextIndex], context: playbackQueue, fromSongsTab: playingFromSongsTab)
            } else {
                if isLooping {
                    if let firstFile = playbackQueue.first {
                        play(audioFile: firstFile, context: playbackQueue, fromSongsTab: playingFromSongsTab)
                    }
                } else {
                    stop()
                }
            }
        } else {
            if let firstFile = playbackQueue.first {
                play(audioFile: firstFile, context: playbackQueue, fromSongsTab: playingFromSongsTab)
            }
        }
    }
    
    func reorderSelectedSongs(selectedIDs: [UUID], to destination: Int, in currentSongs: [AudioFile], playlist: Playlist? = nil) {
        let selectedIndices = currentSongs.enumerated()
            .filter { selectedIDs.contains($0.element.id) }
            .map { $0.offset }
            .sorted()
        
        let selectedSongs = selectedIndices.map { currentSongs[$0] }
        var songs = currentSongs
        
        for index in selectedIndices.reversed() {
            songs.remove(at: index)
        }
        
        let adjustedDestination = destination - selectedIndices.filter { $0 < destination }.count
        
        songs.insert(contentsOf: selectedSongs, at: adjustedDestination)
        
        if let playlist = playlist {
            guard let playlistIndex = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
            
            let reorderedIDs = songs.map { $0.id }
            playlists[playlistIndex].audioFileIDs = reorderedIDs
            savePlaylists()
            
            if !playingFromSongsTab {
                playbackQueue = songs
            }
        } else {
            displayedSongs = songs
            
            guard let masterID = masterPlaylistID,
                  let index = playlists.firstIndex(where: { $0.id == masterID }) else { return }
            
            let reorderedIDs = songs.map { $0.id }
            playlists[index].audioFileIDs = reorderedIDs
            savePlaylists()
            
            if playingFromSongsTab {
                playbackQueue = displayedSongs
            }
        }
    }
    
}

extension AudioManager: AVAudioPlayerDelegate{
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool){
        isPlaying = false
        currentlyPlayingID = nil
        currentTime = 0
        stopTimer()
    }
}

