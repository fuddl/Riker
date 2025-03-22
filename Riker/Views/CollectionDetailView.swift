import SwiftUI
import MediaPlayer
import CommonCrypto
import AVFoundation

struct CollectionDetailView: View {
    let collection: MPMediaItemCollection
    @ObservedObject private var playerManager = MusicPlayerManager.shared
    @ObservedObject private var toastManager = ToastManager.shared
    @State private var metadataByTrack: [UInt64: MusicBrainzMetadata] = [:]
    
    init(collection: MPMediaItemCollection) {
        self.collection = collection
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header with artwork
                if let representative = collection.representativeItem {
                    ZStack(alignment: .top) {
                        // Artwork
                        if let artwork = representative.artwork {
                            VStack(spacing: 0) {
                                if let uiImage = artwork.image(at: artwork.bounds.size) {
                                    let analysis = uiImage.analyzeFirstRowColors()
                                    if analysis.isConsistent {
                                        // solid color
                                        GeometryReader { geometry in
                                            Rectangle()
                                                .fill(Color(analysis.dominantColor ?? .clear))
                                                .frame(height: UIScreen.main.bounds.height)
                                                .position(x: UIScreen.main.bounds.width/2, y: (UIApplication.shared.windows.first?.safeAreaInsets.top ?? 0)/2)
                                        }
                                        .frame(height: UIApplication.shared.windows.first?.safeAreaInsets.top)
                                    } else {
                                        // reflection 
                                        ZStack {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .clipped()
                                                .frame(height: UIApplication.shared.windows.first?.safeAreaInsets.top, alignment: .topLeading)
                                                .scaleEffect(x: 1, y: -1)
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .clipped()
                                                .frame(height: UIApplication.shared.windows.first?.safeAreaInsets.top, alignment: .topLeading)
                                                .blur(radius: 5)
                                                .scaleEffect(x: 1, y: -1)
                                        }
                                    }
                                }
                                
                                Image(uiImage: artwork.image(at: CGSize(width: UIScreen.main.bounds.width, height: 400)) ?? UIImage())
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .clipped()
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
                                if let recordingId = metadataByTrack[item.persistentID]?.recordingId ?? item.musicbrainz.recordingId {
                                    Link(recordingId, 
                                         destination: URL(string: "https://musicbrainz.org/recording/\(recordingId)")!)
                                        .font(.caption2)
                                        .foregroundColor(.secondary.opacity(0.8))
                                }
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
                
                // Technical Metadata Section
                Section {
                    ForEach(collection.items, id: \.persistentID) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.title ?? "Unknown Track")
                                .font(.headline)
                            
                            if let assetURL = item.assetURL {
                                Text("Asset URL: \(assetURL.absoluteString)")
                                    .foregroundColor(.secondary)
                                    .font(.caption.monospaced())
                                
                                let metadata = metadataByTrack[item.persistentID] ?? item.musicbrainz
                                if !metadata.isEmpty {
                                    MusicBrainzMetadataView(metadata: metadata)
                                } else {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                }
                            } else {
                                Text("No asset URL available")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                } header: {
                    Text("Technical Metadata")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding()
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Trigger loading for all items
            for item in collection.items {
                _ = item.musicbrainz
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .musicBrainzMetadataDidUpdate)) { notification in
            if let updatedId = notification.object as? UInt64,
               let item = collection.items.first(where: { $0.persistentID == updatedId }) {
                metadataByTrack[updatedId] = item.musicbrainz
            }
        }
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

extension UIImage {
    func analyzeFirstRowColors() -> (isConsistent: Bool, dominantColor: UIColor?) {
        guard let cgImage = self.cgImage else { return (false, nil) }
        
        let width = cgImage.width
        let height = cgImage.height
        
        guard let provider = cgImage.dataProvider,
              let data = provider.data,
              let bytes = CFDataGetBytePtr(data) else {
            return (false, nil)
        }
        
        // Check bitmap info to determine byte order
        let alphaInfo = cgImage.alphaInfo
        let byteOrder = cgImage.bitmapInfo.rawValue & CGBitmapInfo.byteOrderMask.rawValue
        
        // Function to get correct color components based on byte order
        func getColorComponents(from offset: Int) -> (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
            if byteOrder == CGBitmapInfo.byteOrder32Little.rawValue {
                return (bytes[offset + 2], bytes[offset + 1], bytes[offset], bytes[offset + 3])
            } else {
                return (bytes[offset], bytes[offset + 1], bytes[offset + 2], bytes[offset + 3])
            }
        }
        
        let firstComponents = getColorComponents(from: 0)
        let firstPixel = (
            red: CGFloat(firstComponents.red) / 255.0,
            green: CGFloat(firstComponents.green) / 255.0,
            blue: CGFloat(firstComponents.blue) / 255.0,
            alpha: CGFloat(firstComponents.alpha) / 255.0
        )
        
        for i in 0..<min(20, width) {
            let offset = i * 4
            let components = getColorComponents(from: offset)
        }
        
        var isConsistent = true
        let threshold: CGFloat = 0.05
        
        for x in 0..<width {
            let offset = x * 4
            let components = getColorComponents(from: offset)
            let red = CGFloat(components.red) / 255.0
            let green = CGFloat(components.green) / 255.0
            let blue = CGFloat(components.blue) / 255.0
            
            if abs(red - firstPixel.red) > threshold ||
               abs(green - firstPixel.green) > threshold ||
               abs(blue - firstPixel.blue) > threshold {
                isConsistent = false
                break
            }
        }
        
        let dominantColor = UIColor(
            red: firstPixel.red,
            green: firstPixel.green,
            blue: firstPixel.blue,
            alpha: firstPixel.alpha
        )
        
        return (isConsistent, dominantColor)
    }
}

// Add this extension for SHA-256 hashing
extension Data {
    var sha256Hash: String {
        return withUnsafeBytes { bytes in
            var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
            CC_SHA256(bytes.baseAddress, CC_LONG(count), &hash)
            return hash.map { String(format: "%02x", $0) }.joined()
        }
    }
}

struct MusicBrainzMetadataView: View {
    let metadata: MusicBrainzMetadata
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("MusicBrainz IDs")
                .font(.subheadline)
                .fontWeight(.semibold)
                .padding(.top, 4)
            
            if let recordingId = metadata.recordingId {
                MetadataRow(key: "Recording", value: recordingId)
                Link("View Recording", destination: URL(string: "https://musicbrainz.org/recording/\(recordingId)")!)
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            if let artistId = metadata.artistId {
                MetadataRow(key: "Artist", value: artistId)
                Link("View Artist", destination: URL(string: "https://musicbrainz.org/artist/\(artistId)")!)
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            if let releaseId = metadata.releaseId {
                MetadataRow(key: "Release", value: releaseId)
                Link("View Release", destination: URL(string: "https://musicbrainz.org/release/\(releaseId)")!)
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            if let releaseGroupId = metadata.releaseGroupId {
                MetadataRow(key: "Release Group", value: releaseGroupId)
                Link("View Release Group", destination: URL(string: "https://musicbrainz.org/release-group/\(releaseGroupId)")!)
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            if let workId = metadata.workId {
                MetadataRow(key: "Work", value: workId)
                Link("View Work", destination: URL(string: "https://musicbrainz.org/work/\(workId)")!)
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            if let acousticId = metadata.acousticId {
                MetadataRow(key: "AcousticID", value: acousticId)
            }
            
            if let originalYear = metadata.originalYear {
                MetadataRow(key: "Original Year", value: originalYear)
            }
        }
    }
}

struct MetadataRow: View {
    let key: String
    let value: String?
    
    var body: some View {
        if let value = value {
            HStack(alignment: .top) {
                Text(key)
                    .foregroundColor(.secondary)
                    .frame(width: 100, alignment: .leading)
                Text(value)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct AssetInfo {
    var metadata: [String: String] = [:]
}

extension FourCharCode {
    func toString() -> String {
        let bytes: [UInt8] = [
            UInt8((self >> 24) & 0xFF),
            UInt8((self >> 16) & 0xFF),
            UInt8((self >> 8) & 0xFF),
            UInt8(self & 0xFF)
        ]
        return String(bytes: bytes, encoding: .utf8) ?? String(format: "%08x", self)
    }
}
