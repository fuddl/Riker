import SwiftUI
import MediaPlayer

struct MediaItemRow: View {
    let artwork: MPMediaItemArtwork?
    let title: String
    let subtitle: String
    let defaultIcon: String
    
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Group {
                if let artwork = artwork {
                    Image(uiImage: artwork.image(at: CGSize(width: 50, height: 50)) ?? UIImage())
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 50, height: 50)
                } else {
                    Image(systemName: defaultIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 34, height: 34)
                        .padding(8)
                        .background(Color.gray.opacity(0.2))
                }
            }
            .cornerRadius(4)
            .alignmentGuide(.firstTextBaseline) { d in
                d.height * 0.35
            }
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.body)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.leading, 8)
        }
    }
}

struct LibraryView: View {
    @ObservedObject private var playerManager = MusicPlayerManager.shared
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(playerManager.albums, id: \.persistentID) { album in
                    if let representative = album.representativeItem {
                        NavigationLink(destination: CollectionDetailView(collection: album)) {
                            MediaItemRow(
                                artwork: representative.artwork,
                                title: representative.albumTitle ?? "Unknown Album",
                                subtitle: representative.artist ?? "Unknown Artist",
                                defaultIcon: "music.note"
                            )
                        }
                    }
                }
                
                ForEach(playerManager.playlists, id: \.persistentID) { playlist in
                    NavigationLink(destination: CollectionDetailView(collection: playlist)) {
                        MediaItemRow(
                            artwork: playlist.items.first?.artwork,
                            title: playlist.value(forProperty: MPMediaPlaylistPropertyName) as? String ?? "Unknown Playlist",
                            subtitle: "Playlist",
                            defaultIcon: "music.note.list"
                        )
                    }
                }
            }
            .listStyle(.plain)
        }
    }
} 
