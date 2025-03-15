import SwiftUI
import MediaPlayer

struct LibraryView: View {
    @ObservedObject private var playerManager = MusicPlayerManager.shared
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(playerManager.albums, id: \.persistentID) { album in
                    if let representative = album.representativeItem {
                        NavigationLink(destination: CollectionDetailView(collection: album)) {
                            HStack {
                                if let artwork = representative.artwork {
                                    Image(uiImage: artwork.image(at: CGSize(width: 50, height: 50)) ?? UIImage())
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 50, height: 50)
                                        .cornerRadius(4)
                                } else {
                                    Image(systemName: "music.note")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 50, height: 50)
                                        .padding(8)
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(4)
                                }
                                
                                VStack(alignment: .leading) {
                                    Text(representative.albumTitle ?? "Unknown Album")
                                        .font(.body)
                                    Text(representative.artist ?? "Unknown Artist")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.leading, 8)
                            }
                        }
                    }
                }
                
                ForEach(playerManager.playlists, id: \.persistentID) { playlist in
                    NavigationLink(destination: CollectionDetailView(collection: playlist)) {
                        HStack {
                            if let firstItem = playlist.items.first,
                               let artwork = firstItem.artwork {
                                Image(uiImage: artwork.image(at: CGSize(width: 50, height: 50)) ?? UIImage())
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 50, height: 50)
                                    .cornerRadius(4)
                            } else {
                                Image(systemName: "music.note.list")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 50, height: 50)
                                    .padding(8)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(4)
                            }
                            
                            VStack(alignment: .leading) {
                                Text(playlist.value(forProperty: MPMediaPlaylistPropertyName) as? String ?? "Unknown Playlist")
                                    .font(.body)
                                Text("Playlist")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.leading, 8)
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }
} 
