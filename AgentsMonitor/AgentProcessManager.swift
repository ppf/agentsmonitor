import Foundation
import SwiftTerm
import Darwin

/// Manages spawning, tracking, and lifecycle of agent processes
actor AgentProcessManager {
    private var processes: [UUID: ProcessInfo] = [:]
    
    struct ProcessInfo {
        let process: LocalProcess
        let agentType: AgentType
        let workingDirectory: URL
        var startTime: Date
    }
    
    struct SpawnResult {
        let process: LocalProcess
        let sessionId: UUID
    }
    
    // MARK: - Spawn Process
    
    func spawn(
        sessionId: UUID,
        agentType: AgentType,
        workingDirectory: URL,
        bridge: TerminalBridge
    ) async throws -> SpawnResult {
        // Get the executable path
        guard let executablePath = agentType.resolvedExecutablePath() else {
            throw ProcessError.executableNotFound(agentType: agentType)
        }
        
        // Prepare environment
        var environment = ProcessInfo.processInfo.environment
        environment["TERM"] = "xterm-256color"
        environment["LANG"] = "en_US.UTF-8"
        
        // Get default args for the agent type
        let args = agentType.defaultArgs
        
        // Create and configure the process
        let process = try LocalProcess(
            executable: executablePath,
            args: args,
            environment: environment.map { "\($0.key)=\($0.value)" },
            currentDirectory: workingDirectory.path
        )
        
        // Connect the bridge
        bridge.attachProcess(process)
        process.processDelegate = bridge
        
        // Track the process
        let info = ProcessInfo(
            process: process,
            agentType: agentType,
            workingDirectory: workingDirectory,
            startTime: Date()
        )
        processes[sessionId] = info
        
        return SpawnResult(process: process, sessionId: sessionId)
    }
    
    // MARK: - Process Control
    
    func terminate(sessionId: UUID) async {
        guard let info = processes[sessionId] else { return }
        
        // Send SIGTERM first for graceful shutdown
        info.process.send(signal: SIGTERM)
        
        // Wait a bit
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Force kill if still running
        if info.process.running {
            info.process.send(signal: SIGKILL)
        }
        
        processes.removeValue(forKey: sessionId)
    }
    
    func sendSignal(_ signal: Int32, to sessionId: UUID) async {
        guard let info = processes[sessionId] else { return }
        info.process.send(signal: signal)
    }
    
    func cleanup(sessionId: UUID) async {
        processes.removeValue(forKey: sessionId)
    }
    
    // MARK: - Process Queries
    
    func isRunning(sessionId: UUID) async -> Bool {
        guard let info = processes[sessionId] else { return false }
        return info.process.running
    }
    
    func getProcessInfo(sessionId: UUID) async -> ProcessInfo? {
        return processes[sessionId]
    }
    
    func getAllProcesses() async -> [UUID: ProcessInfo] {
        return processes
    }
}

// MARK: - Process Errors

enum ProcessError: LocalizedError {
    case executableNotFound(agentType: AgentType)
    case spawnFailed(reason: String)
    case processNotFound(sessionId: UUID)
    
    var errorDescription: String? {
        switch self {
        case .executableNotFound(let agentType):
            return "Executable not found for \(agentType.displayName). Please configure the path in settings."
        case .spawnFailed(let reason):
            return "Failed to spawn process: \(reason)"
        case .processNotFound(let sessionId):
            return "Process not found for session \(sessionId)"
        }
    }
}
