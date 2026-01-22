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

    private var timer: Timer?

    init() {
        timeRemaining = AppSettings.shared.timerInterval
        isEnabled = AppSettings.shared.isEnabled
        if isEnabled {
            startTimer()
        }
    }

    func startTimer() {
        timer?.invalidate()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func reset() {
        timeRemaining = AppSettings.shared.timerInterval
        isPaused = false
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
            timer?.invalidate()
            onTimerComplete?()
        } else {
            onTick?(timeRemaining)
        }
    }
}
