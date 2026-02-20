// SPDX-License-Identifier: CC0-1.0
// This file is part of StepAway - https://github.com/the-michael-toy/StepAway

import AppKit

final class DebugLogWindowController {
    private let debugLog: DebugEventLog
    private var debugLogWindow: NSWindow?
    private var debugLogHeaderLabel: NSTextField?
    private var debugLogTextView: NSTextView?
    private var debugFilterPopup: NSPopUpButton?

    private var closeObserver: NSObjectProtocol?

    var stateDescription: (() -> String)?
    var onWindowClosed: (() -> Void)?

    var isShowing: Bool { debugLogWindow?.isVisible == true }

    init(debugLog: DebugEventLog) {
        self.debugLog = debugLog
    }

    func show() {
        if debugLogWindow == nil {
            createDebugLogWindow()
        }
        refreshDebugLogView()
        debugLogWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func refreshIfVisible() {
        guard debugLogWindow?.isVisible == true else { return }
        refreshDebugLogView()
    }

    private func createDebugLogWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 560),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "StepAway Debug Event Log"
        window.center()
        window.isReleasedWhenClosed = false

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]

        let header = NSTextField(labelWithString: "")
        header.font = NSFont.systemFont(ofSize: 12)
        header.textColor = .secondaryLabelColor
        header.frame = NSRect(x: 20, y: 525, width: 860, height: 18)
        header.autoresizingMask = [.width, .minYMargin]
        contentView.addSubview(header)
        debugLogHeaderLabel = header

        let filterPopup = NSPopUpButton(frame: NSRect(x: 20, y: 495, width: 140, height: 28), pullsDown: false)
        filterPopup.addItems(withTitles: ["Last 5 min", "Last 15 min", "Last 60 min", "All"])
        filterPopup.selectItem(at: 0)
        filterPopup.target = self
        filterPopup.action = #selector(debugFilterChanged)
        filterPopup.autoresizingMask = [.maxXMargin, .minYMargin]
        contentView.addSubview(filterPopup)
        debugFilterPopup = filterPopup

        let copy5Button = NSButton(frame: NSRect(x: 170, y: 495, width: 150, height: 28))
        copy5Button.title = "Copy Last 5 Minutes"
        copy5Button.bezelStyle = .rounded
        copy5Button.target = self
        copy5Button.action = #selector(copyLastFiveMinutes)
        copy5Button.autoresizingMask = [.maxXMargin, .minYMargin]
        contentView.addSubview(copy5Button)

        let copyVisibleButton = NSButton(frame: NSRect(x: 330, y: 495, width: 110, height: 28))
        copyVisibleButton.title = "Copy Visible"
        copyVisibleButton.bezelStyle = .rounded
        copyVisibleButton.target = self
        copyVisibleButton.action = #selector(copyVisibleLog)
        copyVisibleButton.autoresizingMask = [.maxXMargin, .minYMargin]
        contentView.addSubview(copyVisibleButton)

        let clearButton = NSButton(frame: NSRect(x: 450, y: 495, width: 70, height: 28))
        clearButton.title = "Clear"
        clearButton.bezelStyle = .rounded
        clearButton.target = self
        clearButton.action = #selector(clearDebugLog)
        clearButton.autoresizingMask = [.maxXMargin, .minYMargin]
        contentView.addSubview(clearButton)

        let scrollView = NSScrollView(frame: NSRect(x: 20, y: 20, width: 860, height: 465))
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.autoresizingMask = [.width, .height]

        let textView = NSTextView(frame: scrollView.bounds)
        textView.isEditable = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.autoresizingMask = [.width, .height]
        textView.string = ""
        scrollView.documentView = textView
        contentView.addSubview(scrollView)
        debugLogTextView = textView

        window.contentView = contentView
        debugLogWindow = window
        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.onWindowClosed?()
        }
    }

    @objc private func debugFilterChanged() {
        refreshDebugLogView()
    }

    @objc private func copyLastFiveMinutes() {
        copyToPasteboard(debugLog.formattedText(since: 5 * 60))
    }

    @objc private func copyVisibleLog() {
        copyToPasteboard(debugLogTextView?.string ?? "")
    }

    @objc private func clearDebugLog() {
        debugLog.clear()
        refreshDebugLogView()
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func selectedDebugFilterInterval() -> TimeInterval? {
        switch debugFilterPopup?.indexOfSelectedItem ?? 0 {
        case 0:
            return 5 * 60
        case 1:
            return 15 * 60
        case 2:
            return 60 * 60
        default:
            return nil
        }
    }

    private func refreshDebugLogView() {
        let interval = selectedDebugFilterInterval()
        debugLogTextView?.string = debugLog.formattedText(since: interval)

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let stateText = stateDescription?() ?? "?"
        debugLogHeaderLabel?.stringValue = "Version \(version) (\(build)) | State: \(stateText) | Records: \(debugLog.count)"
    }
}
