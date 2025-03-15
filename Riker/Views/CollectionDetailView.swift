import SwiftUI
import MediaPlayer

struct CollectionDetailView: View {
    let collection: MPMediaItemCollection
    @ObservedObject private var playerManager = MusicPlayerManager.shared
    @ObservedObject private var toastManager = ToastManager.shared
    
    var body: some View {
        List {
            // Header with artwork and metadata
            if let representative = collection.representativeItem {
                Section {
                    HStack(alignment: .top, spacing: 16) {
                        // Artwork
                        if let artwork = representative.artwork {
                            Image(uiImage: artwork.image(at: CGSize(width: 120, height: 120)) ?? UIImage())
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 120, height: 120)
                                .cornerRadius(8)
                        } else {
                            Image(systemName: collection is MPMediaPlaylist ? "music.note.list" : "music.note")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 120, height: 120)
                                .padding(24)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                        }
                        
                        // Metadata
                        VStack(alignment: .leading, spacing: 4) {
                            if collection is MPMediaPlaylist {
                                Text(collection.value(forProperty: MPMediaPlaylistPropertyName) as? String ?? "Unknown Playlist")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("Playlist")
                                    .foregroundColor(.secondary)
                            } else {
                                Text(representative.albumTitle ?? "Unknown Album")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text(representative.artist ?? "Unknown Artist")
                                    .foregroundColor(.secondary)
                            }
                            
                            Text("\(collection.items.count) songs")
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                            
                            Button(action: {
                                playerManager.playCollection(collection)
                                toastManager.show("Playing \(collection is MPMediaPlaylist ? "playlist" : "album")")
                            }) {
                                Label("Play", systemImage: "play.fill")
                            }
                            .buttonStyle(.bordered)
                            .tint(.accentColor)
                            .padding(.top, 8)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            
            // Track list
            Section {
                ForEach(collection.items, id: \.persistentID) { item in
                    Button(action: {
                        playerManager.playCollection(collection, startingWith: item)
                        toastManager.show("Playing \(item.title ?? "Unknown Track")")
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.title ?? "Unknown Track")
                                    .foregroundColor(isCurrentTrack(item) ? .accentColor : .primary)
                                    .fontWeight(isCurrentTrack(item) ? .semibold : .regular)
                                Text(item.artist ?? "Unknown Artist")
                                    .font(.subheadline)
                                    .foregroundColor(isCurrentTrack(item) ? .accentColor.opacity(0.8) : .secondary)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 8) {
                                if isCurrentTrack(item) && playerManager.isPlaying {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .foregroundColor(.accentColor)
                                }
                                Text(formatDuration(item.playbackDuration))
                                    .font(.subheadline)
                                    .foregroundColor(isCurrentTrack(item) ? .accentColor : .secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func isCurrentTrack(_ item: MPMediaItem) -> Bool {
        return playerManager.currentTrack?.persistentID == item.persistentID
    }
} 