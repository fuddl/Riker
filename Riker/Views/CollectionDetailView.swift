import SwiftUI
import MediaPlayer

struct CollectionDetailView: View {
    let collection: MPMediaItemCollection
    @ObservedObject private var playerManager = MusicPlayerManager.shared
    @ObservedObject private var toastManager = ToastManager.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header with artwork
                if let representative = collection.representativeItem {
                    ZStack(alignment: .top) {
                        // Artwork
                        if let artwork = representative.artwork {
                            VStack(spacing: 0) {
                                let artworkImage = Image(uiImage: artwork.image(at: CGSize(width: UIScreen.main.bounds.width, height: 400)) ?? UIImage())
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .clipped()
                                
                                ZStack {
                                    artworkImage
                                        .frame(height: UIApplication.shared.windows.first?.safeAreaInsets.top, alignment: .topLeading)
                                        .scaleEffect(x: 1, y: -1)
                                    artworkImage
                                        .frame(height: UIApplication.shared.windows.first?.safeAreaInsets.top, alignment: .topLeading)
                                        .blur(radius: 5)
                                        .scaleEffect(x: 1, y: -1)
                                }
                                
                                artworkImage
                            }
                        } else {
                            Image(systemName: collection is MPMediaPlaylist ? "music.note.list" : "music.note")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 400)
                                .padding(24)
                                .background(Color.gray.opacity(0.2))
                        }
                        

                    }
                    .ignoresSafeArea(edges: .top)
                    
                    // Metadata
                    HStack() {
                        VStack(alignment: .leading) {
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
                        }

                        Spacer();
                        
                        
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
                    .padding()
                }
                
                // Track list
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
                                    .multilineTextAlignment(.leading)
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
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    Divider()
                        .padding(.leading)
                }
            }
        }
        .ignoresSafeArea(edges: .top)
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
