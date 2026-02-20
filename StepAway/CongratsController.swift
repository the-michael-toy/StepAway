// SPDX-License-Identifier: CC0-1.0
// This file is part of StepAway - https://github.com/the-michael-toy/StepAway

import AppKit

final class CongratsController {
    private var panel: NSWindow?
    private var progressBar: NSProgressIndicator?
    private var timer: Timer?
    private var progressTimer: Timer?
    private var keyMonitor: Any?
    private var mouseMonitor: Any?
    private var globalMouseMonitor: Any?
    private var activationObserver: NSObjectProtocol?

    var onTimeout: (() -> Void)?

    var isShowing: Bool { panel != nil }

    func show() {
        guard panel == nil else { return }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 160),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.title = "StepAway"
        window.isReleasedWhenClosed = false
        window.level = .modalPanel

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 160))

        // App icon
        let iconView = NSImageView(frame: NSRect(x: 145, y: 100, width: 50, height: 50))
        iconView.image = NSApp.applicationIconImage
        iconView.imageScaling = .scaleProportionallyUpOrDown

        let titleLabel = NSTextField(labelWithString: "Nice! Go take your walk.")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 18)
        titleLabel.alignment = .center
        titleLabel.frame = NSRect(x: 20, y: 65, width: 300, height: 30)

        // Progress bar (fills over 60 seconds)
        let bar = NSProgressIndicator(frame: NSRect(x: 20, y: 50, width: 300, height: 6))
        bar.style = .bar
        bar.isIndeterminate = false
        bar.minValue = 0
        bar.maxValue = 60
        bar.doubleValue = 0
        progressBar = bar

        let subtitleLabel = NSTextField(labelWithString: "See you when you get back.")
        subtitleLabel.font = NSFont.systemFont(ofSize: 13)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.alignment = .center
        subtitleLabel.frame = NSRect(x: 20, y: 22, width: 300, height: 20)

        contentView.addSubview(iconView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(bar)
        contentView.addSubview(subtitleLabel)
        window.contentView = contentView

        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        panel = window

        // Intercept keystrokes: beep and swallow everything.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard self?.panel != nil else { return event }
            NSSound.beep()
            return nil
        }

        // Intercept all mouse clicks outside the panel: beep and swallow.
        // No menu bar exception — nothing should interrupt the congrats modal.
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let panel = self?.panel else { return event }
            if panel == event.window {
                return event
            }
            NSSound.beep()
            return nil
        }

        // Intercept all clicks in other apps: beep and yank focus back.
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, let panel = self.panel else { return }
            NSSound.beep()
            DispatchQueue.main.async {
                panel.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }

        // Re-activate the panel whenever another app steals focus
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self, let panel = self.panel else { return }
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
               app.bundleIdentifier != Bundle.main.bundleIdentifier {
                panel.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }

        // 60-second auto-dismiss timer
        timer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: false) { [weak self] _ in
            self?.onTimeout?()
        }

        // Update progress bar smoothly (10 times per second)
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            if let bar = self?.progressBar {
                bar.doubleValue += 0.1
            }
        }
    }

    func dismiss() {
        timer?.invalidate()
        timer = nil
        progressTimer?.invalidate()
        progressTimer = nil
        progressBar = nil

        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseMonitor = nil
        }
        if let observer = activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            activationObserver = nil
        }

        panel?.close()
        panel = nil
    }
}
