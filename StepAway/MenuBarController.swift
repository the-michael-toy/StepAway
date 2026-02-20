// SPDX-License-Identifier: CC0-1.0
// This file is part of StepAway - https://github.com/the-michael-toy/StepAway

import AppKit
import ServiceManagement

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
    private let stillThereController = StillThereController()
    private let aboutController = AboutWindowController()
    private var debugLogController: DebugLogWindowController!

    private let walkAlertController = WalkAlertController()
    private let congratsController = CongratsController()

    private var isRunningFromApplications: Bool {
        let bundlePath = Bundle.main.bundlePath
        return bundlePath.hasPrefix("/Applications/")
    }

    override init() {
        debugLogController = DebugLogWindowController(debugLog: debugLog)
        super.init()
        debugLogController.stateDescription = { [weak self] in
            guard let self else { return "?" }
            return AppCoordinator.stateName(self.coordinator.state)
        }
        debugLogController.onWindowClosed = { [weak self] in
            self?.handle(event: .auxiliaryWindowClosed)
        }
        aboutController.onWindowClosed = { [weak self] in
            self?.handle(event: .auxiliaryWindowClosed)
        }
        stillThereController.onTimeout = { [weak self] in
            self?.handle(event: .stillThereTimeout)
        }
        walkAlertController.onGettingUpToWalk = { [weak self] in
            self?.handle(event: .alertActionGettingUpToWalk)
        }
        walkAlertController.onFiveMoreMinutes = { [weak self] in
            self?.handle(event: .alertActionFiveMoreMinutes)
        }
        walkAlertController.onLastTaskThenBreak = { [weak self] in
            self?.handle(event: .alertActionLastTaskThenBreak)
        }
        congratsController.onTimeout = { [weak self] in
            self?.handle(event: .congratsTimedOut)
        }
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
        debugLogController.refreshIfVisible()

        switch effect {
        case .showWalkAlert:
            stillThereController.dismiss()
            walkAlertController.show()
        case .dismissWalkAlert:
            walkAlertController.dismiss()
        case .showCongrats:
            congratsController.show()
        case .dismissCongrats:
            congratsController.dismiss()
        case .showStillThere:
            stillThereController.show()
        case .dismissStillThere:
            stillThereController.dismiss()
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

    @objc private func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
            settingsWindowController?.onSettingsChanged = { [weak self] in
                self?.handleSettingsChanged()
            }
            settingsWindowController?.onWindowClosed = { [weak self] in
                self?.handle(event: .settingsClosed)
                self?.resumeAfterSettings()
            }
        }
        settingsWindowController?.showWindow()
        handle(event: .settingsOpened)
        // Pause everything while settings is open
        timerManager.stop()
        activityMonitor.stopMonitoring()
    }

    private func resumeAfterSettings() {
        activityMonitor.startMonitoring()
        // Don't reset the timer if the deferred walk alert just fired —
        // the user still needs to respond to it.
        if timerManager.isEnabled && coordinator.state != .walkAlert {
            timerManager.reset()
        }
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
        // Settings is still open — keep timer stopped until settings closes.
        // resetRequested/enableRequested may have restarted it.
        timerManager.stop()
    }

    @objc private func showAbout() {
        if !aboutController.isShowing {
            handle(event: .auxiliaryWindowOpened)
        }
        aboutController.show()
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
        walkAlertController.dismiss()
        congratsController.dismiss()
        NSApplication.shared.terminate(nil)
    }

    func menuWillOpen(_ menu: NSMenu) {
        handle(event: .menuOpened)
        let shouldShowDebug = isOptionKeyPressed()
        debugLogMenuItem.isHidden = !shouldShowDebug
        debugLogSeparatorMenuItem.isHidden = !shouldShowDebug
    }

    func menuDidClose(_ menu: NSMenu) {
        handle(event: .menuClosed)
        debugLogMenuItem.isHidden = true
        debugLogSeparatorMenuItem.isHidden = true
    }

    private func isOptionKeyPressed() -> Bool {
        CGEventSource.flagsState(.combinedSessionState).contains(.maskAlternate)
    }

    @objc private func showDebugEventLog() {
        if !debugLogController.isShowing {
            handle(event: .auxiliaryWindowOpened)
        }
        debugLogController.show()
    }

    private func logTransition(event: AppCoordinator.Event, from: AppCoordinator.State, to: AppCoordinator.State, effects: [AppCoordinator.Effect]) {
        let eventName = AppCoordinator.eventName(event)
        let fromName = AppCoordinator.stateName(from)
        let toName = AppCoordinator.stateName(to)
        let effectNames = effects.map { AppCoordinator.effectName($0) }.joined(separator: ",")
        debugLog.append("event=\(eventName) | state=\(fromName)->\(toName) | effects=[\(effectNames)]")
        debugLogController.refreshIfVisible()
    }

    private func logSettingsSnapshot(reason: String) {
        debugLog.append(
            "settings(reason:\(reason)) | isEnabled=\(AppSettings.shared.isEnabled) | timerInterval=\(Int(AppSettings.shared.timerInterval)) | idleInterval=\(Int(AppSettings.shared.idleInterval)) | showStillThereDialog=\(AppSettings.shared.showStillThereDialog)"
        )
        debugLogController.refreshIfVisible()
    }

    func cleanup() {
        debugLog.append("lifecycle=appWillTerminate")
        activityMonitor.stopMonitoring()
        timerManager.stop()
    }
}
