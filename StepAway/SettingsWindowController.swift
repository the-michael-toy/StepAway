// SPDX-License-Identifier: CC0-1.0
// This file is part of StepAway - https://github.com/the-michael-toy/StepAway

import AppKit

class SettingsWindowController: NSWindowController {

    // Discrete time values in seconds: 30s, 5m, 10m, 15m, 30m, 60m, 90m, 120m, 150m, 180m
    private let timeStops: [TimeInterval] = [
        30,      // 30 seconds (testing)
        300,     // 5 minutes
        600,     // 10 minutes
        900,     // 15 minutes
        1800,    // 30 minutes
        3600,    // 60 minutes
        5400,    // 90 minutes
        7200,    // 120 minutes
        9000,    // 150 minutes
        10800    // 180 minutes
    ]

    private var enabledCheckbox: NSButton!
    private var timerSlider: NSSlider!
    private var timerLabel: NSTextField!
    private var idleSlider: NSSlider!
    private var idleLabel: NSTextField!
    private var stillThereCheckbox: NSButton!
    private var playSoundCheckbox: NSButton!
    private var soundPopup: NSPopUpButton!
    private var testSoundButton: NSButton!

    private var availableSounds: [String] = []

    var onSettingsChanged: (() -> Void)?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 330),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "StepAway Settings"
        window.center()
        window.isReleasedWhenClosed = false

        self.init(window: window)
        loadAvailableSounds()
        setupUI()
        loadSettings()
    }

    private func loadAvailableSounds() {
        let soundsPath = "/System/Library/Sounds"
        if let files = try? FileManager.default.contentsOfDirectory(atPath: soundsPath) {
            availableSounds = files
                .filter { $0.hasSuffix(".aiff") }
                .map { $0.replacingOccurrences(of: ".aiff", with: "") }
                .sorted()
        }
        if availableSounds.isEmpty {
            availableSounds = ["Glass"] // Fallback
        }
    }

    private func setupUI() {
        guard let window = window else { return }

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]

        var y: CGFloat = 290

        // Enabled checkbox
        enabledCheckbox = NSButton(checkboxWithTitle: "Enable StepAway", target: self, action: #selector(enabledChanged))
        enabledCheckbox.frame = NSRect(x: 20, y: y, width: 250, height: 20)
        contentView.addSubview(enabledCheckbox)

        // --- Reminder interval section ---
        y -= 40

        let timerTitleLabel = NSTextField(labelWithString: "Reminder interval:")
        timerTitleLabel.frame = NSRect(x: 20, y: y, width: 120, height: 17)
        contentView.addSubview(timerTitleLabel)

        let timerHelpButton = createHelpButton(
            tooltip: "Remind me to walk away if I have been active for this long in one sitting."
        )
        timerHelpButton.frame = NSRect(x: 142, y: y - 2, width: 20, height: 20)
        contentView.addSubview(timerHelpButton)

        timerLabel = NSTextField(labelWithString: "90 minutes")
        timerLabel.frame = NSRect(x: 300, y: y, width: 100, height: 17)
        timerLabel.alignment = .right
        contentView.addSubview(timerLabel)

        y -= 25

        timerSlider = NSSlider(value: 0, minValue: 0, maxValue: Double(timeStops.count - 1), target: self, action: #selector(timerSliderChanged))
        timerSlider.frame = NSRect(x: 20, y: y, width: 380, height: 21)
        timerSlider.numberOfTickMarks = timeStops.count
        timerSlider.allowsTickMarkValuesOnly = true
        timerSlider.tickMarkPosition = .below
        contentView.addSubview(timerSlider)

        // --- Idle timeout section ---
        y -= 45

        let idleTitleLabel = NSTextField(labelWithString: "Idle timeout:")
        idleTitleLabel.frame = NSRect(x: 20, y: y, width: 90, height: 17)
        contentView.addSubview(idleTitleLabel)

        let idleHelpButton = createHelpButton(
            tooltip: "Assume I've walked away if I am idle for this long."
        )
        idleHelpButton.frame = NSRect(x: 112, y: y - 2, width: 20, height: 20)
        contentView.addSubview(idleHelpButton)

        idleLabel = NSTextField(labelWithString: "3 minutes")
        idleLabel.frame = NSRect(x: 300, y: y, width: 100, height: 17)
        idleLabel.alignment = .right
        contentView.addSubview(idleLabel)

        y -= 25

        idleSlider = NSSlider(value: 0, minValue: 0, maxValue: Double(timeStops.count - 1), target: self, action: #selector(idleSliderChanged))
        idleSlider.frame = NSRect(x: 20, y: y, width: 380, height: 21)
        idleSlider.numberOfTickMarks = timeStops.count
        idleSlider.allowsTickMarkValuesOnly = true
        idleSlider.tickMarkPosition = .below
        contentView.addSubview(idleSlider)

        // --- Still there dialog section ---
        y -= 40

        stillThereCheckbox = NSButton(
            checkboxWithTitle: "Confirm I'm away before pausing the timer",
            target: self,
            action: #selector(stillThereChanged)
        )
        stillThereCheckbox.frame = NSRect(x: 20, y: y, width: 350, height: 20)
        contentView.addSubview(stillThereCheckbox)

        let stillThereHelpButton = createHelpButton(
            tooltip: "Shows a 'Still there?' prompt when idle. If you don't respond within 60 seconds, the timer pauses assuming you've stepped away."
        )
        stillThereHelpButton.frame = NSRect(x: 370, y: y - 2, width: 20, height: 20)
        contentView.addSubview(stillThereHelpButton)

        y -= 28

        playSoundCheckbox = NSButton(
            checkboxWithTitle: "Play warning sound before prompt dismisses",
            target: self,
            action: #selector(playSoundChanged)
        )
        playSoundCheckbox.frame = NSRect(x: 40, y: y, width: 300, height: 20)
        contentView.addSubview(playSoundCheckbox)

        y -= 30

        let soundLabel = NSTextField(labelWithString: "Sound:")
        soundLabel.frame = NSRect(x: 40, y: y + 2, width: 50, height: 17)
        contentView.addSubview(soundLabel)

        soundPopup = NSPopUpButton(frame: NSRect(x: 95, y: y, width: 150, height: 25), pullsDown: false)
        soundPopup.addItems(withTitles: availableSounds)
        soundPopup.target = self
        soundPopup.action = #selector(soundChanged)
        contentView.addSubview(soundPopup)

        testSoundButton = NSButton(frame: NSRect(x: 255, y: y, width: 60, height: 25))
        testSoundButton.title = "Test"
        testSoundButton.bezelStyle = .rounded
        testSoundButton.target = self
        testSoundButton.action = #selector(testSound)
        contentView.addSubview(testSoundButton)

        window.contentView = contentView
    }

    private func createHelpButton(tooltip: String) -> NSButton {
        let button = NSButton(frame: .zero)
        button.title = "?"
        button.bezelStyle = .circular
        button.font = NSFont.systemFont(ofSize: 10)
        button.toolTip = tooltip
        button.target = self
        button.action = #selector(helpButtonClicked(_:))
        return button
    }

    @objc private func helpButtonClicked(_ sender: NSButton) {
        if let tooltip = sender.toolTip {
            let alert = NSAlert()
            alert.messageText = "Help"
            alert.informativeText = tooltip
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    private func loadSettings() {
        enabledCheckbox.state = AppSettings.shared.isEnabled ? .on : .off

        let timerIndex = indexForTime(AppSettings.shared.timerInterval)
        timerSlider.integerValue = timerIndex
        timerLabel.stringValue = formatTime(timeStops[timerIndex])

        let idleIndex = indexForTime(AppSettings.shared.idleInterval)
        idleSlider.integerValue = idleIndex
        idleLabel.stringValue = formatTime(timeStops[idleIndex])

        stillThereCheckbox.state = AppSettings.shared.showStillThereDialog ? .on : .off
        playSoundCheckbox.state = AppSettings.shared.playWarningSound ? .on : .off

        // Select the saved sound, or default to Glass
        let savedSound = AppSettings.shared.warningSound
        if let index = availableSounds.firstIndex(of: savedSound) {
            soundPopup.selectItem(at: index)
        } else if let index = availableSounds.firstIndex(of: "Glass") {
            soundPopup.selectItem(at: index)
        }

        updateControlsEnabled()
    }

    private func indexForTime(_ time: TimeInterval) -> Int {
        var closestIndex = 0
        var closestDiff = abs(timeStops[0] - time)
        for (index, stop) in timeStops.enumerated() {
            let diff = abs(stop - time)
            if diff < closestDiff {
                closestDiff = diff
                closestIndex = index
            }
        }
        return closestIndex
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return "\(Int(seconds)) seconds"
        } else {
            let minutes = Int(seconds / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        }
    }

    private func updateControlsEnabled() {
        let enabled = enabledCheckbox.state == .on
        timerSlider.isEnabled = enabled
        idleSlider.isEnabled = enabled
        stillThereCheckbox.isEnabled = enabled

        let stillThereEnabled = enabled && stillThereCheckbox.state == .on
        playSoundCheckbox.isEnabled = stillThereEnabled

        let soundEnabled = stillThereEnabled && playSoundCheckbox.state == .on
        soundPopup.isEnabled = soundEnabled
        testSoundButton.isEnabled = soundEnabled
    }

    @objc private func enabledChanged() {
        AppSettings.shared.isEnabled = enabledCheckbox.state == .on
        updateControlsEnabled()
        onSettingsChanged?()
    }

    @objc private func timerSliderChanged() {
        let index = timerSlider.integerValue
        let time = timeStops[index]
        timerLabel.stringValue = formatTime(time)
        AppSettings.shared.timerInterval = time

        // If reminder interval drops below idle timeout, pull idle timeout down
        if idleSlider.integerValue > index {
            idleSlider.integerValue = index
            idleLabel.stringValue = formatTime(timeStops[index])
            AppSettings.shared.idleInterval = timeStops[index]
        }

        onSettingsChanged?()
    }

    @objc private func idleSliderChanged() {
        let index = idleSlider.integerValue
        let time = timeStops[index]
        idleLabel.stringValue = formatTime(time)
        AppSettings.shared.idleInterval = time

        // If idle timeout exceeds reminder interval, push reminder interval up
        if timerSlider.integerValue < index {
            timerSlider.integerValue = index
            timerLabel.stringValue = formatTime(timeStops[index])
            AppSettings.shared.timerInterval = timeStops[index]
        }

        onSettingsChanged?()
    }

    @objc private func stillThereChanged() {
        AppSettings.shared.showStillThereDialog = stillThereCheckbox.state == .on
        updateControlsEnabled()
        onSettingsChanged?()
    }

    @objc private func playSoundChanged() {
        AppSettings.shared.playWarningSound = playSoundCheckbox.state == .on
        updateControlsEnabled()
        onSettingsChanged?()
    }

    @objc private func soundChanged() {
        if let selectedSound = soundPopup.selectedItem?.title {
            AppSettings.shared.warningSound = selectedSound
        }
    }

    @objc private func testSound() {
        if let selectedSound = soundPopup.selectedItem?.title {
            NSSound(named: NSSound.Name(selectedSound))?.play()
        }
    }

    func showWindow() {
        loadSettings()
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
