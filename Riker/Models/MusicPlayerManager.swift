import MediaPlayer
import SwiftUI

class MusicPlayerManager: ObservableObject {
    static let shared = MusicPlayerManager()
    private let player = MPMusicPlayerController.applicationMusicPlayer
    private var playbackObserver: NSObjectProtocol?
    private var nowPlayingObserver: NSObjectProtocol?
    private var timeObserver: Timer?
    private var hasScrobbled = false
    
    @Published var currentTrack: MPMediaItem?
    @Published var isPlaying = false
    @Published var albums: [MPMediaItemCollection] = []
    @Published var playlists: [MPMediaItemCollection] = []
    @Published var currentPlaybackTime: TimeInterval = 0
    
    private init() {
        setupNotifications()
        requestPermissions()
        setupPlaybackObservers()
        setupTimeObserver()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePlaybackStateChanged),
            name: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: player)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNowPlayingItemChanged),
            name: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: player)
        
        player.beginGeneratingPlaybackNotifications()
    }
    
    private func requestPermissions() {
        MPMediaLibrary.requestAuthorization { [weak self] status in
            if status == .authorized {
                DispatchQueue.main.async {
                    self?.loadLibrary()
                }
            }
        }
    }
    
    private func loadLibrary() {
        let albumsQuery = MPMediaQuery.albums()
        albums = albumsQuery.collections ?? []
        
        let playlistsQuery = MPMediaQuery.playlists()
        playlists = playlistsQuery.collections ?? []
    }
    
    @objc private func handlePlaybackStateChanged() {
        DispatchQueue.main.async {
            self.isPlaying = self.player.playbackState == .playing
            if !self.isPlaying {
                self.currentPlaybackTime = self.player.currentPlaybackTime
            }
        }
    }
    
    @objc private func handleNowPlayingItemChanged() {
        DispatchQueue.main.async {
            self.currentTrack = self.player.nowPlayingItem
            self.currentPlaybackTime = 0
            self.hasScrobbled = false
        }
    }
    
    private func setupPlaybackObservers() {
        nowPlayingObserver = NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: player,
            queue: .main
        ) { [weak self] _ in
            self?.hasScrobbled = false
            self?.objectWillChange.send()
        }
    }
    
    private func setupTimeObserver() {
        // Update playback time every 0.5 seconds
        timeObserver = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self,
                  let currentItem = self.player.nowPlayingItem,
                  self.player.playbackState == .playing else { return }
            
            let currentTime = self.player.currentPlaybackTime
            self.currentPlaybackTime = currentTime
            
            // Check for scrobbling threshold
            if !self.hasScrobbled && currentTime > (currentItem.playbackDuration * 2/3) {
                self.hasScrobbled = true
                ListenBrainzClient.shared.submitListen(for: currentItem)
            }
        }
    }
    
    deinit {
        if let playbackObserver = playbackObserver {
            NotificationCenter.default.removeObserver(playbackObserver)
        }
        if let nowPlayingObserver = nowPlayingObserver {
            NotificationCenter.default.removeObserver(nowPlayingObserver)
        }
        timeObserver?.invalidate()
    }
    
    func play() {
        player.play()
        isPlaying = true
    }
    
    func pause() {
        player.pause()
        isPlaying = false
    }
    
    func playNext() {
        player.skipToNextItem()
    }
    
    func playCollection(_ collection: MPMediaItemCollection, startingWith item: MPMediaItem? = nil) {
        player.stop()
        player.setQueue(with: collection)
        if let item = item {
            player.nowPlayingItem = item
        }
        play()
    }
    
    func seek(to time: TimeInterval) {
        player.currentPlaybackTime = time
        currentPlaybackTime = time
    }
} 