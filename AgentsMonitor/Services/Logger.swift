import Foundation
import os.log

/// Centralized logging for the AgentsMonitor app
final class AppLogger {
    static let subsystem = Bundle.main.bundleIdentifier ?? "com.agentsmonitor.app"

    private static let errorLog = OSLog(subsystem: subsystem, category: "errors")
    private static let warningLog = OSLog(subsystem: subsystem, category: "warnings")
    private static let performanceLog = OSLog(subsystem: subsystem, category: "performance")

    static func logError(_ error: Error, context: String, file: String = #file, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        os_log("Error in %{public}@:%{public}d [%{public}@]: %{public}@",
               log: errorLog,
               type: .error,
               fileName,
               line,
               context,
               error.localizedDescription)
    }

    static func logWarning(_ message: String, context: String) {
        os_log("Warning [%{public}@]: %{public}@",
               log: warningLog,
               type: .default,
               context,
               message)
    }

    static func logPerformance(_ operation: String, duration: TimeInterval) {
        os_log("Performance [%{public}@]: %.3f ms",
               log: performanceLog,
               type: .debug,
               operation,
               duration * 1000)
    }

    static func measure<T>(_ operation: String, block: () throws -> T) rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let duration = CFAbsoluteTimeGetCurrent() - start
        logPerformance(operation, duration: duration)
        return result
    }

    static func measureAsync<T>(_ operation: String, block: () async throws -> T) async rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = try await block()
        let duration = CFAbsoluteTimeGetCurrent() - start
        logPerformance(operation, duration: duration)
        return result
    }
}
