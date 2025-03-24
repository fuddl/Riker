import Foundation

enum MusicBrainzError: LocalizedError {
    case badResponse(Int, String)
    case rateLimitExceeded(String)
    case serverError(Int, String)
    case networkError(Error)
    
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
        }
    }
}

class MusicBrainzClient {
    static let shared = MusicBrainzClient()
    private let baseURL = "https://musicbrainz.org/ws/2"
    private let userAgent = "Riker/1.0 (https://github.com/fuddl/Riker)"
    
    // Use rate limiter with 1 second minimum interval
    private let rateLimiter = RateLimiter(minimumRequestInterval: 1.0)
    
    private init() {}
    
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
} 
