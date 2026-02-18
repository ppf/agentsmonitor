import Foundation

struct SessionTokenSummary: Codable {
    let inputTokens: Int
    let outputTokens: Int
    let cacheWriteTokens: Int
    let cacheReadTokens: Int
    let cost: Double
    let modelName: String
    let apiCalls: Int
}

struct CodexRateLimits {
    let primary: AnthropicUsage.UsageWindow
    let secondary: AnthropicUsage.UsageWindow
}

struct CodexCalculationResult {
    let tokenSummary: SessionTokenSummary
    let rateLimits: CodexRateLimits?
}

struct TokenCostCalculator {
    private struct ModelPricing {
        let inputPerMillion: Double
        let cacheWritePerMillion: Double
        let cacheReadPerMillion: Double
        let outputPerMillion: Double
    }

    private struct TokenTotals {
        var inputTokens: Int = 0
        var outputTokens: Int = 0
        var cacheWriteTokens: Int = 0
        var cacheReadTokens: Int = 0
    }

    private static let pricingTable: [(prefix: String, pricing: ModelPricing)] = [
        ("claude-opus-4", ModelPricing(inputPerMillion: 15.0, cacheWritePerMillion: 18.75, cacheReadPerMillion: 1.50, outputPerMillion: 75.0)),
        ("claude-sonnet-4", ModelPricing(inputPerMillion: 3.0, cacheWritePerMillion: 3.75, cacheReadPerMillion: 0.30, outputPerMillion: 15.0)),
        ("claude-haiku-4", ModelPricing(inputPerMillion: 0.80, cacheWritePerMillion: 1.00, cacheReadPerMillion: 0.08, outputPerMillion: 4.0)),
        // Order matters: longer prefixes first to avoid false hasPrefix matches
        ("gpt-5.3-codex", ModelPricing(inputPerMillion: 1.75, cacheWritePerMillion: 0, cacheReadPerMillion: 0.175, outputPerMillion: 14.0)),
        ("gpt-5.1-codex-mini", ModelPricing(inputPerMillion: 0.25, cacheWritePerMillion: 0, cacheReadPerMillion: 0.025, outputPerMillion: 2.0)),
        ("gpt-5-codex", ModelPricing(inputPerMillion: 1.25, cacheWritePerMillion: 0, cacheReadPerMillion: 0.125, outputPerMillion: 10.0)),
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
        var modelTokenTotals: [String: TokenTotals] = [:]
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
            let input = usage["input_tokens"] as? Int ?? 0
            let output = usage["output_tokens"] as? Int ?? 0
            let cacheWrite = usage["cache_creation_input_tokens"] as? Int ?? 0
            let cacheRead = usage["cache_read_input_tokens"] as? Int ?? 0
            let model = message["model"] as? String ?? ""

            totalInput += input
            totalOutput += output
            totalCacheWrite += cacheWrite
            totalCacheRead += cacheRead

            if !model.isEmpty && !model.hasPrefix("<") {
                modelCounts[model, default: 0] += 1
            }

            var totals = modelTokenTotals[model, default: TokenTotals()]
            totals.inputTokens += input
            totals.outputTokens += output
            totals.cacheWriteTokens += cacheWrite
            totals.cacheReadTokens += cacheRead
            modelTokenTotals[model] = totals
        }

        let primaryModel = modelCounts.max(by: { $0.value < $1.value })?.key ?? ""
        let cost = modelTokenTotals.reduce(into: 0.0) { partial, item in
            let model = item.key
            let totals = item.value
            partial += calculateCost(
                model: model,
                inputTokens: totals.inputTokens,
                outputTokens: totals.outputTokens,
                cacheWriteTokens: totals.cacheWriteTokens,
                cacheReadTokens: totals.cacheReadTokens
            )
        }

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

    static func calculateCodex(jsonlPath: String) -> CodexCalculationResult? {
        guard let content = try? String(contentsOfFile: jsonlPath, encoding: .utf8) else {
            AppLogger.logWarning("Cannot read JSONL file: \(jsonlPath)", context: "TokenCostCalculator")
            return nil
        }

        var model = ""
        var apiCalls = 0
        var lastInput = 0
        var lastCached = 0
        var lastOutput = 0
        var foundTokens = false
        var lastRateLimits: [String: Any]?

        for line in content.split(separator: "\n") {
            guard let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let type = json["type"] as? String else { continue }

            guard let payload = json["payload"] as? [String: Any] else { continue }

            switch type {
            case "turn_context":
                apiCalls += 1
                if model.isEmpty, let m = payload["model"] as? String {
                    model = m
                }

            case "event_msg":
                guard let eventType = payload["type"] as? String, eventType == "token_count" else { continue }

                if let rateLimits = payload["rate_limits"] as? [String: Any] {
                    lastRateLimits = rateLimits
                }

                guard let info = payload["info"] as? [String: Any],
                      let usage = info["total_token_usage"] as? [String: Any] else { continue }

                lastInput = usage["input_tokens"] as? Int ?? 0
                lastCached = usage["cached_input_tokens"] as? Int ?? 0
                lastOutput = usage["output_tokens"] as? Int ?? 0
                foundTokens = true

            default:
                break
            }
        }

        guard foundTokens else { return nil }

        let uncachedInput = max(lastInput - lastCached, 0)
        let cost = calculateCost(
            model: model,
            inputTokens: uncachedInput,
            outputTokens: lastOutput,
            cacheWriteTokens: 0,
            cacheReadTokens: lastCached
        )

        let summary = SessionTokenSummary(
            inputTokens: uncachedInput,
            outputTokens: lastOutput,
            cacheWriteTokens: 0,
            cacheReadTokens: lastCached,
            cost: cost,
            modelName: formatModelName(model),
            apiCalls: apiCalls
        )

        let rateLimits = parseCodexRateLimits(lastRateLimits)

        return CodexCalculationResult(tokenSummary: summary, rateLimits: rateLimits)
    }

    private static func parseCodexRateLimits(_ json: [String: Any]?) -> CodexRateLimits? {
        guard let json else { return nil }
        guard let primary = json["primary"] as? [String: Any],
              let secondary = json["secondary"] as? [String: Any] else { return nil }

        func parseWindow(_ window: [String: Any]) -> AnthropicUsage.UsageWindow {
            let usedPercent: Double
            if let number = window["used_percent"] as? NSNumber {
                usedPercent = number.doubleValue
            } else {
                if window["used_percent"] != nil {
                    AppLogger.logWarning("used_percent has unexpected type: \(type(of: window["used_percent"]!))", context: "TokenCostCalculator")
                }
                usedPercent = 0
            }
            let utilization = usedPercent / 100.0
            var resetsAt: String?
            if let ts = window["resets_at"] as? Int {
                let date = Date(timeIntervalSince1970: TimeInterval(ts))
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime]
                resetsAt = formatter.string(from: date)
            }
            return AnthropicUsage.UsageWindow(utilization: utilization, resetsAt: resetsAt)
        }

        return CodexRateLimits(primary: parseWindow(primary), secondary: parseWindow(secondary))
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
        if model.hasPrefix("gpt-5.3-codex") { return "GPT-5.3 Codex" }
        if model.hasPrefix("gpt-5.1-codex-mini") { return "GPT-5.1 Mini" }
        if model.hasPrefix("gpt-5-codex") { return "GPT-5 Codex" }
        if model.isEmpty || model.hasPrefix("<") { return "" }
        return model
    }
}
