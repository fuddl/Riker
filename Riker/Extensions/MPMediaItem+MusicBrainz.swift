import MediaPlayer
import AVFoundation
import SwiftUI

// MusicBrainz metadata wrapper struct
public struct MusicBrainzMetadata {
    public let recordingId: String?
    public let artistId: String?
    public let releaseId: String?
    public let releaseGroupId: String?
    public let workId: String?
    public let trackId: String?
    
    // Additional metadata
    public let acousticId: String?
    public let albumArtistId: String?
    public let originalFormatId: String?
    public let originalYear: String?
    
    // Check if all fields are nil
    public var isEmpty: Bool {
        return recordingId == nil && artistId == nil && releaseId == nil &&
               releaseGroupId == nil && workId == nil && trackId == nil &&
               acousticId == nil && albumArtistId == nil &&
               originalFormatId == nil && originalYear == nil
    }
    
    // Empty metadata singleton for when no data is available
    static let empty = MusicBrainzMetadata(
        recordingId: nil, artistId: nil, releaseId: nil,
        releaseGroupId: nil, workId: nil, trackId: nil,
        acousticId: nil, albumArtistId: nil,
        originalFormatId: nil, originalYear: nil
    )
}

// Cache manager
class MusicBrainzCache {
    static let shared = MusicBrainzCache()
    private var cache: [UInt64: MusicBrainzMetadata] = [:]
    private var loadingTasks: [UInt64: Task<Void, Never>] = [:]
    
    private init() {}
    
    func store(_ metadata: MusicBrainzMetadata, for id: UInt64) {
        cache[id] = metadata
        // Post notification on main thread
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .musicBrainzMetadataDidUpdate, object: id)
        }
    }
    
    func metadata(for id: UInt64) -> MusicBrainzMetadata? {
        return cache[id]
    }
    
    func loadIfNeeded(_ item: MPMediaItem) {
        let id = item.persistentID
        
        // Return if already cached or loading
        if cache[id] != nil || loadingTasks[id] != nil {
            return
        }
        
        // Start new loading task
        loadingTasks[id] = Task {
            let metadata = await item.loadMusicBrainzMetadata()
            store(metadata, for: id)
            loadingTasks[id] = nil
        }
    }
}

extension Notification.Name {
    static let musicBrainzMetadataDidUpdate = Notification.Name("musicBrainzMetadataDidUpdate")
}

extension MPMediaItem {
    /// Namespace for MusicBrainz-related properties with synchronous access
    public var musicbrainz: MusicBrainzMetadata {
        // Return cached metadata if available
        if let cached = MusicBrainzCache.shared.metadata(for: persistentID) {
            return cached
        }
        
        // Start loading if needed
        MusicBrainzCache.shared.loadIfNeeded(self)
        
        return MusicBrainzMetadata.empty
    }
    
    fileprivate func loadMusicBrainzMetadata() async -> MusicBrainzMetadata {
        // Return empty metadata if no asset URL
        guard let assetURL = self.assetURL else {
            return MusicBrainzMetadata.empty
        }
        
        let asset = AVAsset(url: assetURL)
        
        do {
            let commonMetadata = try await asset.load(.metadata)
            let id3Metadata = try await asset.loadMetadata(for: .id3Metadata)
            
            var musicBrainzInfo: [String: String] = [:]
            
            // Process common metadata (M4A style)
            for item in commonMetadata {
                if let key = item.key as? String,
                   key.contains("MusicBrainz") {
                    // Handle MusicBrainz tags (e.g., "com.apple.iTunes.MusicBrainz Track Id")
                    if let value = try? await item.load(.stringValue) {
                        // Extract the actual tag name (e.g., "Track Id" from "com.apple.iTunes.MusicBrainz Track Id")
                        if let range = key.range(of: "MusicBrainz ") {
                            let cleanKey = String(key[range.upperBound...])
                            musicBrainzInfo[cleanKey] = value
                        }
                    }
                }
            }

            // Process ID3 metadata
            for item in id3Metadata {
                if (item.key as? String == "TXXX"),
                   let extras = try? await item.load(.extraAttributes),
                   let extraKey = extras[AVMetadataExtraAttributeKey.info] as? String,
                   extraKey.hasPrefix("MusicBrainz ") {
                    let cleanKey = extraKey.replacingOccurrences(of: "MusicBrainz ", with: "")
                    if let value = try? await item.load(.stringValue) {
                        musicBrainzInfo[cleanKey] = value
                    }
                }
            }
            
            for item in commonMetadata {
                do {
                    let value = try await item.load(.value)
                    if let data = value as? Data,
                       let string = String(data: data, encoding: .utf8),
                       string.contains("musicbrainz.org"),
                       let uuid = string.components(separatedBy: "\u{0000}").last {
                        musicBrainzInfo["Track Id"] = uuid
                    }
                } catch {
                    print("Failed to load metadata value: \(error.localizedDescription)")
                }
            }
            
            return MusicBrainzMetadata(
                recordingId: musicBrainzInfo["Track Id"],  // This is the recording ID in M4A files
                artistId: musicBrainzInfo["Artist Id"],
                releaseId: musicBrainzInfo["Album Id"],    // This is the release ID in M4A files
                releaseGroupId: musicBrainzInfo["Release Group Id"],
                workId: musicBrainzInfo["Work Id"],
                trackId: musicBrainzInfo["Release Track Id"],
                acousticId: musicBrainzInfo["Acoustid Id"],
                albumArtistId: musicBrainzInfo["Album Artist Id"],
                originalFormatId: musicBrainzInfo["Original Format"],
                originalYear: musicBrainzInfo["Original Year"]
            )
        } catch {
            print("Error loading MusicBrainz metadata: \(error)")
            return MusicBrainzMetadata.empty
        }
    }
} 
