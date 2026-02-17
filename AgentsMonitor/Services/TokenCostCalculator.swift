import Foundation

struct SessionTokenSummary {
    let inputTokens: Int
    let outputTokens: Int
    let cacheWriteTokens: Int
    let cacheReadTokens: Int
    let cost: Double
    let modelName: String
    let apiCalls: Int
}

struct TokenCostCalculator {
    private struct ModelPricing {
        let inputPerMillion: Double
        let cacheWritePerMillion: Double
        let cacheReadPerMillion: Double
        let outputPerMillion: Double
    }

    private static let pricingTable: [(prefix: String, pricing: ModelPricing)] = [
        ("claude-opus-4", ModelPricing(inputPerMillion: 15.0, cacheWritePerMillion: 18.75, cacheReadPerMillion: 1.50, outputPerMillion: 75.0)),
        ("claude-sonnet-4", ModelPricing(inputPerMillion: 3.0, cacheWritePerMillion: 3.75, cacheReadPerMillion: 0.30, outputPerMillion: 15.0)),
        ("claude-haiku-4", ModelPricing(inputPerMillion: 0.80, cacheWritePerMillion: 1.00, cacheReadPerMillion: 0.08, outputPerMillion: 4.0)),
    ]

    static func calculate(jsonlPath: String) -> SessionTokenSummary? {
        guard let content = try? String(contentsOfFile: jsonlPath, encoding: .utf8) else {
            AppLogger.logWarning("Cannot read JSONL file: \(jsonlPath)", context: "TokenCostCalculator")
            return nil
        }

        var totalInput = 0
        var totalOutput = 0
        var totalCacheWrite = 0
        var totalCacheRead = 0
        var modelCounts: [String: Int] = [:]
        var apiCalls = 0

        for line in content.split(separator: "\n") {
            guard let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                continue
            }

            guard let type = json["type"] as? String, type == "assistant" else { continue }
            guard let message = json["message"] as? [String: Any] else { continue }
            guard let usage = message["usage"] as? [String: Any] else { continue }

            apiCalls += 1

            if let input = usage["input_tokens"] as? Int {
                totalInput += input
            }
            if let output = usage["output_tokens"] as? Int {
                totalOutput += output
            }
            if let cacheWrite = usage["cache_creation_input_tokens"] as? Int {
                totalCacheWrite += cacheWrite
            }
            if let cacheRead = usage["cache_read_input_tokens"] as? Int {
                totalCacheRead += cacheRead
            }

            if let model = message["model"] as? String {
                modelCounts[model, default: 0] += 1
            }
        }

        let primaryModel = modelCounts.max(by: { $0.value < $1.value })?.key ?? ""
        let cost = calculateCost(
            model: primaryModel,
            inputTokens: totalInput,
            outputTokens: totalOutput,
            cacheWriteTokens: totalCacheWrite,
            cacheReadTokens: totalCacheRead
        )

        return SessionTokenSummary(
            inputTokens: totalInput,
            outputTokens: totalOutput,
            cacheWriteTokens: totalCacheWrite,
            cacheReadTokens: totalCacheRead,
            cost: cost,
            modelName: formatModelName(primaryModel),
            apiCalls: apiCalls
        )
    }

    private static func calculateCost(model: String, inputTokens: Int, outputTokens: Int, cacheWriteTokens: Int, cacheReadTokens: Int) -> Double {
        guard let pricing = pricingTable.first(where: { model.hasPrefix($0.prefix) })?.pricing else {
            AppLogger.logWarning("Unknown model '\(model)', falling back to Sonnet pricing", context: "TokenCostCalculator")
            let fallback = pricingTable[1].pricing
            return tokenCost(fallback, inputTokens: inputTokens, outputTokens: outputTokens, cacheWriteTokens: cacheWriteTokens, cacheReadTokens: cacheReadTokens)
        }
        return tokenCost(pricing, inputTokens: inputTokens, outputTokens: outputTokens, cacheWriteTokens: cacheWriteTokens, cacheReadTokens: cacheReadTokens)
    }

    private static func tokenCost(_ pricing: ModelPricing, inputTokens: Int, outputTokens: Int, cacheWriteTokens: Int, cacheReadTokens: Int) -> Double {
        let input = Double(inputTokens) / 1_000_000 * pricing.inputPerMillion
        let output = Double(outputTokens) / 1_000_000 * pricing.outputPerMillion
        let cacheWrite = Double(cacheWriteTokens) / 1_000_000 * pricing.cacheWritePerMillion
        let cacheRead = Double(cacheReadTokens) / 1_000_000 * pricing.cacheReadPerMillion
        return input + output + cacheWrite + cacheRead
    }

    private static func formatModelName(_ model: String) -> String {
        if model.hasPrefix("claude-opus-4") { return "Opus 4" }
        if model.hasPrefix("claude-sonnet-4") { return "Sonnet 4" }
        if model.hasPrefix("claude-haiku-4") { return "Haiku 4" }
        if model.isEmpty { return "" }
        return model
    }
}
