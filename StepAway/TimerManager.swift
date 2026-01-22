// SPDX-License-Identifier: CC0-1.0
// This file is part of StepAway - https://github.com/the-michael-toy/StepAway

import Foundation

class TimerManager {
    var onTick: ((TimeInterval) -> Void)?
    var onTimerComplete: (() -> Void)?
    var onStateChange: (() -> Void)?

    private(set) var timeRemaining: TimeInterval
    private(set) var isEnabled: Bool = true
    private(set) var isPaused: Bool = false
    private(set) var wasTrulyAway: Bool = false  // If true, reset on return instead of resume

    private var timerCancellable: Cancellable?
    private let timeProvider: TimeProvider
    private let settingsProvider: () -> (timerInterval: TimeInterval, isEnabled: Bool)

    /// Production initializer - uses real time and AppSettings
    convenience init() {
        self.init(
            timeProvider: RealTimeProvider(),
            settingsProvider: { (AppSettings.shared.timerInterval, AppSettings.shared.isEnabled) }
        )
    }

    /// Testable initializer - allows injecting mock time and settings
    init(timeProvider: TimeProvider, settingsProvider: @escaping () -> (timerInterval: TimeInterval, isEnabled: Bool)) {
        self.timeProvider = timeProvider
        self.settingsProvider = settingsProvider

        let settings = settingsProvider()
        timeRemaining = settings.timerInterval
        isEnabled = settings.isEnabled

        if isEnabled {
            startTimer()
        }
    }

    func startTimer() {
        timerCancellable?.cancel()

        timerCancellable = timeProvider.scheduleTimer(interval: 1.0, repeats: true) { [weak self] in
            self?.tick()
        }
    }

    func stop() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    func reset() {
        timeRemaining = settingsProvider().timerInterval
        isPaused = false
        wasTrulyAway = false
        if isEnabled {
            startTimer()
        }
        onTick?(timeRemaining)
    }

    func snooze(minutes: Int) {
        timeRemaining = TimeInterval(minutes * 60)
        isPaused = false
        if isEnabled {
            startTimer()
        }
        onTick?(timeRemaining)
    }

    func toggleEnabled() {
        setEnabled(!isEnabled)
    }

    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        isEnabled = enabled

        if isEnabled {
            reset()
        } else {
            stop()
        }

        onStateChange?()
    }

    /// Pause because user is truly away (didn't respond to "still there?" prompt)
    func pauseAsTrulyAway() {
        guard isEnabled && !isPaused else { return }
        isPaused = true
        wasTrulyAway = true
        onTick?(timeRemaining)
    }

    func resumeIfNeeded() {
        guard isEnabled && isPaused else { return }

        if wasTrulyAway {
            // User was truly away - reset the timer (they took a break)
            wasTrulyAway = false
            reset()
        } else {
            isPaused = false
            onTick?(timeRemaining)
        }
    }

    private func tick() {
        guard isEnabled && !isPaused else { return }

        timeRemaining -= 1

        if timeRemaining <= 0 {
            timerCancellable?.cancel()
            onTimerComplete?()
        } else {
            onTick?(timeRemaining)
        }
    }
}
