import Foundation

class RateLimiter {
    private var lastRequestTime: Date?
    private var remainingRequests: Int?
    private var resetTime: Date?
    private var currentInterval: TimeInterval
    private let minimumRequestInterval: TimeInterval
    private let maxInterval: TimeInterval = 8.0 // Maximum backoff of 8 seconds
    
    init(minimumRequestInterval: TimeInterval = 0) {
        self.minimumRequestInterval = minimumRequestInterval
        self.currentInterval = minimumRequestInterval
    }
    
    func backoff() {
        // Double the current interval, but don't exceed maxInterval
        currentInterval = min(currentInterval * 2, maxInterval)
    }
    
    func resetBackoff() {
        currentInterval = minimumRequestInterval
    }
    
    func waitForNextRequest() async throws {
        if let lastRequest = lastRequestTime {
            let timeSinceLastRequest = Date().timeIntervalSince(lastRequest)
            if timeSinceLastRequest < currentInterval {
                let waitTime = currentInterval - timeSinceLastRequest
                try await Task.sleep(for: .seconds(waitTime))
            }
        }
        
        // Check rate limit quota
        if let remaining = remainingRequests, let reset = resetTime {
            if remaining <= 0 && Date() < reset {
                let waitTime = reset.timeIntervalSinceNow
                try await Task.sleep(for: .seconds(waitTime))
            }
        }
        
        lastRequestTime = Date()
        
        // If we successfully made it here, we can try reducing the interval
        if currentInterval > minimumRequestInterval {
            currentInterval = max(currentInterval * 0.5, minimumRequestInterval)
        }
    }
    
    func updateFromHeaders(_ headers: [AnyHashable: Any]) {
        if let limitRemaining = headers["X-RateLimit-Remaining"] as? String {
            remainingRequests = Int(limitRemaining)
        }
        
        if let resetIn = headers["X-RateLimit-Reset-In"] as? String,
           let seconds = Double(resetIn) {
            resetTime = Date().addingTimeInterval(seconds)
        }
    }
} 
