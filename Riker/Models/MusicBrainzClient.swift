import Foundation

enum MusicBrainzError: LocalizedError {
    case badResponse(Int, String)
    case rateLimitExceeded(String)
    case serverError(Int, String)
    case networkError(Error)
    case invalidURL
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .badResponse(let code, let message):
            return "MusicBrainz API error \(code): \(message)"
        case .rateLimitExceeded(let message):
            return "Rate limit exceeded: \(message)"
        case .serverError(let code, let message):
            return "Server error \(code): \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        }
    }
}

class MusicBrainzClient {
    static let shared = MusicBrainzClient()
    private let baseURL = "https://musicbrainz.org/ws/2"
    private let userAgent = "Riker/1.0 (https://github.com/fuddl/Riker)"
    private let userDefaults = UserDefaults.standard
    private let sessionKey = "musicbrainz_session"
    
    // Use rate limiter with 1 second minimum interval
    private let rateLimiter = RateLimiter(minimumRequestInterval: 1.0)
    
    // Replace NSCache with disk cache
    private let cache = NSCache<NSString, NSData>()
    private let fileManager = FileManager.default
    
    private var cacheDirectory: URL? {
        return fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("MusicBrainzCache")
    }
    
    private init() {
        // Create cache directory if it doesn't exist
        if let cacheDir = cacheDirectory {
            try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - Session Management
    
    func getSession() -> String? {
        let session = userDefaults.string(forKey: sessionKey)
        print("MusicBrainzClient: Getting session: \(session != nil ? "Found" : "Not found")")
        return session
    }
    
    func setSession(_ session: String) {
        print("MusicBrainzClient: Setting session")
        userDefaults.set(session, forKey: sessionKey)
        userDefaults.synchronize() // Force immediate write
    }
    
    func clearSession() {
        print("MusicBrainzClient: Clearing session")
        userDefaults.removeObject(forKey: sessionKey)
        userDefaults.synchronize() // Force immediate write
    }
    
    // MARK: - Rating Submission
    
    func submitRating(releaseGroupId: String, rating: Int, session: String) async throws {
        print("MusicBrainzClient: Submitting rating \(rating) for release group \(releaseGroupId)")
        
        guard let url = URL(string: "\(baseURL)/rating?client=Riker-1.0") else {
            throw MusicBrainzError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        // Add the session cookie
        let cookieString = "musicbrainz_server_session=\(session)"
        request.setValue(cookieString, forHTTPHeaderField: "Cookie")
        print("MusicBrainzClient: Added session cookie to request: \(cookieString)")
        
        // Create XML payload
        let xmlString = """
        <?xml version="1.0" encoding="UTF-8"?>
        <metadata xmlns="http://musicbrainz.org/ns/mmd-2.0#">
            <release-group-list>
                <release-group id="\(releaseGroupId)">
                    <user-rating>\(rating * 20)</user-rating>
                </release-group>
            </release-group-list>
        </metadata>
        """
        
        request.httpBody = xmlString.data(using: .utf8)
        
        print("MusicBrainzClient: Sending rating request")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MusicBrainzError.invalidResponse
        }
        
        print("MusicBrainzClient: Response status code: \(httpResponse.statusCode)")
        
        switch httpResponse.statusCode {
        case 200, 201:
            print("MusicBrainzClient: Rating submitted successfully")
            return
        case 401:
            print("MusicBrainzClient: Unauthorized (401)")
            throw MusicBrainzError.badResponse(401, "Session expired")
        case 404:
            print("MusicBrainzClient: Not Found (404)")
            throw MusicBrainzError.badResponse(404, "Release group not found")
        default:
            print("MusicBrainzClient: Unexpected status code: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("MusicBrainzClient: Response body: \(responseString)")
            }
            throw MusicBrainzError.badResponse(httpResponse.statusCode, "Unexpected response")
        }
    }
    
    // MARK: - Release Group
    
    struct ReleaseGroup: Codable {
        let id: String
        let title: String?
        let firstReleaseDate: String?
        let type: String?
        let releases: [Release]?
        let artistCredit: [ArtistCredit]?
        let tags: [Tag]?
        let rating: Rating?
        let genres: [Genre]?
        
        enum CodingKeys: String, CodingKey {
            case id
            case title
            case firstReleaseDate = "first-release-date"
            case type
            case releases
            case artistCredit = "artist-credit"
            case tags
            case rating
            case genres
        }
    }
    
    struct Release: Codable {
        let id: String
        let title: String?
        let date: String?
        let country: String?
        let status: String?
        let media: [Media]?
        let artistCredit: [ArtistCredit]?
        let labelInfo: [LabelInfo]?
        
        enum CodingKeys: String, CodingKey {
            case id
            case title
            case date
            case country
            case status
            case media
            case artistCredit = "artist-credit"
            case labelInfo = "label-info"
        }
    }
    
    struct Media: Codable {
        let format: String?
        let trackCount: Int?
        let tracks: [Track]?
        
        enum CodingKeys: String, CodingKey {
            case format
            case trackCount = "track-count"
            case tracks
        }
    }
    
    struct Track: Codable {
        let id: String
        let number: String
        let title: String
        let length: Int?
        let recording: Recording?
        
        enum CodingKeys: String, CodingKey {
            case id
            case number
            case title
            case length
            case recording
        }
    }
    
    struct Recording: Codable {
        let id: String
        let title: String
        let length: Int?
        let artistCredit: [ArtistCredit]?
        
        enum CodingKeys: String, CodingKey {
            case id
            case title
            case length
            case artistCredit = "artist-credit"
        }
    }
    
    struct ArtistCredit: Codable {
        let name: String
        let joinPhrase: String?
        
        enum CodingKeys: String, CodingKey {
            case name
            case joinPhrase = "joinphrase"
        }
    }
    
    struct LabelInfo: Codable {
        let label: Label?
        let catalogNumber: String?
        
        enum CodingKeys: String, CodingKey {
            case label
            case catalogNumber = "catalog-number"
        }
    }
    
    struct Label: Codable {
        let id: String
        let name: String
    }
    
    struct Tag: Codable {
        let name: String
        let count: Int
    }
    
    struct Rating: Codable {
        let value: Double?
        let votesCount: Int?
        
        enum CodingKeys: String, CodingKey {
            case value
            case votesCount = "votes-count"
        }
    }
    
    struct Genre: Codable {
        let name: String
        let count: Int
    }
    
    // MARK: - API Methods
    
    private func makeRequest<T: Decodable>(_ endpoint: String) async throws -> T {
        // Generate cache file path
        let cacheKey = endpoint.data(using: .utf8)!.sha256Hash
        let cacheFile = cacheDirectory?.appendingPathComponent(cacheKey)
        
        // Check disk cache first
        if let cacheFile = cacheFile,
           let data = try? Data(contentsOf: cacheFile) {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        }
        
        let url = URL(string: "\(baseURL)\(endpoint)")!
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        try await rateLimiter.waitForNextRequest()
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MusicBrainzError.networkError(URLError(.badServerResponse))
        }
        
        let responseText = String(data: data, encoding: .utf8) ?? "No response body"
        
        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            // Save to disk cache
            if let cacheFile = cacheFile {
                try? data.write(to: cacheFile)
            }
            return try decoder.decode(T.self, from: data)
            
        case 503:
            // When we hit rate limit, increase the wait time
            rateLimiter.backoff()
            throw MusicBrainzError.rateLimitExceeded(responseText)
            
        case 400...499:
            throw MusicBrainzError.badResponse(httpResponse.statusCode, responseText)
            
        case 500...599:
            throw MusicBrainzError.serverError(httpResponse.statusCode, responseText)
            
        default:
            throw MusicBrainzError.badResponse(httpResponse.statusCode, responseText)
        }
    }
    
    func fetchReleaseGroup(id: String) async throws -> ReleaseGroup {
        return try await makeRequest("/release-group/\(id)?inc=releases+artist-credits+tags+ratings+genres")
    }
    
    func fetchRelease(id: String) async throws -> Release {
        return try await makeRequest("/release/\(id)?inc=artist-credits+labels+recordings")
    }
    
    func clearCache(releaseGroupId: String, releaseId: String) {
        let releaseGroupEndpoint = "/release-group/\(releaseGroupId)?inc=releases+artist-credits+tags+ratings+genres"
        let releaseEndpoint = "/release/\(releaseId)?inc=artist-credits+labels+recordings"
        
        // Clear disk cache
        let releaseGroupKey = releaseGroupEndpoint.data(using: .utf8)!.sha256Hash
        let releaseKey = releaseEndpoint.data(using: .utf8)!.sha256Hash
        
        if let cacheDir = cacheDirectory {
            try? fileManager.removeItem(at: cacheDir.appendingPathComponent(releaseGroupKey))
            try? fileManager.removeItem(at: cacheDir.appendingPathComponent(releaseKey))
        }
    }
} 
