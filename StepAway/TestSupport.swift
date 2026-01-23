// SPDX-License-Identifier: CC0-1.0
// This file is part of StepAway - https://github.com/the-michael-toy/StepAway

import Foundation
import AppKit

// MARK: - Time Provider Protocol

/// Protocol for time-based operations, allowing tests to control time
protocol TimeProvider {
    var now: Date { get }
    func scheduleTimer(interval: TimeInterval, repeats: Bool, block: @escaping () -> Void) -> Cancellable
}

/// Protocol for cancellable operations (like timers)
protocol Cancellable {
    func cancel()
}

// MARK: - Real Time Provider (Production)

class RealTimeProvider: TimeProvider {
    var now: Date { Date() }

    func scheduleTimer(interval: TimeInterval, repeats: Bool, block: @escaping () -> Void) -> Cancellable {
        let timer = Timer(timeInterval: interval, repeats: repeats) { _ in
            block()
        }
        // Add to .common modes so timer fires during modal dialogs too
        RunLoop.current.add(timer, forMode: .common)
        return TimerCancellable(timer: timer)
    }
}

class TimerCancellable: Cancellable {
    private let timer: Timer

    init(timer: Timer) {
        self.timer = timer
    }

    func cancel() {
        timer.invalidate()
    }
}

// MARK: - Mock Time Provider (Testing)

class MockTimeProvider: TimeProvider {
    private(set) var now: Date
    private var scheduledBlocks: [(fireDate: Date, repeats: Bool, interval: TimeInterval, block: () -> Void, cancelled: Bool)] = []
    private var nextId = 0

    init(startTime: Date = Date()) {
        self.now = startTime
    }

    func scheduleTimer(interval: TimeInterval, repeats: Bool, block: @escaping () -> Void) -> Cancellable {
        let fireDate = now.addingTimeInterval(interval)
        let id = nextId
        nextId += 1
        scheduledBlocks.append((fireDate: fireDate, repeats: repeats, interval: interval, block: block, cancelled: false))
        return MockCancellable { [weak self] in
            if id < self?.scheduledBlocks.count ?? 0 {
                self?.scheduledBlocks[id].cancelled = true
            }
        }
    }

    /// Advance time and fire any timers that should have fired
    func advance(by interval: TimeInterval) {
        let targetTime = now.addingTimeInterval(interval)

        while now < targetTime {
            // Find the next timer to fire
            let pending = scheduledBlocks.enumerated()
                .filter { !$0.element.cancelled && $0.element.fireDate <= targetTime }
                .sorted { $0.element.fireDate < $1.element.fireDate }

            if let next = pending.first {
                now = next.element.fireDate
                next.element.block()

                // Only reschedule if the timer wasn't cancelled inside its callback
                if next.element.repeats && !scheduledBlocks[next.offset].cancelled {
                    // Reschedule
                    scheduledBlocks[next.offset] = (
                        fireDate: now.addingTimeInterval(next.element.interval),
                        repeats: true,
                        interval: next.element.interval,
                        block: next.element.block,
                        cancelled: false
                    )
                } else if !next.element.repeats {
                    scheduledBlocks[next.offset].cancelled = true
                }
            } else {
                now = targetTime
            }
        }
    }
}

class MockCancellable: Cancellable {
    private let onCancel: () -> Void
    private var isCancelled = false

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    func cancel() {
        guard !isCancelled else { return }
        isCancelled = true
        onCancel()
    }
}

// MARK: - Activity Source Protocol

/// Protocol for activity detection, allowing tests to simulate user activity
protocol ActivitySource {
    var onActivity: (() -> Void)? { get set }
    func startMonitoring()
    func stopMonitoring()
    func getIdleTime() -> TimeInterval
}

// MARK: - Real Activity Source (Production)

class RealActivitySource: ActivitySource {
    var onActivity: (() -> Void)?

    func startMonitoring() {
        // No setup needed - we use the system's idle time directly
    }

    func stopMonitoring() {
        // No cleanup needed
    }

    func getIdleTime() -> TimeInterval {
        // Use the system's idle time tracking - this is what macOS uses for
        // screen saver and is more reliable than event monitoring
        let idleTime = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: CGEventType(rawValue: ~0)!  // All event types
        )
        return idleTime
    }
}

// MARK: - Mock Activity Source (Testing)

class MockActivitySource: ActivitySource {
    var onActivity: (() -> Void)?
    private var idleTime: TimeInterval = 0
    private(set) var isMonitoring = false
    private var lastResetTime: Date?
    private weak var timeProvider: MockTimeProvider?

    /// Set the time provider so idle time advances with mock time
    func setTimeProvider(_ provider: MockTimeProvider) {
        self.timeProvider = provider
        self.lastResetTime = provider.now
    }

    func startMonitoring() {
        isMonitoring = true
        lastResetTime = timeProvider?.now ?? Date()
    }

    func stopMonitoring() {
        isMonitoring = false
    }

    func getIdleTime() -> TimeInterval {
        // If we have a time provider, calculate idle time based on mock time
        if let provider = timeProvider, let resetTime = lastResetTime {
            return provider.now.timeIntervalSince(resetTime)
        }
        return idleTime
    }

    /// Simulate user activity - resets idle time to 0
    func simulateActivity() {
        lastResetTime = timeProvider?.now ?? Date()
        idleTime = 0
        onActivity?()
    }

    /// Simulate time passing with no activity (for tests not using MockTimeProvider)
    func simulateIdle(seconds: TimeInterval) {
        idleTime += seconds
    }
}
