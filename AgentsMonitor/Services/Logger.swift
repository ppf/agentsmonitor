import Foundation
import os.log

/// Centralized logging for the AgentsMonitor app
final class AppLogger {
    static let subsystem = Bundle.main.bundleIdentifier ?? "com.agentsmonitor.app"

    // MARK: - Log Categories

    private static let sessionLog = OSLog(subsystem: subsystem, category: "sessions")
    private static let networkLog = OSLog(subsystem: subsystem, category: "network")
    private static let persistenceLog = OSLog(subsystem: subsystem, category: "persistence")
    private static let errorLog = OSLog(subsystem: subsystem, category: "errors")
    private static let performanceLog = OSLog(subsystem: subsystem, category: "performance")

    // MARK: - Session Events

    static func logSessionCreated(_ session: Session) {
        os_log("Session created: %{public}@ (%{public}@)",
               log: sessionLog,
               type: .info,
               session.name,
               session.id.uuidString)
    }

    static func logSessionStatusChanged(_ session: Session, from oldStatus: SessionStatus) {
        os_log("Session %{public}@ status changed: %{public}@ → %{public}@",
               log: sessionLog,
               type: .info,
               session.id.uuidString,
               oldStatus.rawValue,
               session.status.rawValue)
    }

    static func logSessionDeleted(_ sessionId: UUID) {
        os_log("Session deleted: %{public}@",
               log: sessionLog,
               type: .info,
               sessionId.uuidString)
    }

    // MARK: - Tool Call Events

    static func logToolCallStarted(_ toolCall: ToolCall, sessionId: UUID) {
        os_log("Tool call started: %{public}@ in session %{public}@",
               log: sessionLog,
               type: .debug,
               toolCall.name,
               sessionId.uuidString)
    }

    static func logToolCallCompleted(_ toolCall: ToolCall, sessionId: UUID) {
        os_log("Tool call completed: %{public}@ (%{public}@) in session %{public}@",
               log: sessionLog,
               type: .debug,
               toolCall.name,
               toolCall.formattedDuration,
               sessionId.uuidString)
    }

    // MARK: - Network Events

    static func logConnectionAttempt(host: String, port: String) {
        os_log("Attempting connection to %{public}@:%{public}@",
               log: networkLog,
               type: .info,
               host, port)
    }

    static func logConnectionSuccess() {
        os_log("WebSocket connection established",
               log: networkLog,
               type: .info)
    }

    static func logConnectionFailed(_ error: Error) {
        os_log("WebSocket connection failed: %{public}@",
               log: networkLog,
               type: .error,
               error.localizedDescription)
    }

    static func logDisconnection(reason: String?) {
        os_log("WebSocket disconnected: %{public}@",
               log: networkLog,
               type: .info,
               reason ?? "unknown reason")
    }

    // MARK: - Persistence Events

    static func logPersistenceLoaded(count: Int) {
        os_log("Loaded %{public}d sessions from disk",
               log: persistenceLog,
               type: .info,
               count)
    }

    static func logPersistenceSaved(_ sessionId: UUID) {
        os_log("Saved session %{public}@ to disk",
               log: persistenceLog,
               type: .debug,
               sessionId.uuidString)
    }

    static func logPersistenceDeleted(_ sessionId: UUID) {
        os_log("Deleted session %{public}@ from disk",
               log: persistenceLog,
               type: .debug,
               sessionId.uuidString)
    }

    static func logPersistenceError(_ error: Error, context: String) {
        os_log("Persistence error in %{public}@: %{public}@",
               log: persistenceLog,
               type: .error,
               context,
               error.localizedDescription)
    }

    // MARK: - Error Logging

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
               log: errorLog,
               type: .default,
               context,
               message)
    }

    // MARK: - Performance Logging

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
