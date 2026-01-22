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
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: repeats) { _ in
            block()
        }
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
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var lastActivityTime = Date()

    func startMonitoring() {
        lastActivityTime = Date()

        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDown, .rightMouseDown, .keyDown, .scrollWheel]
        ) { [weak self] _ in
            self?.activityDetected()
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDown, .rightMouseDown, .keyDown, .scrollWheel]
        ) { [weak self] event in
            self?.activityDetected()
            return event
        }
    }

    func stopMonitoring() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    func getIdleTime() -> TimeInterval {
        return Date().timeIntervalSince(lastActivityTime)
    }

    private func activityDetected() {
        lastActivityTime = Date()
        onActivity?()
    }
}

// MARK: - Mock Activity Source (Testing)

class MockActivitySource: ActivitySource {
    var onActivity: (() -> Void)?
    private var idleTime: TimeInterval = 0
    private(set) var isMonitoring = false

    func startMonitoring() {
        isMonitoring = true
        idleTime = 0
    }

    func stopMonitoring() {
        isMonitoring = false
    }

    func getIdleTime() -> TimeInterval {
        return idleTime
    }

    /// Simulate user activity
    func simulateActivity() {
        idleTime = 0
        onActivity?()
    }

    /// Simulate time passing with no activity
    func simulateIdle(seconds: TimeInterval) {
        idleTime += seconds
    }
}
