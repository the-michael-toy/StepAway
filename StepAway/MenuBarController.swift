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
    }

    private func setupActivityMonitor() {
        activityMonitor = ActivityMonitor()
        activityMonitor.onActivityDetected = { [weak self] in
            self?.handleActivityDetected()
        }
        activityMonitor.onIdleCheckNeeded = { [weak self] in
            self?.showStillThereWindow()
        }
        activityMonitor.startMonitoring()
    }

    private func handleActivityDetected() {
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

        let timeText: String
        if timerManager?.wasTrulyAway == true {
            // User is away - show --:-- with pause symbol
            timeText = "\(walkingIcon) --:-- \u{23F8}"
        } else if timerManager?.isEnabled == false {
            timeText = "\(walkingIcon) --:--"
        } else {
            timeText = "\(walkingIcon) \(String(format: "%d:%02d", minutes, seconds))"
        }

        // Use monospaced digit font to prevent jitter as timer counts down
        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        button.attributedTitle = NSAttributedString(string: timeText, attributes: attributes)
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
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 190),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About StepAway"
        window.center()
        window.isReleasedWhenClosed = true

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 190))

        // App icon on the left
        let iconView = NSImageView(frame: NSRect(x: 20, y: 115, width: 64, height: 64))
        iconView.image = NSApp.applicationIconImage
        iconView.imageScaling = .scaleProportionallyUpOrDown
        contentView.addSubview(iconView)

        // App name to the right of icon
        let titleLabel = NSTextField(labelWithString: "StepAway")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 18)
        titleLabel.frame = NSRect(x: 100, y: 155, width: 220, height: 22)
        contentView.addSubview(titleLabel)

        // Version
        let versionLabel = NSTextField(labelWithString: "Version 1.0")
        versionLabel.font = NSFont.systemFont(ofSize: 12)
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.frame = NSRect(x: 100, y: 135, width: 220, height: 16)
        contentView.addSubview(versionLabel)

        // Description - below icon, full width
        let descLabel = NSTextField(labelWithString: "A macOS menu bar app that reminds you to take walking breaks.")
        descLabel.font = NSFont.systemFont(ofSize: 11)
        descLabel.textColor = .secondaryLabelColor
        descLabel.frame = NSRect(x: 20, y: 82, width: 300, height: 28)
        descLabel.usesSingleLineMode = false
        descLabel.cell?.wraps = true
        contentView.addSubview(descLabel)

        // Collective attribution - left aligned
        let collectiveLabel = NSTextField(labelWithString: "A product of the")
        collectiveLabel.font = NSFont.systemFont(ofSize: 11)
        collectiveLabel.textColor = .secondaryLabelColor
        collectiveLabel.frame = NSRect(x: 20, y: 55, width: 90, height: 16)
        contentView.addSubview(collectiveLabel)

        let collectiveButton = NSButton(frame: NSRect(x: 106, y: 53, width: 155, height: 20))
        collectiveButton.title = "Apocalyptic Art Collective"
        collectiveButton.bezelStyle = .inline
        collectiveButton.isBordered = false
        collectiveButton.font = NSFont.systemFont(ofSize: 11)
        collectiveButton.contentTintColor = .linkColor
        collectiveButton.target = self
        collectiveButton.action = #selector(openCollective)
        contentView.addSubview(collectiveButton)

        // GitHub link - below collective, left aligned
        let linkButton = NSButton(frame: NSRect(x: 16, y: 35, width: 230, height: 20))
        linkButton.title = "github.com/the-michael-toy/StepAway"
        linkButton.bezelStyle = .inline
        linkButton.isBordered = false
        linkButton.font = NSFont.systemFont(ofSize: 11)
        linkButton.contentTintColor = .linkColor
        linkButton.target = self
        linkButton.action = #selector(openRepo)
        contentView.addSubview(linkButton)

        // OK button
        let okButton = NSButton(frame: NSRect(x: 250, y: 10, width: 70, height: 24))
        okButton.title = "OK"
        okButton.bezelStyle = .rounded
        okButton.target = window
        okButton.action = #selector(NSWindow.close)
        okButton.keyEquivalent = "\r"
        contentView.addSubview(okButton)

        window.contentView = contentView
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
            let launcherAppId = "com.stepaway.launcher"
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

        // Create a simple window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 140),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.title = "StepAway"
        window.center()
        window.isReleasedWhenClosed = false

        // Create the content
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 140))

        // App icon
        let iconView = NSImageView(frame: NSRect(x: 125, y: 85, width: 50, height: 50))
        iconView.image = NSApp.applicationIconImage
        iconView.imageScaling = .scaleProportionallyUpOrDown

        let titleLabel = NSTextField(labelWithString: "Still there?")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 18)
        titleLabel.alignment = .center
        titleLabel.frame = NSRect(x: 20, y: 50, width: 260, height: 30)

        let subtitleLabel = NSTextField(labelWithString: "Move the mouse or press any key.")
        subtitleLabel.font = NSFont.systemFont(ofSize: 13)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.alignment = .center
        subtitleLabel.frame = NSRect(x: 20, y: 25, width: 260, height: 20)

        contentView.addSubview(iconView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        window.contentView = contentView

        // Show the window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        stillThereWindow = window

        // Start 60-second timer
        stillThereTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: false) { [weak self] _ in
            self?.dismissStillThereWindow(userIsPresent: false)
        }
    }

    private func dismissStillThereWindow(userIsPresent: Bool) {
        stillThereTimer?.invalidate()
        stillThereTimer = nil

        stillThereWindow?.close()
        stillThereWindow = nil

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
            if response == .alertSecondButtonReturn {
                // Snooze - set a 5 minute timer
                self.timerManager.snooze(minutes: 5)
            } else {
                // Reset the timer
                self.timerManager.reset()
            }
            self.updateButtonTitle(timeRemaining: self.timerManager.timeRemaining)
        }
    }

    func cleanup() {
        activityMonitor.stopMonitoring()
        timerManager.stop()
    }
}
