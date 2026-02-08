import Foundation
import SwiftUI

struct AppEnvironment: Sendable {
    let isUITesting: Bool
    let isUnitTesting: Bool
    let mockSessionCount: Int?
    let fixedNow: Date?

    var isTesting: Bool {
        isUITesting || isUnitTesting
    }

    var now: Date {
        fixedNow ?? Date()
    }

    static var current: AppEnvironment {
        let processInfo = ProcessInfo.processInfo
        let args = processInfo.arguments
        let env = processInfo.environment

        let isUITesting = args.contains("--ui-testing") || env["AGENTS_MONITOR_UI_TESTING"] == "1"
        let isUnitTesting = env["XCTestConfigurationFilePath"] != nil
        let mockSessionCount = Int(env["AGENTS_MONITOR_UI_TEST_SESSIONS"] ?? "")
        let fixedNow = isUITesting ? AppEnvironment.defaultFixedNow : nil

        return AppEnvironment(
            isUITesting: isUITesting,
            isUnitTesting: isUnitTesting,
            mockSessionCount: mockSessionCount,
            fixedNow: fixedNow
        )
    }

    static let defaultFixedNow = Date(timeIntervalSince1970: 1_706_000_000)
}

private struct AppEnvironmentKey: EnvironmentKey {
    static let defaultValue = AppEnvironment.current
}

extension EnvironmentValues {
    var appEnvironment: AppEnvironment {
        get { self[AppEnvironmentKey.self] }
        set { self[AppEnvironmentKey.self] = newValue }
    }
}
