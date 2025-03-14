import Foundation
import MediaPlayer
import SwiftUI

class ListenBrainzClient {
    static let shared = ListenBrainzClient()
    private let baseURL = "https://api.listenbrainz.org/1"
    private let userDefaults = UserDefaults.standard
    private var pendingListens: [Listen] = []
    private let toastManager = ToastManager.shared
    
    struct ListenPayload: Codable {
        let listenType: String
        let payload: [Listen]
        
        enum CodingKeys: String, CodingKey {
            case listenType = "listen_type"
            case payload
        }
    }
    
    struct Listen: Codable {
        let listenedAt: Int
        let trackMetadata: TrackMetadata
        
        enum CodingKeys: String, CodingKey {
            case listenedAt = "listened_at"
            case trackMetadata = "track_metadata"
        }
        
        struct TrackMetadata: Codable {
            let artist: String
            let track: String
            let album: String
            let additionalInfo: AdditionalInfo?
            
            enum CodingKeys: String, CodingKey {
                case artist = "artist_name"
                case track = "track_name"
                case album = "release_name"
                case additionalInfo = "additional_info"
            }
            
            struct AdditionalInfo: Codable {
                let albumArtist: String?
                
                enum CodingKeys: String, CodingKey {
                    case albumArtist = "album_artist"
                }
            }
        }
    }
    
    var token: String? {
        get { UserDefaults.standard.string(forKey: "listenbrainz_token") }
        set { UserDefaults.standard.set(newValue, forKey: "listenbrainz_token") }
    }
    
    private init() {
        loadPendingListens()
        registerDefaults()
    }
    
    private func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            "listenbrainz_token": ""
        ])
    }
    
    func submitListen(for item: MPMediaItem) {
        guard let token = token else {
            DispatchQueue.main.async {
                self.toastManager.show("ListenBrainz: Token not configured")
            }
            return
        }
        
        let listen = createListen(from: item)
        let payload = ListenPayload(listenType: "single", payload: [listen])
        
        var request = URLRequest(url: URL(string: "\(baseURL)/submit-listens")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            request.httpBody = try JSONEncoder().encode(payload)
        } catch {
            print("ListenBrainz: Failed to encode listen - \(error)")
            queueListen(listen)
            DispatchQueue.main.async {
                self.toastManager.show("Listen queued for later submission")
            }
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("ListenBrainz: Network error - \(error.localizedDescription)")
                self.queueListen(listen)
                DispatchQueue.main.async {
                    self.toastManager.show("Listen queued: Network error")
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("ListenBrainz: Invalid response type")
                self.queueListen(listen)
                DispatchQueue.main.async {
                    self.toastManager.show("Listen queued: Invalid response")
                }
                return
            }
            
            if httpResponse.statusCode == 200 {
                print("ListenBrainz: Listen submitted successfully")
                DispatchQueue.main.async {
                    self.toastManager.show("Listen submitted to ListenBrainz")
                }
            } else {
                let responseText = data.flatMap { String(data: $0, encoding: .utf8) } ?? "No response body"
                print("ListenBrainz: Server error \(httpResponse.statusCode) - \(responseText)")
                self.queueListen(listen)
                DispatchQueue.main.async {
                    self.toastManager.show("Listen queued: Server error")
                }
            }
        }.resume()
    }
    
    private func createListen(from item: MPMediaItem) -> Listen {
        Listen(
            listenedAt: Int(Date().timeIntervalSince1970),
            trackMetadata: Listen.TrackMetadata(
                artist: item.artist ?? "Unknown Artist",
                track: item.title ?? "Unknown Track",
                album: item.albumTitle ?? "Unknown Album",
                additionalInfo: item.albumArtist.map { albumArtist in
                    Listen.TrackMetadata.AdditionalInfo(albumArtist: albumArtist)
                }
            )
        )
    }
    
    private func queueListen(_ listen: Listen) {
        pendingListens.append(listen)
        savePendingListens()
    }
    
    private func loadPendingListens() {
        if let data = userDefaults.data(forKey: "pending_listens"),
           let listens = try? JSONDecoder().decode([Listen].self, from: data) {
            pendingListens = listens
        }
    }
    
    private func savePendingListens() {
        if let data = try? JSONEncoder().encode(pendingListens) {
            userDefaults.set(data, forKey: "pending_listens")
        }
    }
    
    func submitPendingListens() {
        guard !pendingListens.isEmpty else {
            print("ListenBrainz: No pending listens to submit")
            return
        }
        
        guard let token = token else {
            DispatchQueue.main.async {
                self.toastManager.show("ListenBrainz: Token not configured")
            }
            return
        }
        
        let payload = ListenPayload(listenType: "import", payload: pendingListens)
        var request = URLRequest(url: URL(string: "\(baseURL)/submit-listens")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            request.httpBody = try JSONEncoder().encode(payload)
        } catch {
            print("ListenBrainz: Failed to encode pending listens - \(error)")
            DispatchQueue.main.async {
                self.toastManager.show("Failed to submit pending listens")
            }
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("ListenBrainz: Network error while submitting pending - \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.toastManager.show("Failed to submit pending listens: Network error")
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("ListenBrainz: Invalid response type for pending submission")
                DispatchQueue.main.async {
                    self.toastManager.show("Failed to submit pending listens: Invalid response")
                }
                return
            }
            
            if httpResponse.statusCode == 200 {
                print("ListenBrainz: Pending listens submitted successfully")
                self.pendingListens.removeAll()
                self.savePendingListens()
                DispatchQueue.main.async {
                    self.toastManager.show("Pending listens submitted successfully")
                }
            } else {
                let responseText = data.flatMap { String(data: $0, encoding: .utf8) } ?? "No response body"
                print("ListenBrainz: Server error \(httpResponse.statusCode) while submitting pending - \(responseText)")
                DispatchQueue.main.async {
                    self.toastManager.show("Failed to submit pending listens: Server error")
                }
            }
        }.resume()
    }
} 