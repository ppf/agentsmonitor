import Foundation

struct SessionMetrics: Codable, Hashable {
    var tokenCount: Int = 0
    var toolCallCount: Int = 0
    var apiCalls: Int = 0
    var errorCount: Int = 0
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var cacheReadTokens: Int = 0
    var cacheWriteTokens: Int = 0
    
    var totalTokens: Int {
        inputTokens + outputTokens
    }
    
    var formattedTokens: String {
        let total = totalTokens
        if total >= 1_000_000 {
            return String(format: "%.1fM", Double(total) / 1_000_000)
        } else if total >= 1_000 {
            return String(format: "%.1fK", Double(total) / 1_000)
        } else {
            return "\(total)"
        }
    }
}
