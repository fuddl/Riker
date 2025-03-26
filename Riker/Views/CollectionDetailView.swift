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
    @State private var isReloading = false
    @State private var isLoadingListenCount = false
    @State private var listenCount: Int?
    
    init(collection: MPMediaItemCollection) {
        self.collection = collection
    }
    
    var body: some View {
        ZStack(alignment: .top) {
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
                                    Text(releaseGroup?.title ?? representative.albumTitle ?? "Unknown Album")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                    if let artistCredit = releaseGroup?.artistCredit {
                                        let artists = artistCredit.map { $0.name + ($0.joinPhrase ?? "") }.joined()
                                        Text(artists)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text(representative.artist ?? "Unknown Artist")
                                            .foregroundColor(.secondary)
                                    }
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
                        if let genres = releaseGroup?.genres, !genres.isEmpty {
                            Group {
                                Text(genres.map { $0.name }.joined(separator: " · "))
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                        } else {
                            Group {
                                if let genre = representative.genre {
                                    Text(genre.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: " · "))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                        }
                    }

                    
                    // Track list
                    ForEach(collection.items, id: \.persistentID) { item in
                        TrackRowView(
                            item: item,
                            isCurrentTrack: isCurrentTrack(item),
                            isPlaying: playerManager.isPlaying,
                            metadata: metadataByTrack[item.persistentID],
                            onTap: {
                                playerManager.playCollection(collection, startingWith: item)
                            }
                        )
                        Divider()
                            .padding(.leading)
                    }
                    
                    if let releaseGroup = releaseGroup {
                        VStack() {
                            HStack() {                          // First release
                                if let firstReleaseDate = releaseGroup.firstReleaseDate {
                                    VStack(spacing: 2) {
                                        Image(systemName: "sparkles")
                                            .foregroundColor(.secondary)
                                        Text(formatDate(firstReleaseDate)!)
                                        .font(.headline)
                                        Text("first released")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(10)
                            HStack(spacing: 20) {
                                // Rating
                                if let rating = releaseGroup.rating,
                                let votesCount = rating.votesCount {         
                                    VStack {
                                        Text("Rating")
                                            .font(.headline)
                                        let value = rating.value ?? 0
                                        let roundedValue = round(value * 2) / 2 // Round to nearest 0.5
                                        let fullStars = Int(roundedValue)
                                        let hasHalfStar = roundedValue.truncatingRemainder(dividingBy: 1) != 0
                                        let emptyStars = 5 - fullStars - (hasHalfStar ? 1 : 0)
                                        
                                        HStack(spacing: 2) {
                                            ForEach(0..<fullStars, id: \.self) { _ in
                                                Image(systemName: "star.fill")
                                                    .foregroundColor(.secondary)
                                            }
                                            if hasHalfStar {
                                                Image(systemName: "star.leadinghalf.filled")
                                                    .foregroundColor(.secondary)
                                            }
                                            ForEach(0..<emptyStars, id: \.self) { _ in
                                                Image(systemName: "star")
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .font(.subheadline)
                                        
                                        Text(votesCount > 0 ? "Based on \(votesCount) \(votesCount == 1 ? "vote" : "votes")" : "No ratings yet")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                
                                // Listen Count
                                if isLoadingListenCount {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                } else if let listenCount = listenCount {
                                    Link(destination: URL(string: "https://listenbrainz.org/release-group/\(releaseGroup.id)")!) {
                                        VStack {
                                            Image(systemName: "headphones")
                                                .foregroundColor(.secondary)
                                            Text(formatNumber(listenCount))
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            Text("times played")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
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
            
            // Loading indicator in front of everything
            if isLoadingReleaseInfo || isReloading {
                VStack {
                    HStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.accentColor)
                        Spacer()
                    }
                    .padding(.top, UIApplication.shared.windows.first?.safeAreaInsets.top ?? 47)
                    Spacer()
                }
            }
        }
        .refreshable {
            await reloadMusicBrainzData()
            loadReleaseInformation()
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
            isLoadingListenCount = true
            
            Task {
                do {
                    // Fetch release group information
                    let releaseGroup = try await MusicBrainzClient.shared.fetchReleaseGroup(id: firstId)
                    
                    // Use the existing method for listen count
                    let count = try await ListenBrainzClient.shared.getReleaseGroupListenCount(releaseGroupId: firstId)
                    
                    // If we have a release ID, fetch release information
                    var release: MusicBrainzClient.Release?
                    if let releaseId = collection.items.first?.musicbrainz.releaseId {
                        release = try await MusicBrainzClient.shared.fetchRelease(id: releaseId)
                    }
                    
                    await MainActor.run {
                        self.releaseGroup = releaseGroup
                        self.release = release
                        self.listenCount = count
                        self.isLoadingReleaseInfo = false
                        self.isLoadingListenCount = false
                    }
                } catch {
                    print("Error loading release information: \(error)")
                    await MainActor.run {
                        self.isLoadingReleaseInfo = false
                        self.isLoadingListenCount = false
                    }
                }
            }
        } else {
            releaseGroup = nil
            release = nil
            listenCount = nil
        }
    }
    
    private func reloadMusicBrainzData() async {
        isReloading = true
        defer { isReloading = false }
        
        // Extract IDs from the first track's metadata
        if let firstTrack = collection.items.first,
           let releaseGroupId = firstTrack.musicbrainz.releaseGroupId,
           let releaseId = firstTrack.musicbrainz.releaseId {
            
            MusicBrainzClient.shared.clearCache(releaseGroupId: releaseGroupId, releaseId: releaseId)
        }
    }
    
    // Add this helper function for formatting numbers
    private func formatNumber(_ number: Int) -> String {
        if number >= 1_000_000 {
            return String(format: "%.1f,000,000+", Double(number) / 1_000_000)
        } else if number >= 1_000 {
            return String(format: "%.0f,000+", Double(number) / 1_000)
        }
        return "\(number)"
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale.current
        return formatter
    }()

    private func formatDate(_ dateString: String?) -> String? {
        guard let dateString = dateString else { return nil }
        
        // MusicBrainz dates are typically in YYYY-MM-DD format
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        
        if let date = inputFormatter.date(from: dateString) {
            return dateFormatter.string(from: date)
        }
        
        // If the date string doesn't match the expected format, return it as is
        return dateString
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
