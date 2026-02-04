import Foundation
import SwiftTerm
import AppKit
import Darwin

final class TerminalBridge: @unchecked Sendable {
    private var process: LocalProcess?
    private weak var terminal: SwiftTerm.TerminalView?
    private var onTermination: ((Int32?) -> Void)?
    private var onDataReceived: ((Data) -> Void)?
    private let lock = NSLock()

    func attachTerminal(_ terminal: SwiftTerm.TerminalView, onTermination: ((Int32?) -> Void)? = nil, onDataReceived: ((Data) -> Void)? = nil) {
        lock.lock()
        defer { lock.unlock() }

        self.terminal = terminal
        if let onTermination {
            self.onTermination = onTermination
        }
        if let onDataReceived {
            self.onDataReceived = onDataReceived
        }
    }

    func attachProcess(_ process: LocalProcess) {
        lock.lock()
        defer { lock.unlock() }

        self.process = process
    }

    func send(data: ArraySlice<UInt8>) {
        lock.lock()
        let process = process
        lock.unlock()

        process?.send(data: data)
    }
    func disconnect() {
        lock.lock()
        defer { lock.unlock() }

        process = nil
        terminal = nil
        onTermination = nil
        onDataReceived = nil
    }
}

extension TerminalBridge: TerminalViewDelegate {
    func scrolled(source: SwiftTerm.TerminalView, position: Double) {}

    func setTerminalTitle(source: SwiftTerm.TerminalView, title: String) {}

    func sizeChanged(source: SwiftTerm.TerminalView, newCols: Int, newRows: Int) {
        lock.lock()
        let process = process
        lock.unlock()
        guard let process else { return }
        var size = getWindowSize()
        _ = PseudoTerminalHelpers.setWinSize(masterPtyDescriptor: process.childfd, windowSize: &size)
    }

    func bell(source: SwiftTerm.TerminalView) {}

    func selectionChanged(source: SwiftTerm.TerminalView) {}

    func send(source: SwiftTerm.TerminalView, data: ArraySlice<UInt8>) {
        send(data: data)
    }

    func hostCurrentDirectoryUpdate(source: SwiftTerm.TerminalView, directory: String?) {}

    func requestOpenLink(source: SwiftTerm.TerminalView, link: String, params: [String : String]) {}

    func rangeChanged(source: SwiftTerm.TerminalView, startY: Int, endY: Int) {}

    func iTermContent(source: SwiftTerm.TerminalView, content: ArraySlice<UInt8>) {}

    func clipboardCopy(source: SwiftTerm.TerminalView, content: Data) {
        if let string = String(data: content, encoding: .utf8) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(string, forType: .string)
        }
    }
}

extension TerminalBridge: LocalProcessDelegate {
    func processTerminated(_ source: LocalProcess, exitCode: Int32?) {
        lock.lock()
        let handler = onTermination
        lock.unlock()

        handler?(exitCode)
    }

    func dataReceived(slice: ArraySlice<UInt8>) {
        lock.lock()
        let terminal = terminal
        lock.unlock()
        guard let terminal else { return }
        let bytes = Array(slice)
        if Thread.isMainThread {
            terminal.feed(byteArray: bytes[...])
        } else {
            DispatchQueue.main.async {
                terminal.feed(byteArray: bytes[...])
            }
        }
        
        lock.lock()
        let dataHandler = onDataReceived
        lock.unlock()
        dataHandler?(Data(bytes))
    }

    func getWindowSize() -> winsize {
        lock.lock()
        let terminal = terminal
        lock.unlock()
        guard let terminal else {
            return winsize()
        }
        let frame = terminal.frame
        return winsize(
            ws_row: UInt16(terminal.terminal.rows),
            ws_col: UInt16(terminal.terminal.cols),
            ws_xpixel: UInt16(frame.width),
            ws_ypixel: UInt16(frame.height)
        )
    }
}
