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
        
        print("Bitmap info: \(cgImage.bitmapInfo.rawValue)")
        print("Alpha info: \(alphaInfo.rawValue)")
        print("Byte order: \(byteOrder)")
        
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
        
        print("First pixel: R:\(firstPixel.red) G:\(firstPixel.green) B:\(firstPixel.blue) A:\(firstPixel.alpha)")
        print("Image properties:")
        print("Width: \(width)")
        print("Height: \(height)")
        print("Bits per component: \(cgImage.bitsPerComponent)")
        print("Bits per pixel: \(cgImage.bitsPerPixel)")
        print("BytesPerRow: \(cgImage.bytesPerRow)")
        print("Color space: \(cgImage.colorSpace?.name ?? "unknown" as CFString)")
        
        print("\nFirst 20 pixels raw values:")
        for i in 0..<min(20, width) {
            let offset = i * 4
            let components = getColorComponents(from: offset)
            print("Pixel \(i): [\(components.red), \(components.green), \(components.blue), \(components.alpha)]")
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
                print("\nInconsistency found at pixel \(x):")
                print("Raw bytes: [\(components.red), \(components.green), \(components.blue), \(components.alpha)]")
                print("Current pixel: R:\(red) G:\(green) B:\(blue)")
                print("Differences: R:\(abs(red - firstPixel.red)) G:\(abs(green - firstPixel.green)) B:\(abs(blue - firstPixel.blue))")
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
