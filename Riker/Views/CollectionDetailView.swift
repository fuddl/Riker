import SwiftUI
import MediaPlayer
import CommonCrypto
import AVFoundation

struct CollectionDetailView: View {
    let collection: MPMediaItemCollection
    @ObservedObject private var playerManager = MusicPlayerManager.shared
    @ObservedObject private var toastManager = ToastManager.shared
    @State private var metadataByTrack: [UInt64: MusicBrainzMetadata] = [:]
    @State private var releaseGroup: MusicBrainzClient.ReleaseGroup?
    @State private var release: MusicBrainzClient.Release?
    @State private var isLoadingReleaseInfo = false
    
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
                
                // Release Information Section
                if !collection.items.isEmpty {
                    Section {
                        MusicBrainzReleaseInfoView(
                            releaseGroup: releaseGroup,
                            release: release,
                            isLoading: isLoadingReleaseInfo
                        )
                    } header: {
                        Text("Release Information")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding()
                    }
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
            
            // Load release information if all tracks have the same release group ID
            loadReleaseInformation()
        }
        .onReceive(NotificationCenter.default.publisher(for: .musicBrainzMetadataDidUpdate)) { notification in
            if let updatedId = notification.object as? UInt64,
               let item = collection.items.first(where: { $0.persistentID == updatedId }) {
                metadataByTrack[updatedId] = item.musicbrainz
                // Reload release information when metadata is updated
                loadReleaseInformation()
            }
        }
    }
    
    func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func isCurrentTrack(_ item: MPMediaItem) -> Bool {
        return playerManager.currentTrack?.persistentID == item.persistentID
    }
    
    private func loadReleaseInformation() {
        // Get all release group IDs from the collection
        let releaseGroupIds = collection.items.compactMap { item in
            metadataByTrack[item.persistentID]?.releaseGroupId ?? item.musicbrainz.releaseGroupId
        }
        
        // Check if all tracks have the same release group ID
        if let firstId = releaseGroupIds.first,
           releaseGroupIds.allSatisfy({ $0 == firstId }) {
            isLoadingReleaseInfo = true
            
            Task {
                do {
                    // Fetch release group information
                    let releaseGroup = try await MusicBrainzClient.shared.fetchReleaseGroup(id: firstId)
                    
                    // If we have a release ID, fetch release information
                    var release: MusicBrainzClient.Release?
                    if let releaseId = collection.items.first?.musicbrainz.releaseId {
                        release = try await MusicBrainzClient.shared.fetchRelease(id: releaseId)
                    }
                    
                    await MainActor.run {
                        self.releaseGroup = releaseGroup
                        self.release = release
                        self.isLoadingReleaseInfo = false
                    }
                } catch {
                    print("Error loading release information: \(error)")
                    await MainActor.run {
                        self.isLoadingReleaseInfo = false
                    }
                }
            }
        } else {
            releaseGroup = nil
            release = nil
        }
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
