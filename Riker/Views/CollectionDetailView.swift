import SwiftUI
import MediaPlayer
import CommonCrypto
import AVFoundation

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
                                Group {
                                    Text("Asset URL: \(assetURL.absoluteString)")
                                    
                                    // Pass both assetURL and the MPMediaItem
                                    AsyncMetadataView(assetURL: assetURL, mediaItem: item)
                                }
                                .foregroundColor(.secondary)
                                .font(.caption.monospaced())
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

struct AsyncMetadataView: View {
    let assetURL: URL
    let mediaItem: MPMediaItem
    @State private var assetInfo: AssetInfo?
    @State private var error: String?
    
    var body: some View {
        Group {
            if let error = error {
                Text("Error: \(error)")
                    .foregroundColor(.red)
            } else if let info = assetInfo {
                VStack(alignment: .leading, spacing: 12) {
                    if !info.metadata.isEmpty {
                        Group {
                            Text("MusicBrainz Metadata").font(.headline)
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(Array(info.metadata.keys.sorted()), id: \.self) { key in
                                    if let value = info.metadata[key] {
                                        MetadataRow(key: key, value: value)
                                        
                                        // Add MusicBrainz link if it's a recording ID
                                        if key == "Track Id" || key == "Recording ID" {
                                            Link("View on MusicBrainz",
                                                 destination: URL(string: "https://musicbrainz.org/recording/\(value)")!)
                                                .foregroundColor(.blue)
                                                .padding(.top, 4)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                ProgressView()
                    .progressViewStyle(.circular)
            }
        }
        .onAppear {
            loadAssetMetadata()
        }
    }
    
    @MainActor
    private func loadAssetMetadata() {
        let asset = AVAsset(url: assetURL)
        
        Task {
            await loadMetadata(for: asset)
        }
    }
    
    private func loadMetadata(for asset: AVAsset) async {
        do {
            var info = AssetInfo()
            
            // Try to read metadata directly from AVAsset first
            let metadata = try await asset.load(.metadata)
            
            // Create an array to hold dictionaries for each item.
            var metadataArray: [[String: Any]] = []
            
            // Process MusicBrainz IDs based on format
            var musicBrainzInfo: [String: String] = [:]
            
            // Add all AVFoundation metadata
            for item in metadata {
                do {
                    let value = try await item.load(.value)
                    let key = item.commonKey?.rawValue ?? (item.key as? String ?? "unknown")
                    
                    // Store all metadata first
                    switch value {
                    case let string as String:
                        info.metadata[key] = string
                    case let data as Data:
                        // Try to interpret data as UTF-8 string
                        if let string = String(data: data, encoding: .utf8) {
                            info.metadata[key] = string
                        } else {
                            info.metadata[key] = "Data(\(data.count) bytes)"
                        }
                    default:
                        info.metadata[key] = String(describing: value)
                    }
                    
                    // Store the actual key from the metadata item if available
                    if let actualKey = item.key as? String {
                        info.metadata[actualKey] = info.metadata[key]
                    }
                    
                } catch {
                    print("Failed to load metadata value: \(error.localizedDescription)")
                }
            }

            let id3MetadataItems = try await asset.loadMetadata(for: .id3Metadata)


            for item in id3MetadataItems {
               
                // Include extraAttributes if available.
                if (item.key as! String == "TXXX") {
                    if let extras = try await item.load(.extraAttributes)  {
                        if let extraKey = extras[AVMetadataExtraAttributeKey.info] as? String {
                            if (extraKey.hasPrefix("MusicBrainz ")) {
                                musicBrainzInfo[extraKey.replacingOccurrences(of: "MusicBrainz ", with: "")] = try await item.load(.stringValue)  ?? "<non-string value>";
                            }
                        }
                    }
                }
                  
                
            }

            // First check for M4A style iTunes metadata
            for (key, value) in info.metadata {
                if key.hasPrefix("com.apple.iTunes.MusicBrainz") {
                    let cleanKey = key.replacingOccurrences(of: "com.apple.iTunes.MusicBrainz ", with: "")
                    musicBrainzInfo[cleanKey] = value
                }
            }
                        
            // Update the metadata with processed MusicBrainz info
            info.metadata = musicBrainzInfo
            
            await MainActor.run {
                self.assetInfo = info
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
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

