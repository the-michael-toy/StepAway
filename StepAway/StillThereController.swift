// SPDX-License-Identifier: CC0-1.0
// This file is part of StepAway - https://github.com/the-michael-toy/StepAway

import AppKit

final class StillThereController {
    private var stillThereWindow: NSWindow?
    private var stillThereTimer: Timer?
    private var stillThereWarningTimer: Timer?
    private var stillThereProgressTimer: Timer?
    private var stillThereProgressBar: NSProgressIndicator?
    private var previousActiveApp: NSRunningApplication?

    var onTimeout: (() -> Void)?

    func show() {
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
            self?.onTimeout?()
        }

        // Update progress bar smoothly (10 times per second)
        stillThereProgressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            if let progressBar = self?.stillThereProgressBar {
                progressBar.doubleValue += 0.1
            }
        }
    }

    func dismiss() {
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
}
