// SPDX-License-Identifier: CC0-1.0
// This file is part of StepAway - https://github.com/the-michael-toy/StepAway

import AppKit
import SwiftUI
import ServiceManagement

final class AppCoordinator {
    enum CountdownMode: Equatable {
        case running
        case snoozed
        case pausedUntilBreak
    }

    enum State: Equatable {
        case disabled
        case running
        case snoozed
        case walkAlert
        case pausedUntilBreak
        case confirmingPresence(previous: CountdownMode, pendingWalkAlert: Bool)
        case away
    }

    enum Event: Equatable {
        case timerReachedZero
        case alertActionFiveMoreMinutes
        case alertActionLastTaskThenBreak
        case idleThresholdReached(showStillThereDialog: Bool)
        case activityDetected
        case stillThereTimeout
        case disableRequested
        case enableRequested
        case resetRequested
    }

    enum Effect: Equatable {
        case showWalkAlert
        case dismissWalkAlert
        case showStillThere
        case dismissStillThere
        case markPresent
        case markAwayAndPause
        case pauseUntilBreak
        case setSnooze(minutes: Int)
        case resetTimer
        case disableTimer
        case enableTimer
    }

    private(set) var state: State

    init(isEnabled: Bool) {
        state = isEnabled ? .running : .disabled
    }

    @discardableResult
    func transition(_ event: Event) -> [Effect] {
        switch (state, event) {
        case (.disabled, .enableRequested):
            state = .running
            return [.enableTimer, .markPresent, .resetTimer]
        case (.disabled, .idleThresholdReached):
            return [.markPresent]
        case (.disabled, _):
            return []

        case (_, .disableRequested):
            state = .disabled
            return [.dismissWalkAlert, .dismissStillThere, .disableTimer, .markPresent]

        case (_, .resetRequested):
            state = .running
            return [.dismissWalkAlert, .dismissStillThere, .markPresent, .resetTimer]

        case (.running, .timerReachedZero), (.snoozed, .timerReachedZero):
            state = .walkAlert
            return [.showWalkAlert]

        case (.walkAlert, .alertActionFiveMoreMinutes):
            state = .snoozed
            return [.dismissWalkAlert, .setSnooze(minutes: 5)]

        case (.walkAlert, .alertActionLastTaskThenBreak):
            state = .pausedUntilBreak
            return [.dismissWalkAlert, .pauseUntilBreak]

        case (.walkAlert, .idleThresholdReached):
            state = .away
            return [.dismissWalkAlert, .markAwayAndPause]

        case (.running, .idleThresholdReached(let showStillThereDialog)):
            if showStillThereDialog {
                state = .confirmingPresence(previous: .running, pendingWalkAlert: false)
                return [.showStillThere]
            }
            state = .away
            return [.markAwayAndPause]

        case (.snoozed, .idleThresholdReached(let showStillThereDialog)):
            if showStillThereDialog {
                state = .confirmingPresence(previous: .snoozed, pendingWalkAlert: false)
                return [.showStillThere]
            }
            state = .away
            return [.markAwayAndPause]

        case (.confirmingPresence(let previous, let pendingWalkAlert), .activityDetected):
            if pendingWalkAlert {
                state = .walkAlert
                return [.dismissStillThere, .markPresent, .showWalkAlert]
            }
            switch previous {
            case .running:
                state = .running
            case .snoozed:
                state = .snoozed
            case .pausedUntilBreak:
                state = .pausedUntilBreak
            }
            return [.dismissStillThere, .markPresent]

        case (.confirmingPresence, .stillThereTimeout):
            state = .away
            return [.dismissStillThere, .markAwayAndPause]

        case (.confirmingPresence(let previous, _), .timerReachedZero):
            state = .confirmingPresence(previous: previous, pendingWalkAlert: true)
            return []

        case (.pausedUntilBreak, .idleThresholdReached(let showStillThereDialog)):
            if showStillThereDialog {
                state = .confirmingPresence(previous: .pausedUntilBreak, pendingWalkAlert: false)
                return [.showStillThere]
            }
            state = .away
            return [.markAwayAndPause]

        case (.away, .activityDetected):
            state = .running
            return [.markPresent, .resetTimer]

        default:
            return []
        }
    }

    static func stateName(_ state: State) -> String {
        switch state {
        case .disabled:
            return "disabled"
        case .running:
            return "running"
        case .snoozed:
            return "snoozed"
        case .walkAlert:
            return "walkAlert"
        case .pausedUntilBreak:
            return "pausedUntilBreak"
        case .confirmingPresence(let previous, let pendingWalkAlert):
            return "confirmingPresence(previous:\(countdownModeName(previous)),pendingWalkAlert:\(pendingWalkAlert))"
        case .away:
            return "away"
        }
    }

    static func eventName(_ event: Event) -> String {
        switch event {
        case .timerReachedZero:
            return "timerReachedZero"
        case .alertActionFiveMoreMinutes:
            return "alertActionFiveMoreMinutes"
        case .alertActionLastTaskThenBreak:
            return "alertActionLastTaskThenBreak"
        case .idleThresholdReached(let showStillThereDialog):
            return "idleThresholdReached(showStillThereDialog:\(showStillThereDialog))"
        case .activityDetected:
            return "activityDetected"
        case .stillThereTimeout:
            return "stillThereTimeout"
        case .disableRequested:
            return "disableRequested"
        case .enableRequested:
            return "enableRequested"
        case .resetRequested:
            return "resetRequested"
        }
    }

    static func effectName(_ effect: Effect) -> String {
        switch effect {
        case .showWalkAlert:
            return "showWalkAlert"
        case .dismissWalkAlert:
            return "dismissWalkAlert"
        case .showStillThere:
            return "showStillThere"
        case .dismissStillThere:
            return "dismissStillThere"
        case .markPresent:
            return "markPresent"
        case .markAwayAndPause:
            return "markAwayAndPause"
        case .pauseUntilBreak:
            return "pauseUntilBreak"
        case .setSnooze(let minutes):
            return "setSnooze(minutes:\(minutes))"
        case .resetTimer:
            return "resetTimer"
        case .disableTimer:
            return "disableTimer"
        case .enableTimer:
            return "enableTimer"
        }
    }

    static func countdownModeName(_ mode: CountdownMode) -> String {
        switch mode {
        case .running:
            return "running"
        case .snoozed:
            return "snoozed"
        case .pausedUntilBreak:
            return "pausedUntilBreak"
        }
    }
}

final class DebugEventLog {
    struct Record {
        let sequence: Int
        let timestamp: Date
        let message: String
    }

    private var records: [Record] = []
    private var nextSequence = 1
    private let capacity: Int
    private let formatter: DateFormatter

    init(capacity: Int = 500) {
        self.capacity = capacity
        formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
    }

    var count: Int {
        records.count
    }

    func append(_ message: String, at timestamp: Date = Date()) {
        let record = Record(sequence: nextSequence, timestamp: timestamp, message: message)
        nextSequence += 1
        records.append(record)
        if records.count > capacity {
            records.removeFirst(records.count - capacity)
        }
    }

    func clear() {
        records.removeAll(keepingCapacity: true)
    }

    func formattedText(since interval: TimeInterval?) -> String {
        let cutoff = interval.map { Date().addingTimeInterval(-$0) }
        let filtered = records.filter { record in
            guard let cutoff else { return true }
            return record.timestamp >= cutoff
        }
        return filtered.map { record in
            "\(formatter.string(from: record.timestamp)) | seq=\(record.sequence) | \(record.message)"
        }.joined(separator: "\n")
    }
}

class MenuBarController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var timerManager: TimerManager!
    private var activityMonitor: ActivityMonitor!
    private var coordinator: AppCoordinator!
    private let debugLog = DebugEventLog(capacity: 500)

    // Menu items that need updating
    private var launchAtLoginMenuItem: NSMenuItem!
    private var debugLogMenuItem: NSMenuItem!
    private var debugLogSeparatorMenuItem: NSMenuItem!

    // Windows
    private var settingsWindowController: SettingsWindowController?
    private var stillThereWindow: NSWindow?
    private var stillThereTimer: Timer?
    private var stillThereWarningTimer: Timer?
    private var stillThereProgressTimer: Timer?
    private var stillThereProgressBar: NSProgressIndicator?
    private var aboutWindow: NSWindow?
    private var debugLogWindow: NSWindow?
    private var debugLogHeaderLabel: NSTextField?
    private var debugLogTextView: NSTextView?
    private var debugFilterPopup: NSPopUpButton?

    // Walk alert state
    private var isWalkAlertShowing = false

    // Track previous app to restore focus
    private var previousActiveApp: NSRunningApplication?

    private var isRunningFromApplications: Bool {
        let bundlePath = Bundle.main.bundlePath
        return bundlePath.hasPrefix("/Applications/")
    }

    override init() {
        super.init()
        setupStatusItem()
        setupTimerManager()
        setupActivityMonitor()
        debugLog.append("lifecycle=appLaunched")
        logSettingsSnapshot(reason: "appLaunched")
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if statusItem.button != nil {
            updateButtonTitle(timeRemaining: AppSettings.shared.timerInterval)
        }

        setupMenu()
    }

    private func setupTimerManager() {
        timerManager = TimerManager()
        coordinator = AppCoordinator(isEnabled: timerManager.isEnabled)
        timerManager.onTick = { [weak self] remaining in
            self?.updateButtonTitle(timeRemaining: remaining)
        }
        timerManager.onTimerComplete = { [weak self] in
            self?.handle(event: .timerReachedZero)
        }
        timerManager.onStateChange = { [weak self] in
            self?.updateMenuState()
            self?.updateButtonTitle(timeRemaining: self?.timerManager.timeRemaining ?? 0)
        }
        // Update display now that timerManager exists (needed to show disabled state on launch)
        updateButtonTitle(timeRemaining: timerManager.timeRemaining)
    }

    private func setupActivityMonitor() {
        activityMonitor = ActivityMonitor()
        activityMonitor.onActivityDetected = { [weak self] in
            self?.handleActivityDetected()
        }
        activityMonitor.onIdleCheckNeeded = { [weak self] in
            self?.handleIdleCheckNeeded()
        }
        activityMonitor.startMonitoring()
    }

    private func handleIdleCheckNeeded() {
        handle(event: .idleThresholdReached(showStillThereDialog: AppSettings.shared.showStillThereDialog))
    }

    private func handleActivityDetected() {
        handle(event: .activityDetected)
    }

    private func handle(event: AppCoordinator.Event) {
        let previousState = coordinator.state
        let effects = coordinator.transition(event)
        logTransition(event: event, from: previousState, to: coordinator.state, effects: effects)
        apply(effects: effects)
        updateButtonTitle(timeRemaining: timerManager.timeRemaining)
    }

    private func apply(effects: [AppCoordinator.Effect]) {
        for effect in effects {
            apply(effect: effect)
        }
    }

    private func apply(effect: AppCoordinator.Effect) {
        debugLog.append("effect=\(AppCoordinator.effectName(effect))")
        refreshDebugLogViewIfVisible()

        switch effect {
        case .showWalkAlert:
            showWalkAlert()
        case .dismissWalkAlert:
            dismissWalkAlertIfNeeded()
        case .showStillThere:
            showStillThereWindow()
        case .dismissStillThere:
            dismissStillThereWindow()
        case .markPresent:
            activityMonitor.userConfirmedPresent()
        case .markAwayAndPause:
            activityMonitor.userConfirmedAway()
            timerManager.pauseAsTrulyAway()
        case .pauseUntilBreak:
            timerManager.pauseTemporarily()
        case .setSnooze(let minutes):
            timerManager.snooze(minutes: minutes)
        case .resetTimer:
            timerManager.reset()
        case .disableTimer:
            timerManager.setEnabled(false)
        case .enableTimer:
            timerManager.setEnabled(true)
        }
    }

    private func dismissWalkAlertIfNeeded() {
        guard isWalkAlertShowing else { return }
        NSApp.stopModal(withCode: .abort)
    }

    private func updateButtonTitle(timeRemaining: TimeInterval) {
        guard let button = statusItem.button else { return }

        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60

        let workingIcon = "\u{1F9D1}\u{200D}\u{1F4BB}"
        let walkingIcon = "\u{1F6B6}"

        // Use monospaced digit font to prevent jitter as timer counts down
        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let baseAttributes: [NSAttributedString.Key: Any] = [.font: font]

        let currentState = coordinator?.state

        if currentState == .away {
            let timeText = "\(walkingIcon) --:-- \u{23F8}"
            button.attributedTitle = NSAttributedString(string: timeText, attributes: baseAttributes)
            return
        }

        if currentState == .pausedUntilBreak {
            let timeText = "\(workingIcon) --:-- \u{23F8}"
            button.attributedTitle = NSAttributedString(string: timeText, attributes: baseAttributes)
            return
        }

        if currentState == .disabled || (currentState == nil && AppSettings.shared.isEnabled == false) {
            let timeText = "\(workingIcon) --:-- \u{23F9}"
            let attributed = NSMutableAttributedString(string: timeText, attributes: baseAttributes)
            let stopRange = (timeText as NSString).range(of: "\u{23F9}")
            attributed.addAttribute(.foregroundColor, value: NSColor.systemRed, range: stopRange)
            button.attributedTitle = attributed
            return
        }

        let timeText = "\(workingIcon) \(String(format: "%d:%02d", minutes, seconds))"
        button.attributedTitle = NSAttributedString(string: timeText, attributes: baseAttributes)
    }

    private func setupMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self

        // Settings
        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(showSettings),
            keyEquivalent: ""
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // Launch at login
        launchAtLoginMenuItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin(_:)),
            keyEquivalent: ""
        )
        launchAtLoginMenuItem.target = self
        launchAtLoginMenuItem.isEnabled = isRunningFromApplications
        launchAtLoginMenuItem.state = AppSettings.shared.launchAtLogin ? .on : .off
        menu.addItem(launchAtLoginMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Reset timer
        let resetItem = NSMenuItem(
            title: "Reset Timer",
            action: #selector(resetTimer),
            keyEquivalent: ""
        )
        resetItem.target = self
        menu.addItem(resetItem)

        menu.addItem(NSMenuItem.separator())

        // Hidden debug log item (revealed only when Option is held while opening menu)
        debugLogSeparatorMenuItem = NSMenuItem.separator()
        debugLogSeparatorMenuItem.isHidden = true
        menu.addItem(debugLogSeparatorMenuItem)

        debugLogMenuItem = NSMenuItem(
            title: "Show Debug Event Log...",
            action: #selector(showDebugEventLog),
            keyEquivalent: ""
        )
        debugLogMenuItem.target = self
        debugLogMenuItem.isHidden = true
        menu.addItem(debugLogMenuItem)

        // About
        let aboutItem = NSMenuItem(
            title: "About StepAway...",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit StepAway",
            action: #selector(quitApp),
            keyEquivalent: ""
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func updateMenuState() {
        // Menu state now managed by Settings window
    }

    @objc private func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
            settingsWindowController?.onSettingsChanged = { [weak self] in
                self?.handleSettingsChanged()
            }
        }
        settingsWindowController?.showWindow()
    }

    private func handleSettingsChanged() {
        activityMonitor.updateIdleInterval()
        logSettingsSnapshot(reason: "settingsChanged")

        if AppSettings.shared.isEnabled {
            if coordinator.state == .disabled {
                handle(event: .enableRequested)
            } else {
                handle(event: .resetRequested)
            }
        } else {
            handle(event: .disableRequested)
        }
    }

    @objc private func showAbout() {
        // Reuse existing window if open
        if let existingWindow = aboutWindow, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 270),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About StepAway"
        window.center()
        window.isReleasedWhenClosed = false

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 380, height: 270))

        // App icon on the left
        let iconView = NSImageView(frame: NSRect(x: 20, y: 195, width: 64, height: 64))
        iconView.image = NSApp.applicationIconImage
        iconView.imageScaling = .scaleProportionallyUpOrDown
        contentView.addSubview(iconView)

        // App name to the right of icon
        let titleLabel = NSTextField(labelWithString: "StepAway")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 18)
        titleLabel.frame = NSRect(x: 100, y: 235, width: 260, height: 22)
        contentView.addSubview(titleLabel)

        // Version
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let versionLabel = NSTextField(labelWithString: "Version \(version)")
        versionLabel.font = NSFont.systemFont(ofSize: 12)
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.frame = NSRect(x: 100, y: 215, width: 260, height: 16)
        contentView.addSubview(versionLabel)

        // Description - below icon, full width
        let descLabel = NSTextField(labelWithString: "A macOS menu bar app that reminds you to take walking breaks.")
        descLabel.font = NSFont.systemFont(ofSize: 11)
        descLabel.textColor = .secondaryLabelColor
        descLabel.frame = NSRect(x: 20, y: 162, width: 340, height: 28)
        descLabel.usesSingleLineMode = false
        descLabel.cell?.wraps = true
        contentView.addSubview(descLabel)

        // Collective attribution - left aligned
        let collectiveLabel = NSTextField(labelWithString: "A product of the")
        collectiveLabel.font = NSFont.systemFont(ofSize: 11)
        collectiveLabel.textColor = .secondaryLabelColor
        collectiveLabel.frame = NSRect(x: 20, y: 130, width: 90, height: 16)
        contentView.addSubview(collectiveLabel)

        let collectiveButton = NSButton(frame: NSRect(x: 106, y: 130, width: 155, height: 16))
        collectiveButton.title = "Apocalyptic Art Collective"
        collectiveButton.bezelStyle = .inline
        collectiveButton.isBordered = false
        collectiveButton.font = NSFont.systemFont(ofSize: 11)
        collectiveButton.contentTintColor = .linkColor
        collectiveButton.target = self
        collectiveButton.action = #selector(openCollective)
        contentView.addSubview(collectiveButton)

        // GitHub link - below collective, left aligned
        let linkButton = NSButton(frame: NSRect(x: 16, y: 112, width: 230, height: 16))
        linkButton.title = "github.com/the-michael-toy/StepAway"
        linkButton.bezelStyle = .inline
        linkButton.isBordered = false
        linkButton.font = NSFont.systemFont(ofSize: 11)
        linkButton.contentTintColor = .linkColor
        linkButton.target = self
        linkButton.action = #selector(openRepo)
        contentView.addSubview(linkButton)

        // Horizontal separator line
        let separator = NSBox(frame: NSRect(x: 20, y: 98, width: 340, height: 1))
        separator.boxType = .separator
        contentView.addSubview(separator)

        // Built with Claude link
        let claudeButton = NSButton(frame: NSRect(x: 16, y: 75, width: 180, height: 16))
        claudeButton.title = "Built with Claude Code"
        claudeButton.bezelStyle = .inline
        claudeButton.isBordered = false
        claudeButton.font = NSFont.systemFont(ofSize: 11)
        claudeButton.contentTintColor = .linkColor
        claudeButton.target = self
        claudeButton.action = #selector(openClaude)
        contentView.addSubview(claudeButton)

        // Disclaimer
        let disclaimerLabel = NSTextField(labelWithString: "This software is provided as-is. It was developed with AI assistance. Please review the source code and exercise your own judgment before use.")
        disclaimerLabel.font = NSFont.systemFont(ofSize: 10)
        disclaimerLabel.textColor = .tertiaryLabelColor
        disclaimerLabel.frame = NSRect(x: 20, y: 38, width: 340, height: 32)
        disclaimerLabel.usesSingleLineMode = false
        disclaimerLabel.cell?.wraps = true
        contentView.addSubview(disclaimerLabel)

        // OK button
        let okButton = NSButton(frame: NSRect(x: 290, y: 10, width: 70, height: 24))
        okButton.title = "OK"
        okButton.bezelStyle = .rounded
        okButton.target = window
        okButton.action = #selector(NSWindow.close)
        okButton.keyEquivalent = "\r"
        contentView.addSubview(okButton)

        window.contentView = contentView
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        aboutWindow = window
    }

    @objc private func openRepo() {
        if let url = URL(string: "https://github.com/the-michael-toy/StepAway") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openCollective() {
        if let url = URL(string: "https://apocalypticartcollective.com/") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openClaude() {
        if let url = URL(string: "https://claude.ai/claude-code") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let newState = !AppSettings.shared.launchAtLogin
        AppSettings.shared.launchAtLogin = newState
        sender.state = newState ? .on : .off

        // Register/unregister with Launch Services
        if #available(macOS 13.0, *) {
            do {
                if newState {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to update launch at login: \(error)")
            }
        } else {
            // Fallback for older macOS versions
            let launcherAppId = "io.github.the-michael-toy.StepAway.launcher"
            SMLoginItemSetEnabled(launcherAppId as CFString, newState)
        }
    }

    @objc private func resetTimer() {
        handle(event: .resetRequested)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    func menuWillOpen(_ menu: NSMenu) {
        let shouldShowDebug = isOptionKeyPressed()
        debugLogMenuItem.isHidden = !shouldShowDebug
        debugLogSeparatorMenuItem.isHidden = !shouldShowDebug
    }

    func menuDidClose(_ menu: NSMenu) {
        debugLogMenuItem.isHidden = true
        debugLogSeparatorMenuItem.isHidden = true
    }

    private func isOptionKeyPressed() -> Bool {
        CGEventSource.flagsState(.combinedSessionState).contains(.maskAlternate)
    }

    @objc private func showDebugEventLog() {
        if debugLogWindow == nil {
            createDebugLogWindow()
        }
        refreshDebugLogView()
        debugLogWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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

    private func refreshDebugLogViewIfVisible() {
        guard debugLogWindow?.isVisible == true else { return }
        refreshDebugLogView()
    }

    private func refreshDebugLogView() {
        let interval = selectedDebugFilterInterval()
        debugLogTextView?.string = debugLog.formattedText(since: interval)

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let stateText = AppCoordinator.stateName(coordinator.state)
        debugLogHeaderLabel?.stringValue = "Version \(version) (\(build)) | State: \(stateText) | Records: \(debugLog.count)"
    }

    private func logTransition(event: AppCoordinator.Event, from: AppCoordinator.State, to: AppCoordinator.State, effects: [AppCoordinator.Effect]) {
        let eventName = AppCoordinator.eventName(event)
        let fromName = AppCoordinator.stateName(from)
        let toName = AppCoordinator.stateName(to)
        let effectNames = effects.map { AppCoordinator.effectName($0) }.joined(separator: ",")
        debugLog.append("event=\(eventName) | state=\(fromName)->\(toName) | effects=[\(effectNames)]")
        refreshDebugLogViewIfVisible()
    }

    private func logSettingsSnapshot(reason: String) {
        debugLog.append(
            "settings(reason:\(reason)) | isEnabled=\(AppSettings.shared.isEnabled) | timerInterval=\(Int(AppSettings.shared.timerInterval)) | idleInterval=\(Int(AppSettings.shared.idleInterval)) | showStillThereDialog=\(AppSettings.shared.showStillThereDialog)"
        )
        refreshDebugLogViewIfVisible()
    }

    private func showStillThereWindow() {
        guard stillThereWindow == nil else { return }

        // Save the currently active app so we can restore focus later
        previousActiveApp = NSWorkspace.shared.frontmostApplication

        // Create a simple window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 140),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.title = "StepAway"
        window.isReleasedWhenClosed = false
        window.level = .floating

        // Position near the mouse cursor, staying on screen
        let mouseLocation = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) {
            let screenFrame = screen.visibleFrame
            let windowSize = window.frame.size
            let padding: CGFloat = 20

            // Prefer left of cursor, fall back to right
            var x: CGFloat
            if mouseLocation.x - windowSize.width - padding >= screenFrame.minX {
                x = mouseLocation.x - windowSize.width - padding
            } else {
                x = mouseLocation.x + padding
            }
            // Clamp to screen bounds
            x = max(screenFrame.minX, min(x, screenFrame.maxX - windowSize.width))

            // Prefer above cursor, fall back to below
            var y: CGFloat
            if mouseLocation.y + padding + windowSize.height <= screenFrame.maxY {
                y = mouseLocation.y + padding
            } else {
                y = mouseLocation.y - windowSize.height - padding
            }
            // Clamp to screen bounds
            y = max(screenFrame.minY, min(y, screenFrame.maxY - windowSize.height))

            window.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            window.center()
        }

        // Create the content
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 140))

        // App icon
        let iconView = NSImageView(frame: NSRect(x: 125, y: 85, width: 50, height: 50))
        iconView.image = NSApp.applicationIconImage
        iconView.imageScaling = .scaleProportionallyUpOrDown

        let titleLabel = NSTextField(labelWithString: "Still there?")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 18)
        titleLabel.alignment = .center
        titleLabel.frame = NSRect(x: 20, y: 55, width: 260, height: 30)

        // Progress bar (fills over 60 seconds)
        let progressBar = NSProgressIndicator(frame: NSRect(x: 20, y: 42, width: 260, height: 6))
        progressBar.style = .bar
        progressBar.isIndeterminate = false
        progressBar.minValue = 0
        progressBar.maxValue = 60
        progressBar.doubleValue = 0
        stillThereProgressBar = progressBar

        let subtitleLabel = NSTextField(labelWithString: "Move the mouse or press any key.")
        subtitleLabel.font = NSFont.systemFont(ofSize: 13)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.alignment = .center
        subtitleLabel.frame = NSRect(x: 20, y: 18, width: 260, height: 20)

        contentView.addSubview(iconView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(progressBar)
        contentView.addSubview(subtitleLabel)
        window.contentView = contentView

        // Show the window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        stillThereWindow = window

        // Warning sound and flash 10 seconds before auto-dismiss
        stillThereWarningTimer = Timer.scheduledTimer(withTimeInterval: 50.0, repeats: false) { [weak self] _ in
            // Play warning sound if enabled
            if AppSettings.shared.playWarningSound {
                let soundName = AppSettings.shared.warningSound
                NSSound(named: NSSound.Name(soundName))?.play()
            }

            // Flash the window background
            if let window = self?.stillThereWindow, let contentView = window.contentView {
                contentView.wantsLayer = true
                contentView.layer?.backgroundColor = NSColor.systemYellow.cgColor
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    contentView.layer?.backgroundColor = nil
                }
            }
        }

        // Start 60-second timer
        stillThereTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: false) { [weak self] _ in
            self?.handle(event: .stillThereTimeout)
        }

        // Update progress bar smoothly (10 times per second)
        stillThereProgressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            if let progressBar = self?.stillThereProgressBar {
                progressBar.doubleValue += 0.1
            }
        }
    }

    private func dismissStillThereWindow() {
        stillThereTimer?.invalidate()
        stillThereTimer = nil
        stillThereWarningTimer?.invalidate()
        stillThereWarningTimer = nil
        stillThereProgressTimer?.invalidate()
        stillThereProgressTimer = nil
        stillThereProgressBar = nil

        stillThereWindow?.close()
        stillThereWindow = nil

        // Restore focus to the previously active app
        if let previousApp = previousActiveApp {
            previousApp.activate()
            previousActiveApp = nil
        }
    }

    private func showWalkAlert() {
        // Dismiss "Still there?" if showing - walk alert takes priority
        if stillThereWindow != nil {
            dismissStillThereWindow()
        }

        DispatchQueue.main.async {
            self.isWalkAlertShowing = true

            let alert = NSAlert()
            alert.messageText = "Time to Step Away!"
            alert.informativeText = "Choose \"Last task, then break\" to pause reminders until you take a break and return."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "5 more minutes")
            alert.addButton(withTitle: "Last task, then break")

            // Bring app to front for the alert
            NSApp.activate(ignoringOtherApps: true)

            let response = alert.runModal()
            self.isWalkAlertShowing = false

            // Another event already moved us out of walkAlert (for example idle/disable).
            guard self.coordinator.state == .walkAlert else {
                return
            }

            if response == .alertFirstButtonReturn {
                self.handle(event: .alertActionFiveMoreMinutes)
            } else if response == .alertSecondButtonReturn {
                self.handle(event: .alertActionLastTaskThenBreak)
            }
        }
    }

    func cleanup() {
        debugLog.append("lifecycle=appWillTerminate")
        activityMonitor.stopMonitoring()
        timerManager.stop()
    }
}
