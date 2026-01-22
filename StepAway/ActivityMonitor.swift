// SPDX-License-Identifier: CC0-1.0
// This file is part of StepAway - https://github.com/the-michael-toy/StepAway

import AppKit
import Foundation

class ActivityMonitor {
    var onActivityDetected: (() -> Void)?
    var onIdleCheckNeeded: (() -> Void)?  // Called when idle timeout reached, to show "still there?" dialog

    private(set) var isIdle = false
    private(set) var isCheckingStillThere = false  // True while "still there?" dialog is shown

    private var idleTimerCancellable: Cancellable?
    private let timeProvider: TimeProvider
    private var activitySource: ActivitySource
    private let settingsProvider: () -> TimeInterval  // Returns idle interval

    private var lastActivityTime: Date

    /// Production initializer - uses real activity source and AppSettings
    convenience init() {
        self.init(
            timeProvider: RealTimeProvider(),
            activitySource: RealActivitySource(),
            settingsProvider: { AppSettings.shared.idleInterval }
        )
    }

    /// Testable initializer - allows injecting mocks
    init(timeProvider: TimeProvider, activitySource: ActivitySource, settingsProvider: @escaping () -> TimeInterval) {
        self.timeProvider = timeProvider
        self.activitySource = activitySource
        self.settingsProvider = settingsProvider
        self.lastActivityTime = timeProvider.now
    }

    func startMonitoring() {
        // Set up activity source callback
        activitySource.onActivity = { [weak self] in
            self?.activityDetected()
        }
        activitySource.startMonitoring()

        // Start the idle check timer
        startIdleCheckTimer()

        // Initial activity
        activityDetected()
    }

    func stopMonitoring() {
        activitySource.stopMonitoring()
        idleTimerCancellable?.cancel()
        idleTimerCancellable = nil
    }

    func updateIdleInterval() {
        // Restart the idle check timer with new interval
        startIdleCheckTimer()
    }

    private func startIdleCheckTimer() {
        idleTimerCancellable?.cancel()

        // Check for idle every second
        idleTimerCancellable = timeProvider.scheduleTimer(interval: 1.0, repeats: true) { [weak self] in
            self?.checkIdleState()
        }
    }

    private func activityDetected() {
        lastActivityTime = timeProvider.now

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

        let idleTime = timeProvider.now.timeIntervalSince(lastActivityTime)
        let idleThreshold = settingsProvider()

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
        lastActivityTime = timeProvider.now
    }

    /// Called when user didn't respond - they're truly away
    func userConfirmedAway() {
        isCheckingStillThere = false
        isIdle = true
    }

    /// For testing: simulate activity
    func simulateActivity() {
        activityDetected()
    }
}
