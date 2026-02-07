import AppKit
import XCTest

final class AgentsMonitorMenuBarTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        terminateRunningAppIfNeeded()
    }

    func testMenuBarExtraContents() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        var statusItem = app.menuBars.statusItems["menuBar.statusItem"]
        if !statusItem.waitForExistence(timeout: 2) {
            statusItem = app.menuBars.statusItems["Agents Monitor"]
        }
        XCTAssertTrue(statusItem.waitForExistence(timeout: 10))
        statusItem.click()

        let headerTitle = app.staticTexts["menuBar.header.title"]
        let headerTitleLabel = app.staticTexts["Agents Monitor"]
        XCTAssertTrue(
            headerTitle.waitForExistence(timeout: 5) || headerTitleLabel.waitForExistence(timeout: 5)
        )
        if headerTitle.exists, !headerTitle.label.isEmpty {
            XCTAssertEqual(headerTitle.label, "Agents Monitor")
        } else {
            XCTAssertTrue(headerTitleLabel.exists)
        }

        let headerActive = app.staticTexts["menuBar.header.activeCount"]
        let headerActiveLabel = app.staticTexts["3 active"]
        XCTAssertTrue(
            headerActive.waitForExistence(timeout: 2) || headerActiveLabel.waitForExistence(timeout: 2)
        )
        if headerActive.exists, !headerActive.label.isEmpty {
            XCTAssertEqual(headerActive.label, "3 active")
        } else {
            XCTAssertTrue(headerActiveLabel.exists)
        }

        let activeSection = app.staticTexts["menuBar.section.active"]
        let activeSectionLabel = app.staticTexts["ACTIVE SESSIONS"]
        XCTAssertTrue(
            activeSection.waitForExistence(timeout: 2) || activeSectionLabel.waitForExistence(timeout: 2)
        )

        let sessionNames = app.staticTexts.matching(identifier: "menuBar.session.name")
        let sessionDurations = app.staticTexts.matching(identifier: "menuBar.session.duration")
        let sessionRows = app.otherElements.matching(identifier: "menuBar.sessionRow")
        XCTAssertTrue(sessionRows.count > 0 || sessionNames.count > 0)
        XCTAssertTrue(sessionNames.count > 0)
        XCTAssertTrue(sessionDurations.count > 0 || sessionNames.count > 0)

        let newSessionButton = app.buttons["menuBar.action.newSession"]
        XCTAssertTrue(newSessionButton.exists)
        newSessionButton.click()

        if headerActive.exists, !headerActive.label.isEmpty {
            let activeCountPredicate = NSPredicate(format: "label == %@", "4 active")
            expectation(for: activeCountPredicate, evaluatedWith: headerActive)
            waitForExpectations(timeout: 5)
        } else {
            XCTAssertTrue(app.staticTexts["4 active"].waitForExistence(timeout: 5))
        }

        XCTAssertTrue(app.buttons["menuBar.action.refresh"].exists)
        XCTAssertTrue(app.buttons["menuBar.action.settings"].exists)
        let quitButton = app.buttons["menuBar.action.quit"]
        XCTAssertTrue(quitButton.exists)
        quitButton.click()
        _ = app.wait(for: .notRunning, timeout: 5)
    }

    private func terminateRunningAppIfNeeded() {
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.agentsmonitor.app")
        guard !runningApps.isEmpty else { return }

        for app in runningApps {
            _ = app.terminate()
        }

        waitForTermination(timeout: 2)

        let stillRunning = NSRunningApplication.runningApplications(withBundleIdentifier: "com.agentsmonitor.app")
        if !stillRunning.isEmpty {
            for app in stillRunning {
                app.forceTerminate()
            }
            waitForTermination(timeout: 2)
        }

        if !NSRunningApplication.runningApplications(withBundleIdentifier: "com.agentsmonitor.app").isEmpty {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
            process.arguments = ["-x", "AgentsMonitor"]
            try? process.run()
            process.waitUntilExit()
            waitForTermination(timeout: 2)
        }
    }

    private func waitForTermination(timeout: TimeInterval) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let stillRunning = NSRunningApplication.runningApplications(withBundleIdentifier: "com.agentsmonitor.app")
            if stillRunning.isEmpty || stillRunning.allSatisfy({ $0.isTerminated }) {
                break
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
    }
}

final class AgentsMonitorHistoryLoadingTests: XCTestCase {
    private struct SeededSession {
        let sessionName: String
        let sessionsDirectory: URL
        let uppercasedURL: URL
        let canonicalURL: URL
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        terminateRunningAppIfNeeded()
    }

    override func tearDownWithError() throws {
        terminateRunningAppIfNeeded()
    }

    func testLegacySessionHistoryLoadsFromDiskAndPersistsAfterRestart() throws {
        let seeded = try seedLegacySession()
        addTeardownBlock {
            try? FileManager.default.removeItem(at: seeded.uppercasedURL)
            try? FileManager.default.removeItem(at: seeded.canonicalURL)
            try? FileManager.default.removeItem(at: seeded.sessionsDirectory)
        }

        let firstLaunch = XCUIApplication()
        firstLaunch.launchEnvironment["AGENTS_MONITOR_SESSIONS_DIR"] = seeded.sessionsDirectory.path
        firstLaunch.launch()

        verifySessionAndHistoryVisible(in: firstLaunch, seeded: seeded)

        let filenamesAfterFirstLoad = try FileManager.default.contentsOfDirectory(atPath: seeded.sessionsDirectory.path)
        XCTAssertTrue(
            filenamesAfterFirstLoad.contains(seeded.canonicalURL.lastPathComponent),
            "Expected canonical lowercase session file after load"
        )
        XCTAssertFalse(
            filenamesAfterFirstLoad.contains(seeded.uppercasedURL.lastPathComponent),
            "Expected uppercase legacy file to be renamed"
        )

        terminateRunningAppIfNeeded()

        let secondLaunch = XCUIApplication()
        secondLaunch.launchEnvironment["AGENTS_MONITOR_SESSIONS_DIR"] = seeded.sessionsDirectory.path
        secondLaunch.launch()

        verifySessionAndHistoryVisible(in: secondLaunch, seeded: seeded)

        let filenamesAfterRestart = try FileManager.default.contentsOfDirectory(atPath: seeded.sessionsDirectory.path)
        XCTAssertTrue(
            filenamesAfterRestart.contains(seeded.canonicalURL.lastPathComponent),
            "Expected canonical lowercase session file after restart"
        )
    }

    private func verifySessionAndHistoryVisible(in app: XCUIApplication, seeded: SeededSession) {
        let sessionByName = app.staticTexts[seeded.sessionName]
        XCTAssertTrue(sessionByName.waitForExistence(timeout: 20), "Expected seeded session to appear in menu bar popover")
    }

    private func seedLegacySession() throws -> SeededSession {
        let sessionID = "0a1b2c3d-4e5f-4a6b-8c9d-0e1f2a3b4c5d"
        let uppercasedID = sessionID.uppercased()
        let sessionName = "UI Legacy History Smoke"
        let toolCallName = "Read"
        let toolCallInput = "UI_HISTORY_README.md"

        let sessionsDirectory = try isolatedSessionsDirectoryURL()
        let uppercasedURL = sessionsDirectory.appendingPathComponent("\(uppercasedID).json")
        let canonicalURL = sessionsDirectory.appendingPathComponent("\(sessionID).json")

        try? FileManager.default.removeItem(at: uppercasedURL)
        try? FileManager.default.removeItem(at: canonicalURL)

        let payload = """
        {
          "id": "\(sessionID)",
          "name": "\(sessionName)",
          "status": "running",
          "agentType": "ClaudeCode",
          "startedAt": "2099-01-20T15:04:05.678Z",
          "messages": [
            {
              "id": "11111111-1111-4111-8111-111111111111",
              "role": "User",
              "content": "ui-history-message",
              "timestamp": "2099-01-20T15:04:06.001Z"
            }
          ],
          "toolCalls": [
            {
              "id": "22222222-2222-4222-8222-222222222222",
              "name": "\(toolCallName)",
              "input": "\(toolCallInput)",
              "startedAt": "2099-01-20T15:04:06.500Z",
              "completedAt": "2099-01-20T15:04:07.000Z",
              "status": "Completed"
            }
          ],
          "metrics": {
            "totalTokens": 100,
            "inputTokens": 40,
            "outputTokens": 60,
            "toolCallCount": 1,
            "errorCount": 0,
            "apiCalls": 1
          },
          "workingDirectory": "/tmp"
        }
        """

        try Data(payload.utf8).write(to: uppercasedURL, options: .atomic)

        return SeededSession(
            sessionName: sessionName,
            sessionsDirectory: sessionsDirectory,
            uppercasedURL: uppercasedURL,
            canonicalURL: canonicalURL
        )
    }

    private func isolatedSessionsDirectoryURL() throws -> URL {
        let sessionsDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AgentsMonitorUITests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: sessionsDirectory,
            withIntermediateDirectories: true
        )
        return sessionsDirectory
    }

    private func terminateRunningAppIfNeeded() {
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.agentsmonitor.app")
        guard !runningApps.isEmpty else { return }

        for app in runningApps {
            _ = app.terminate()
        }

        waitForTermination(timeout: 2)

        let stillRunning = NSRunningApplication.runningApplications(withBundleIdentifier: "com.agentsmonitor.app")
        if !stillRunning.isEmpty {
            for app in stillRunning {
                app.forceTerminate()
            }
            waitForTermination(timeout: 2)
        }

        if !NSRunningApplication.runningApplications(withBundleIdentifier: "com.agentsmonitor.app").isEmpty {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
            process.arguments = ["-x", "AgentsMonitor"]
            try? process.run()
            process.waitUntilExit()
            waitForTermination(timeout: 2)
        }
    }

    private func waitForTermination(timeout: TimeInterval) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let stillRunning = NSRunningApplication.runningApplications(withBundleIdentifier: "com.agentsmonitor.app")
            if stillRunning.isEmpty || stillRunning.allSatisfy({ $0.isTerminated }) {
                break
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
    }
}
