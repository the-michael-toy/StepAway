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
    }

    func startMonitoring() {
        activitySource.startMonitoring()

        // Start the idle check timer - polls every second
        startIdleCheckTimer()
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

    private func checkIdleState() {
        let idleTime = activitySource.getIdleTime()
        let idleThreshold = settingsProvider()

        if isCheckingStillThere {
            // While showing "still there?" dialog, watch for activity
            if idleTime <= 1.0 {
                // Recent activity detected - user is present
                isCheckingStillThere = false
                isIdle = false
                onActivityDetected?()
            }
        } else if isIdle {
            // User was away, check if they returned
            if idleTime <= 1.0 {
                isIdle = false
                onActivityDetected?()
            }
        } else {
            // Normal state - check if user went idle
            if idleTime >= idleThreshold {
                isCheckingStillThere = true
                onIdleCheckNeeded?()
            }
        }
    }

    /// Called when user confirms they're still there
    func userConfirmedPresent() {
        isCheckingStillThere = false
        isIdle = false
    }

    /// Called when user didn't respond - they're truly away
    func userConfirmedAway() {
        isCheckingStillThere = false
        isIdle = true
    }

    /// For testing: simulate activity
    func simulateActivity() {
        // For tests using MockActivitySource, trigger the onActivity callback
        activitySource.onActivity?()
    }
}
