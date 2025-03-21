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
                                    
                                    // Load asset metadata
                                    AsyncMetadataView(assetURL: assetURL)
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
    @State private var assetInfo: AssetInfo?
    @State private var error: String?
    
    var body: some View {
        Group {
            if let error = error {
                Text("Error: \(error)")
                    .foregroundColor(.red)
            } else if let info = assetInfo {
                VStack(alignment: .leading, spacing: 4) {
                    if !info.metadata.isEmpty {
                        ForEach(info.metadata.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                            Text("\(key):")
                            Text(value)
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
            
            // Metadata
            for item in try await asset.load(.metadata) {
                do {
                    let value = try await item.load(.value)
                    let key = item.commonKey?.rawValue ?? (item.key as? String ?? "unknown")
                    
                    switch value {
                    case let string as String:
                        info.metadata[key] = string
                    case let number as NSNumber:
                        info.metadata[key] = number.stringValue
                    case let date as Date:
                        info.metadata[key] = ISO8601DateFormatter().string(from: date)
                    case let data as Data:
                        info.metadata[key] = "Data(\(data.count) bytes)"
                    case let array as [Any]:
                        info.metadata[key] = array.description
                    case let dict as [String: Any]:
                        info.metadata[key] = dict.description
                    default:
                        info.metadata[key] = String(describing: value)
                    }
                } catch {
                    print("Failed to load metadata value: \(error.localizedDescription)")
                }
            }
            
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
        return String(bytes: bytes, encoding: .utf8) ?? "Unknown"
    }
} 
