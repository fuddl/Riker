import SwiftUI
import MediaPlayer

struct CollectionDetailView: View {
    let collection: MPMediaItemCollection
    @ObservedObject private var playerManager = MusicPlayerManager.shared
    
    var body: some View {
        List {
            // Header
            if let representative = collection.representativeItem {
                CollectionHeader(representative: representative)
            }
            
            // Songs
            ForEach(collection.items, id: \.persistentID) { item in
                Button(action: {
                    playerManager.playCollection(collection, startingWith: item)
                }) {
                    SongRow(item: item, isPlaying: playerManager.currentTrack?.persistentID == item.persistentID)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CollectionHeader: View {
    let representative: MPMediaItem
    
    var body: some View {
        VStack(spacing: 16) {
            if let artwork = representative.artwork {
                Image(uiImage: artwork.image(at: CGSize(width: 200, height: 200)) ?? UIImage())
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200, height: 200)
                    .cornerRadius(8)
            } else {
                Image(systemName: "music.note")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200, height: 200)
                    .padding(40)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }
            
            VStack(spacing: 4) {
                Text(representative.albumTitle ?? "Unknown Album")
                    .font(.title2)
                    .fontWeight(.bold)
                Text(representative.artist ?? "Unknown Artist")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
        .listRowInsets(EdgeInsets())
        .background(Color(UIColor.systemBackground))
    }
}

struct SongRow: View {
    let item: MPMediaItem
    let isPlaying: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(item.title ?? "Unknown Title")
                    .font(.body)
                    .foregroundColor(isPlaying ? .accentColor : .primary)
                if let artist = item.artist {
                    Text(artist)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if isPlaying {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundColor(.accentColor)
            }
        }
        .contentShape(Rectangle())
    }
} 