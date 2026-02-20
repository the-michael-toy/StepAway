// SPDX-License-Identifier: CC0-1.0
// This file is part of StepAway - https://github.com/the-michael-toy/StepAway

import AppKit

final class WalkAlertController {
    private var walkAlertPanel: NSWindow?
    private var keyMonitor: Any?
    private var mouseMonitor: Any?
    private var globalMouseMonitor: Any?
    private var activationObserver: NSObjectProtocol?

    var onFiveMoreMinutes: (() -> Void)?
    var onLastTaskThenBreak: (() -> Void)?

    var isShowing: Bool { walkAlertPanel != nil }

    func show() {
        guard walkAlertPanel == nil else { return }

        let alert = NSAlert()
        alert.messageText = "Time to Step Away!"
        alert.informativeText = "Choose \"Last task, then break\" to pause reminders until you take a break and return."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "5 more minutes")
        alert.addButton(withTitle: "Last task, then break")

        alert.buttons[0].target = self
        alert.buttons[0].action = #selector(fiveMoreMinutesTapped)
        alert.buttons[1].target = self
        alert.buttons[1].action = #selector(lastTaskTapped)

        alert.layout()

        let panel = alert.window
        panel.level = .modalPanel
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        walkAlertPanel = panel

        // Intercept keystrokes: let the panel handle its button key equivalents
        // (Return for "5 more minutes"), beep and swallow everything else.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let panel = self?.walkAlertPanel else { return event }
            if panel.performKeyEquivalent(with: event) {
                return nil
            }
            NSSound.beep()
            return nil
        }

        // Intercept mouse clicks outside the alert panel: beep and swallow.
        // Exception: clicks in the menu bar area pass through so the coordinator's
        // menuOpened deferral works.
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let panel = self?.walkAlertPanel else { return event }
            let clickLocation = event.locationInWindow
            let clickScreenLocation: NSPoint
            if let eventWindow = event.window {
                clickScreenLocation = eventWindow.convertPoint(toScreen: clickLocation)
            } else {
                clickScreenLocation = clickLocation
            }
            // Allow clicks inside the alert panel
            if panel == event.window {
                return event
            }
            // Allow clicks in the menu bar area (top 24 points of any screen)
            for screen in NSScreen.screens {
                let menuBarRect = NSRect(
                    x: screen.frame.minX,
                    y: screen.frame.maxY - 24,
                    width: screen.frame.width,
                    height: 24
                )
                if menuBarRect.contains(clickScreenLocation) {
                    return event
                }
            }
            NSSound.beep()
            return nil
        }

        // Intercept mouse clicks in OTHER apps: beep and yank focus back.
        // Global monitors cannot swallow events, but we re-activate our panel
        // so the user is immediately pulled back to the alert.
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, let panel = self.walkAlertPanel else { return }
            // Allow clicks in the menu bar area (top 24 points of any screen)
            let clickScreenLocation = event.locationInWindow
            for screen in NSScreen.screens {
                let menuBarRect = NSRect(
                    x: screen.frame.minX,
                    y: screen.frame.maxY - 24,
                    width: screen.frame.width,
                    height: 24
                )
                if menuBarRect.contains(clickScreenLocation) {
                    return
                }
            }
            NSSound.beep()
            DispatchQueue.main.async {
                panel.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }

        // Re-activate the panel whenever ANOTHER app steals focus
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self, let panel = self.walkAlertPanel else { return }
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
               app.bundleIdentifier != Bundle.main.bundleIdentifier {
                panel.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    func dismiss() {
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
        walkAlertPanel?.close()
        walkAlertPanel = nil
    }

    @objc private func fiveMoreMinutesTapped() {
        onFiveMoreMinutes?()
    }

    @objc private func lastTaskTapped() {
        onLastTaskThenBreak?()
    }
}
