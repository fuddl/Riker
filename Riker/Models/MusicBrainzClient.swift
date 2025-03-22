import Foundation

class MusicBrainzClient {
    static let shared = MusicBrainzClient()
    private let baseURL = "https://musicbrainz.org/ws/2"
    private let userAgent = "Riker/1.0 (https://github.com/yourusername/riker)"
    
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
    
    func fetchReleaseGroup(id: String) async throws -> ReleaseGroup {
        let url = URL(string: "\(baseURL)/release-group/\(id)?inc=releases+artist-credits+tags+ratings+genres")!
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard httpResponse.statusCode == 200 else {
            let responseText = String(data: data, encoding: .utf8) ?? "No response body"
            print("MusicBrainz API error \(httpResponse.statusCode): \(responseText)")
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(ReleaseGroup.self, from: data)
    }
    
    func fetchRelease(id: String) async throws -> Release {
        let url = URL(string: "\(baseURL)/release/\(id)?inc=artist-credits+labels+recordings")!
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard httpResponse.statusCode == 200 else {
            let responseText = String(data: data, encoding: .utf8) ?? "No response body"
            print("MusicBrainz API error \(httpResponse.statusCode): \(responseText)")
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(Release.self, from: data)
    }
} 
