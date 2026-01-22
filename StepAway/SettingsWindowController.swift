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

    private var timerSlider: NSSlider!
    private var timerLabel: NSTextField!
    private var idleSlider: NSSlider!
    private var idleLabel: NSTextField!
    private var enabledCheckbox: NSButton!

    var onSettingsChanged: (() -> Void)?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "StepAway Settings"
        window.center()
        window.isReleasedWhenClosed = false

        self.init(window: window)
        setupUI()
        loadSettings()
    }

    private func setupUI() {
        guard let window = window else { return }

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]

        // Enabled checkbox
        enabledCheckbox = NSButton(checkboxWithTitle: "Enable StepAway", target: self, action: #selector(enabledChanged))
        enabledCheckbox.frame = NSRect(x: 20, y: 155, width: 250, height: 20)
        contentView.addSubview(enabledCheckbox)

        // Timer interval section
        let timerTitleLabel = NSTextField(labelWithString: "Reminder interval:")
        timerTitleLabel.frame = NSRect(x: 20, y: 120, width: 120, height: 17)
        contentView.addSubview(timerTitleLabel)

        timerLabel = NSTextField(labelWithString: "90 minutes")
        timerLabel.frame = NSRect(x: 300, y: 120, width: 80, height: 17)
        timerLabel.alignment = .right
        contentView.addSubview(timerLabel)

        timerSlider = NSSlider(value: 0, minValue: 0, maxValue: Double(timeStops.count - 1), target: self, action: #selector(timerSliderChanged))
        timerSlider.frame = NSRect(x: 20, y: 95, width: 360, height: 21)
        timerSlider.numberOfTickMarks = timeStops.count
        timerSlider.allowsTickMarkValuesOnly = true
        timerSlider.tickMarkPosition = .below
        contentView.addSubview(timerSlider)

        // Idle timeout section
        let idleTitleLabel = NSTextField(labelWithString: "Idle timeout:")
        idleTitleLabel.frame = NSRect(x: 20, y: 55, width: 120, height: 17)
        contentView.addSubview(idleTitleLabel)

        idleLabel = NSTextField(labelWithString: "3 minutes")
        idleLabel.frame = NSRect(x: 300, y: 55, width: 80, height: 17)
        idleLabel.alignment = .right
        contentView.addSubview(idleLabel)

        idleSlider = NSSlider(value: 0, minValue: 0, maxValue: Double(timeStops.count - 1), target: self, action: #selector(idleSliderChanged))
        idleSlider.frame = NSRect(x: 20, y: 30, width: 360, height: 21)
        idleSlider.numberOfTickMarks = timeStops.count
        idleSlider.allowsTickMarkValuesOnly = true
        idleSlider.tickMarkPosition = .below
        contentView.addSubview(idleSlider)

        window.contentView = contentView
    }

    private func loadSettings() {
        enabledCheckbox.state = AppSettings.shared.isEnabled ? .on : .off

        let timerIndex = indexForTime(AppSettings.shared.timerInterval)
        timerSlider.integerValue = timerIndex
        timerLabel.stringValue = formatTime(timeStops[timerIndex])

        let idleIndex = indexForTime(AppSettings.shared.idleInterval)
        idleSlider.integerValue = idleIndex
        idleLabel.stringValue = formatTime(timeStops[idleIndex])

        updateControlsEnabled()
    }

    private func indexForTime(_ time: TimeInterval) -> Int {
        // Find closest matching index
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
    }

    @objc private func enabledChanged() {
        let enabled = enabledCheckbox.state == .on
        AppSettings.shared.isEnabled = enabled
        updateControlsEnabled()
        onSettingsChanged?()
    }

    @objc private func timerSliderChanged() {
        let index = timerSlider.integerValue
        let time = timeStops[index]
        timerLabel.stringValue = formatTime(time)
        AppSettings.shared.timerInterval = time
        onSettingsChanged?()
    }

    @objc private func idleSliderChanged() {
        let index = idleSlider.integerValue
        let time = timeStops[index]
        idleLabel.stringValue = formatTime(time)
        AppSettings.shared.idleInterval = time
        onSettingsChanged?()
    }

    func showWindow() {
        loadSettings()
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
