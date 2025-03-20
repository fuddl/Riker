import Foundation
import MediaPlayer
import SwiftUI
import UserNotifications
import UIKit

class ListenBrainzClient: NSObject, UNUserNotificationCenterDelegate {
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
    
    private override init() {
        super.init()
        loadPendingListens()
        registerDefaults()
        
        // Set up notification delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Request regular authorization
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            print("ListenBrainz: Notification permission granted: \(granted)")
        }
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
                    // Create and show notification with album artwork
                    let content = UNMutableNotificationContent()
                    content.title = "Listen Submitted"
                    content.body = "\(item.title ?? "Unknown Track") by \(item.artist ?? "Unknown Artist")"
                    
                    // Add album artwork if available
                    if let artwork = item.artwork,
                       let image = artwork.image(at: artwork.bounds.size),
                       let attachmentURL = self.saveImageTemporarily(image: image) {
                        do {
                            let attachment = try UNNotificationAttachment(
                                identifier: UUID().uuidString,
                                url: attachmentURL,
                                options: nil
                            )
                            content.attachments = [attachment]
                        } catch {
                            print("Failed to attach artwork to notification: \(error)")
                        }
                    }
                    
                    // Create unique identifier for this notification
                    let identifier = UUID().uuidString
                    
                    // Configure notification
                    let request = UNNotificationRequest(
                        identifier: identifier,
                        content: content,
                        trigger: nil  // Show immediately
                    )
                    
                    UNUserNotificationCenter.current().add(request) { error in
                        if let error = error {
                            print("Failed to schedule notification: \(error)")
                        } else {
                            print("ListenBrainz: Notification scheduled successfully")
                            
                            // Remove the notification after 2 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
                            }
                        }
                    }
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
    
    private func saveImageTemporarily(image: UIImage) -> URL? {
        let fileManager = FileManager.default
        let tempDirectory = fileManager.temporaryDirectory
        let imageURL = tempDirectory.appendingPathComponent(UUID().uuidString + ".png")
        
        do {
            if let imageData = image.pngData() {
                try imageData.write(to: imageURL)
                return imageURL
            }
        } catch {
            print("Failed to save image temporarily: \(error)")
        }
        return nil
    }
    
    // Update the delegate method:
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification banner and play sound in foreground
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound])
        } else {
            completionHandler([.alert, .sound])
        }
    }
} 