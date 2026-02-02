// SPDX-License-Identifier: CC0-1.0
// This file is part of StepAway - https://github.com/the-michael-toy/StepAway

import AppKit
import SwiftUI
import ServiceManagement

class MenuBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var timerManager: TimerManager!
    private var activityMonitor: ActivityMonitor!

    // Menu items that need updating
    private var launchAtLoginMenuItem: NSMenuItem!

    // Windows
    private var settingsWindowController: SettingsWindowController?
    private var stillThereWindow: NSWindow?
    private var stillThereTimer: Timer?
    private var stillThereWarningTimer: Timer?
    private var stillThereProgressTimer: Timer?
    private var stillThereProgressBar: NSProgressIndicator?
    private var aboutWindow: NSWindow?

    // Walk alert state
    private var isWalkAlertShowing = false
    private var walkAlertDismissedDueToIdle = false

    // Grace period after clicking "OK, I'll Walk!" - ignore activity until this time
    private var activityGraceUntil: Date?

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
        timerManager.onTick = { [weak self] remaining in
            self?.updateButtonTitle(timeRemaining: remaining)
        }
        timerManager.onTimerComplete = { [weak self] in
            self?.showWalkAlert()
        }
        timerManager.onStateChange = { [weak self] in
            self?.updateMenuState()
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
        // If disabled, don't show "Still there?" - user doesn't want interruptions
        if !timerManager.isEnabled {
            return
        }

        // If already paused as away, don't show "Still there?" - we know they're away
        if timerManager.wasTrulyAway {
            return
        }

        // If walk alert is showing and user went idle, they already stepped away!
        // Dismiss the alert and pause the timer (same as clicking "OK, I'll Walk!").
        if isWalkAlertShowing {
            walkAlertDismissedDueToIdle = true
            activityMonitor.userConfirmedAway()  // Mark as away
            timerManager.pauseAsTrulyAway()      // Pause timer until they return
            updateButtonTitle(timeRemaining: timerManager.timeRemaining)
            NSApp.stopModal()
            return
        }

        if AppSettings.shared.showStillThereDialog {
            showStillThereWindow()
        } else {
            // Skip the dialog, directly assume user is away
            activityMonitor.userConfirmedAway()
            timerManager.pauseAsTrulyAway()
            updateButtonTitle(timeRemaining: timerManager.timeRemaining)
        }
    }

    private func handleActivityDetected() {
        // Ignore activity during grace period (right after clicking "OK, I'll Walk!")
        if let graceUntil = activityGraceUntil, Date() < graceUntil {
            // Re-confirm away state since activity monitor resets it when it sees activity
            activityMonitor.userConfirmedAway()
            return
        }
        activityGraceUntil = nil

        if stillThereWindow != nil {
            // Activity while "still there?" window is showing - user is present
            dismissStillThereWindow(userIsPresent: true)
        } else {
            // Normal activity after being away
            timerManager.resumeIfNeeded()
        }
    }

    private func updateButtonTitle(timeRemaining: TimeInterval) {
        guard let button = statusItem.button else { return }

        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60

        // Walking person symbol (U+1F6B6) or use SF Symbol
        let walkingIcon = "\u{1F6B6}"

        // Use monospaced digit font to prevent jitter as timer counts down
        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let baseAttributes: [NSAttributedString.Key: Any] = [.font: font]

        if timerManager?.wasTrulyAway == true {
            // User is away - show --:-- with pause symbol
            let timeText = "\(walkingIcon) --:-- \u{23F8}"
            button.attributedTitle = NSAttributedString(string: timeText, attributes: baseAttributes)
        } else if timerManager?.isEnabled == false {
            // Disabled - show --:-- with red stop symbol
            let timeText = "\(walkingIcon) --:-- \u{23F9}"
            let attributed = NSMutableAttributedString(string: timeText, attributes: baseAttributes)
            // Color the stop symbol red
            let stopRange = (timeText as NSString).range(of: "\u{23F9}")
            attributed.addAttribute(.foregroundColor, value: NSColor.systemRed, range: stopRange)
            button.attributedTitle = attributed
        } else {
            let timeText = "\(walkingIcon) \(String(format: "%d:%02d", minutes, seconds))"
            button.attributedTitle = NSAttributedString(string: timeText, attributes: baseAttributes)
        }
    }

    private func setupMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

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
        // Sync enabled state
        let enabled = AppSettings.shared.isEnabled
        if enabled != timerManager.isEnabled {
            timerManager.setEnabled(enabled)
        }

        // Reset timer with new interval
        timerManager.reset()
        activityMonitor.updateIdleInterval()
        updateButtonTitle(timeRemaining: timerManager.timeRemaining)
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
        timerManager.reset()
        updateButtonTitle(timeRemaining: timerManager.timeRemaining)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
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
            self?.dismissStillThereWindow(userIsPresent: false)
        }

        // Update progress bar smoothly (10 times per second)
        stillThereProgressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            if let progressBar = self?.stillThereProgressBar {
                progressBar.doubleValue += 0.1
            }
        }
    }

    private func dismissStillThereWindow(userIsPresent: Bool) {
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

        if userIsPresent {
            // User confirmed present - keep timer running, don't pause
            activityMonitor.userConfirmedPresent()
        } else {
            // User didn't respond - they're truly away
            activityMonitor.userConfirmedAway()
            timerManager.pauseAsTrulyAway()
            updateButtonTitle(timeRemaining: timerManager.timeRemaining)
        }
    }

    private func showWalkAlert() {
        // Set flag immediately to prevent race with idle timer
        isWalkAlertShowing = true
        walkAlertDismissedDueToIdle = false

        // Dismiss "Still there?" if showing - walk alert takes priority
        if stillThereWindow != nil {
            dismissStillThereWindow(userIsPresent: true)
        }

        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Time to Step Away!"
            alert.informativeText = "You've been working for a while. Take a walk and stretch your legs!"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK, I'll Walk!")
            alert.addButton(withTitle: "Snooze 5 min")

            // Bring app to front for the alert
            NSApp.activate(ignoringOtherApps: true)

            let response = alert.runModal()

            self.isWalkAlertShowing = false

            // If alert was dismissed because user went idle, timer is already reset
            if self.walkAlertDismissedDueToIdle {
                self.walkAlertDismissedDueToIdle = false
                self.updateButtonTitle(timeRemaining: self.timerManager.timeRemaining)
                return
            }

            if response == .alertSecondButtonReturn {
                // Snooze - set a 5 minute timer
                self.timerManager.snooze(minutes: 5)
            } else {
                // User is going for a walk - pause timer until they return
                // Grace period so the button click doesn't count as "returned"
                self.activityGraceUntil = Date().addingTimeInterval(3.0)
                self.activityMonitor.userConfirmedAway()
                self.timerManager.pauseAsTrulyAway()
            }
            self.updateButtonTitle(timeRemaining: self.timerManager.timeRemaining)
        }
    }

    func cleanup() {
        activityMonitor.stopMonitoring()
        timerManager.stop()
    }
}
