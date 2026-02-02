import Foundation
import SwiftTerm

actor AgentProcessManager {
    private var processes: [UUID: LocalProcess] = [:]

    struct SpawnResult {
        let process: LocalProcess
    }

    func validate(agentType: AgentType, workingDirectory: URL) throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: workingDirectory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw AgentProcessError.directoryNotAccessible(workingDirectory)
        }
    }

    func spawn(sessionId: UUID, agentType: AgentType, workingDirectory: URL, bridge: TerminalBridge) throws -> SpawnResult {
        if processes[sessionId] != nil {
            throw AgentProcessError.alreadyRunning
        }
        let executable = try resolveExecutable(for: agentType)
        try validate(agentType: agentType, workingDirectory: workingDirectory)

        let process = LocalProcess(delegate: bridge)
        bridge.attachProcess(process)
        process.startProcess(
            executable: executable,
            args: agentType.defaultArgs,
            environment: buildEnvironment(),
            execName: nil,
            currentDirectory: workingDirectory.path
        )

        guard process.running else {
            throw AgentProcessError.spawnFailed("Process failed to start")
        }
        processes[sessionId] = process

        return SpawnResult(
            process: process
        )
    }

    func terminate(sessionId: UUID) async {
        guard let process = processes[sessionId] else { return }

        process.terminate()

        try? await Task.sleep(for: .seconds(2))
        if process.running {
            kill(process.shellPid, SIGKILL)
        }

        processes.removeValue(forKey: sessionId)
    }

    func sendSignal(_ signal: Int32, to sessionId: UUID) {
        guard let process = processes[sessionId] else { return }
        kill(process.shellPid, signal)
    }

    func isRunning(_ sessionId: UUID) -> Bool {
        processes[sessionId]?.running ?? false
    }

    func processId(_ sessionId: UUID) -> Int32? {
        processes[sessionId]?.shellPid
    }

    func cleanup(sessionId: UUID) {
        processes.removeValue(forKey: sessionId)
    }

    private func resolveExecutable(for agentType: AgentType) throws -> String {
        if let resolved = agentType.resolvedExecutablePath() {
            return resolved
        }
        if let override = agentType.overrideExecutablePath, AgentType.isSandboxed {
            if agentType.overrideExecutableBookmarkData == nil {
                throw AgentProcessError.permissionRequired(override)
            }
            throw AgentProcessError.binaryNotFound(override)
        }
        let names = agentType.executableNames.joined(separator: " or ")
        throw AgentProcessError.binaryNotFound("\(agentType.displayName) (\(names))")
    }

    private func buildEnvironment() -> [String] {
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["COLORTERM"] = "truecolor"
        env["LANG"] = env["LANG"] ?? "en_US.UTF-8"
        return env.map { "\($0.key)=\($0.value)" }
    }
}

enum AgentProcessError: LocalizedError {
    case binaryNotFound(String)
    case permissionRequired(String)
    case directoryNotAccessible(URL)
    case spawnFailed(String)
    case alreadyRunning

    var errorDescription: String? {
        switch self {
        case .binaryNotFound(let path):
            return "Agent binary not found: \(path)"
        case .permissionRequired(let path):
            return "Permission required to access \(path). Use Settings → Connection → Agent Binaries → Grant Access"
        case .directoryNotAccessible(let url):
            return "Cannot access directory: \(url.path)"
        case .spawnFailed(let message):
            return "Failed to spawn process: \(message)"
        case .alreadyRunning:
            return "Process is already running"
        }
    }
}
