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
        XCTAssertTrue(headerActive.waitForExistence(timeout: 2))

        let sessionRows = app.otherElements.matching(identifier: "menuBar.sessionRow")
        let sessionNames = app.staticTexts.matching(identifier: "menuBar.session.name")
        XCTAssertTrue(sessionRows.count > 0 || sessionNames.count > 0)

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
