import SwiftUI
import MediaPlayer

struct PlayerBar: View {
    @ObservedObject private var playerManager = MusicPlayerManager.shared
    
    var body: some View {
        if let currentTrack = playerManager.currentTrack {
            VStack(spacing: 0) {
                // Seek bar
                SeekBar(
                    duration: currentTrack.playbackDuration,
                    currentTime: playerManager.currentPlaybackTime,
                    onSeek: { time in
                        playerManager.seek(to: time)
                    }
                )
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Player controls
                HStack {
                    // Album artwork
                    if let artwork = currentTrack.artwork {
                        Image(uiImage: artwork.image(at: CGSize(width: 40, height: 40)) ?? UIImage())
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                            .cornerRadius(4)
                    } else {
                        Image(systemName: "music.note")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                            .padding(8)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                    }
                    
                    // Track info
                    VStack(alignment: .leading) {
                        Text(currentTrack.title ?? "Unknown Track")
                            .font(.body)
                            .lineLimit(1)
                        Text(currentTrack.artist ?? "Unknown Artist")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Playback controls
                    HStack(spacing: 20) {
                        Button(action: {
                            if playerManager.isPlaying {
                                playerManager.pause()
                            } else {
                                playerManager.play()
                            }
                        }) {
                            Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title2)
                        }
                        
                        Button(action: {
                            playerManager.playNext()
                        }) {
                            Image(systemName: "forward.fill")
                                .font(.title2)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .background(.thinMaterial)
        }
    }
} 