import AppKit
import SwiftUI

final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private var eventMonitor: Any?
    private let sessionStore: SessionStore
    private let appEnvironment: AppEnvironment

    init(sessionStore: SessionStore, environment: AppEnvironment) {
        self.sessionStore = sessionStore
        self.appEnvironment = environment
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()
        super.init()
        configureStatusItem()
        configurePopover()
    }

    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "cpu", accessibilityDescription: "Agents Monitor")
        button.toolTip = "Agents Monitor"
        button.target = self
        button.action = #selector(togglePopover(_:))
        button.setAccessibilityIdentifier("menuBar.statusItem")
        button.setAccessibilityLabel("Agents Monitor")
    }

    private func configurePopover() {
        popover.behavior = .transient

        let rootView = MenuBarView()
            .environment(sessionStore)
            .environment(\.appEnvironment, appEnvironment)

        let hostingController = NSHostingController(rootView: rootView)
        popover.contentViewController = hostingController

        let view = hostingController.view
        view.layoutSubtreeIfNeeded()
        let fittingSize = view.fittingSize
        let width = max(280, fittingSize.width)
        popover.contentSize = NSSize(width: width, height: fittingSize.height)

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, self.popover.isShown else { return }
            self.closePopover(nil)
        }
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            closePopover(sender)
        } else {
            showPopover(sender)
        }
    }

    private func showPopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closePopover(_ sender: AnyObject?) {
        popover.performClose(sender)
    }
}
