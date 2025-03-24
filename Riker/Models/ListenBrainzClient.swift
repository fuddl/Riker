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
    private let userAgent = "Riker/1.0 (https://github.com/fuddl/Riker)"
    
    // Use rate limiter with no minimum interval (will be controlled by headers)
    private let rateLimiter = RateLimiter()
    
    struct ListenPayload: Codable {
        let listenType: String
        let payload: [Listen]
        
        enum CodingKeys: String, CodingKey {
            case listenType = "listen_type"
            case payload
        }
    }
    
    struct Listen: Codable {
        let listenedAt: Int?
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
            let releaseMbid: String?
            let artistMbids: [String]?
            let recordingMbid: String?
            
            enum CodingKeys: String, CodingKey {
                case artist = "artist_name"
                case track = "track_name"
                case album = "release_name"
                case additionalInfo = "additional_info"
                case releaseMbid = "release_mbid"
                case artistMbids = "artist_mbids"
                case recordingMbid = "recording_mbid"
            }
            
            struct AdditionalInfo: Codable {
                let albumArtist: String?
                
                enum CodingKeys: String, CodingKey {
                    case albumArtist = "album_artist"
                }
            }
        }
    }
    
    // MARK: - Release Group Popularity
    
    struct ReleaseGroupPopularity: Codable {
        let releaseGroupMbid: String
        let totalListenCount: Int
        let totalUserCount: Int
        
        enum CodingKeys: String, CodingKey {
            case releaseGroupMbid = "release_group_mbid"
            case totalListenCount = "total_listen_count"
            case totalUserCount = "total_user_count"
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
    
    private func createListen(
        from item: MPMediaItem,
        includeListenedAt: Bool = true,
        recordingMbid: String? = nil,
        releaseMbid: String? = nil,
        artistMbids: [String]? = nil
    ) -> Listen {
        Listen(
            listenedAt: includeListenedAt ? Int(Date().timeIntervalSince1970) : nil,
            trackMetadata: Listen.TrackMetadata(
                artist: item.artist ?? "Unknown Artist",
                track: item.title ?? "Unknown Track",
                album: item.albumTitle ?? "Unknown Album",
                additionalInfo: item.albumArtist.map { albumArtist in
                    Listen.TrackMetadata.AdditionalInfo(albumArtist: albumArtist)
                },
                releaseMbid: releaseMbid,
                artistMbids: artistMbids,
                recordingMbid: recordingMbid
            )
        )
    }
    
    func submitListen(
        for item: MPMediaItem,
        recordingMbid: String? = nil,
        releaseMbid: String? = nil,
        artistMbids: [String]? = nil
    ) {
        guard let token = token else {
            DispatchQueue.main.async {
                self.toastManager.show("ListenBrainz: Token not configured")
            }
            return
        }
        
        let listen = createListen(
            from: item,
            includeListenedAt: true,
            recordingMbid: recordingMbid,
            releaseMbid: releaseMbid,
            artistMbids: artistMbids
        )
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
    
    func submitPlayingNow(
        for item: MPMediaItem,
        recordingMbid: String? = nil,
        releaseMbid: String? = nil,
        artistMbids: [String]? = nil
    ) {
        guard let token = token else {
            DispatchQueue.main.async {
                self.toastManager.show("ListenBrainz: Token not configured")
            }
            return
        }
        
        let listen = createListen(
            from: item,
            includeListenedAt: false,
            recordingMbid: recordingMbid,
            releaseMbid: releaseMbid,
            artistMbids: artistMbids
        )
        let payload = ListenPayload(listenType: "playing_now", payload: [listen])
        
        var request = URLRequest(url: URL(string: "\(baseURL)/submit-listens")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            request.httpBody = try JSONEncoder().encode(payload)
        } catch {
            print("ListenBrainz: Failed to encode playing_now - \(error)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("ListenBrainz: Network error - \(error.localizedDescription)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("ListenBrainz: Invalid response type")
                return
            }
            
            if httpResponse.statusCode == 200 {
                print("ListenBrainz: Playing now submitted successfully")
            } else {
                let responseText = data.flatMap { String(data: $0, encoding: .utf8) } ?? "No response body"
                print("ListenBrainz: Server error \(httpResponse.statusCode) - \(responseText)")
            }
        }.resume()
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
    
    func getReleaseGroupListenCount(releaseGroupId: String) async throws -> Int {
        guard let token = token else {
            throw URLError(.userAuthenticationRequired)
        }
        
        let url = URL(string: "\(baseURL)/popularity/release-group")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        
        let payload = ["release_group_mbids": [releaseGroupId]]
        request.httpBody = try JSONEncoder().encode(payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard httpResponse.statusCode == 200 else {
            let responseText = String(data: data, encoding: .utf8) ?? "No response body"
            print("ListenBrainz API error \(httpResponse.statusCode): \(responseText)")
            throw URLError(.badServerResponse)
        }
        
        let popularities = try JSONDecoder().decode([ReleaseGroupPopularity].self, from: data)
        return popularities.first?.totalListenCount ?? 0
    }
    
    // Add method to handle API requests
    enum ListenBrainzError: LocalizedError {
        case badResponse(Int, String)
        case gone(String)
        case rateLimitExceeded(String)
        case serverError(Int, String)
        case networkError(Error)
        
        var errorDescription: String? {
            switch self {
            case .badResponse(let code, let message):
                return "ListenBrainz API error \(code): \(message)"
            case .gone:
                return "This ListenBrainz API endpoint is no longer available (410 Gone). The app may need to be updated."
            case .rateLimitExceeded(let message):
                return "Rate limit exceeded: \(message)"
            case .serverError(let code, let message):
                return "Server error \(code): \(message)"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            }
        }
    }
    
    private func parseErrorResponse(_ data: Data, contentType: String?) -> String {
        // If content type is HTML, extract text content
        if contentType?.contains("text/html") == true {
            if let htmlString = String(data: data, encoding: .utf8) {
                // Simple HTML stripping - could be more sophisticated if needed
                return htmlString
                    .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
                    .components(separatedBy: .whitespacesAndNewlines)
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
            }
        }
        
        // Try to parse as JSON
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? String {
            return error
        }
        
        // Fallback to raw string
        return String(data: data, encoding: .utf8) ?? "Unknown error"
    }
    
    private func makeRequest<T: Decodable>(_ endpoint: String, method: String = "GET") async throws -> T {
        let url = URL(string: "\(baseURL)\(endpoint)")!
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        try await rateLimiter.waitForNextRequest()
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ListenBrainzError.networkError(URLError(.badServerResponse))
        }
        
        // Update rate limits even for error responses
        rateLimiter.updateFromHeaders(httpResponse.allHeaderFields)
        
        switch httpResponse.statusCode {
        case 200:
            return try JSONDecoder().decode(T.self, from: data)
        
        case 410:
            let message = parseErrorResponse(data, contentType: httpResponse.value(forHTTPHeaderField: "Content-Type"))
            throw ListenBrainzError.gone(message)
        
        case 429:
            let message = parseErrorResponse(data, contentType: httpResponse.value(forHTTPHeaderField: "Content-Type"))
            throw ListenBrainzError.rateLimitExceeded(message)
        
        case 400...499:
            let message = parseErrorResponse(data, contentType: httpResponse.value(forHTTPHeaderField: "Content-Type"))
            throw ListenBrainzError.badResponse(httpResponse.statusCode, message)
        
        case 500...599:
            let message = parseErrorResponse(data, contentType: httpResponse.value(forHTTPHeaderField: "Content-Type"))
            throw ListenBrainzError.serverError(httpResponse.statusCode, message)
        
        default:
            let message = parseErrorResponse(data, contentType: httpResponse.value(forHTTPHeaderField: "Content-Type"))
            throw ListenBrainzError.badResponse(httpResponse.statusCode, message)
        }
    }
} 