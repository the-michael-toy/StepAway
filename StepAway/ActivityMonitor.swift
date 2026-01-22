// SPDX-License-Identifier: CC0-1.0
// This file is part of StepAway - https://github.com/the-michael-toy/StepAway

import AppKit
import Foundation

class ActivityMonitor {
    var onActivityDetected: (() -> Void)?
    var onIdleCheckNeeded: (() -> Void)?  // Called when idle timeout reached, to show "still there?" dialog

    private var eventMonitor: Any?
    private var idleTimer: Timer?
    private var isIdle = false
    private var isCheckingStillThere = false  // True while "still there?" dialog is shown
    private var lastActivityTime = Date()

    func startMonitoring() {
        // Monitor global events (mouse movement, key presses, etc.)
        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDown, .rightMouseDown, .keyDown, .scrollWheel]
        ) { [weak self] _ in
            self?.activityDetected()
        }

        // Also monitor local events within our app
        NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDown, .rightMouseDown, .keyDown, .scrollWheel]
        ) { [weak self] event in
            self?.activityDetected()
            return event
        }

        // Start the idle check timer
        startIdleCheckTimer()

        // Initial activity
        activityDetected()
    }

    func stopMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        idleTimer?.invalidate()
        idleTimer = nil
    }

    func updateIdleInterval() {
        // Restart the idle check timer with new interval
        startIdleCheckTimer()
    }

    private func startIdleCheckTimer() {
        idleTimer?.invalidate()

        // Check for idle every second
        idleTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkIdleState()
        }
    }

    private func activityDetected() {
        lastActivityTime = Date()

        if isCheckingStillThere {
            // User responded during the "still there?" check - they're present
            isCheckingStillThere = false
            isIdle = false
            onActivityDetected?()
        } else if isIdle {
            isIdle = false
            onActivityDetected?()
        }
    }

    private func checkIdleState() {
        // Don't trigger another check while one is in progress
        guard !isCheckingStillThere else { return }

        let idleTime = Date().timeIntervalSince(lastActivityTime)
        let idleThreshold = AppSettings.shared.idleInterval

        if idleTime >= idleThreshold && !isIdle {
            // Instead of marking idle immediately, trigger the "still there?" check
            isCheckingStillThere = true
            onIdleCheckNeeded?()
        }
    }

    /// Called when user confirms they're still there
    func userConfirmedPresent() {
        isCheckingStillThere = false
        isIdle = false
        lastActivityTime = Date()
    }

    /// Called when user didn't respond - they're truly away
    func userConfirmedAway() {
        isCheckingStillThere = false
        isIdle = true
    }
}
