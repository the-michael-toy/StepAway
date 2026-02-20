// SPDX-License-Identifier: CC0-1.0
// This file is part of StepAway - https://github.com/the-michael-toy/StepAway

import Testing
import Foundation
@testable import StepAway

struct StepAwayTests {

    // MARK: - AppCoordinator state machine

    @Test func lastTaskThenBreakRequiresAwayReturnCycle() {
        let coordinator = AppCoordinator(isEnabled: true)

        let toAlertEffects = coordinator.transition(.timerReachedZero)
        #expect(coordinator.state == .walkAlert)
        #expect(toAlertEffects == [.showWalkAlert])

        let lastTaskEffects = coordinator.transition(.alertActionLastTaskThenBreak)
        #expect(coordinator.state == .pausedUntilBreak)
        #expect(lastTaskEffects == [.dismissWalkAlert, .pauseUntilBreak])

        let activityEffects = coordinator.transition(.activityDetected)
        #expect(coordinator.state == .pausedUntilBreak)
        #expect(activityEffects.isEmpty, "Activity should be ignored until an away cycle happens")

        let idleEffects = coordinator.transition(.idleThresholdReached(showStillThereDialog: true))
        #expect(coordinator.state == .confirmingPresence(previous: .pausedUntilBreak, pendingWalkAlert: false))
        #expect(idleEffects == [.showStillThere])

        let toAwayEffects = coordinator.transition(.stillThereTimeout)
        #expect(coordinator.state == .away)
        #expect(toAwayEffects == [.dismissStillThere, .markAwayAndPause])

        let returnEffects = coordinator.transition(.activityDetected)
        #expect(coordinator.state == .running)
        #expect(returnEffects == [.markPresent, .resetTimer])
    }

    @Test func walkAlertIsDeferredWhileStillThereDialogIsActive() {
        let coordinator = AppCoordinator(isEnabled: true)

        let toPresenceCheckEffects = coordinator.transition(.idleThresholdReached(showStillThereDialog: true))
        #expect(coordinator.state == .confirmingPresence(previous: .running, pendingWalkAlert: false))
        #expect(toPresenceCheckEffects == [.showStillThere])

        let deferredEffects = coordinator.transition(.timerReachedZero)
        #expect(coordinator.state == .confirmingPresence(previous: .running, pendingWalkAlert: true))
        #expect(deferredEffects.isEmpty)

        let activityEffects = coordinator.transition(.activityDetected)
        #expect(coordinator.state == .walkAlert)
        #expect(activityEffects == [.dismissStillThere, .markPresent, .showWalkAlert])
    }

    @Test func fiveMoreMinutesTransitionsToSnoozed() {
        let coordinator = AppCoordinator(isEnabled: true)
        _ = coordinator.transition(.timerReachedZero)

        let snoozeEffects = coordinator.transition(.alertActionFiveMoreMinutes)

        #expect(coordinator.state == .snoozed)
        #expect(snoozeEffects == [.dismissWalkAlert, .setSnooze(minutes: 5)])
    }

    @Test func disableThenEnableTransitionsBackToRunning() {
        let coordinator = AppCoordinator(isEnabled: true)

        let disableEffects = coordinator.transition(.disableRequested)
        #expect(coordinator.state == .disabled)
        #expect(disableEffects == [.dismissWalkAlert, .dismissStillThere, .dismissCongrats, .disableTimer, .markPresent])

        let enableEffects = coordinator.transition(.enableRequested)
        #expect(coordinator.state == .running)
        #expect(enableEffects == [.enableTimer, .markPresent, .resetTimer])
    }

    @Test func gettingUpToWalkTransitionsToAwayWithCongrats() {
        let coordinator = AppCoordinator(isEnabled: true)
        _ = coordinator.transition(.timerReachedZero)
        #expect(coordinator.state == .walkAlert)

        let effects = coordinator.transition(.alertActionGettingUpToWalk)
        #expect(coordinator.state == .away)
        #expect(coordinator.isCongratsShowing)
        #expect(effects == [.dismissWalkAlert, .showCongrats, .markAwayAndPause])
    }

    @Test func activityIgnoredWhileCongratsShowing() {
        let coordinator = AppCoordinator(isEnabled: true)
        _ = coordinator.transition(.timerReachedZero)
        _ = coordinator.transition(.alertActionGettingUpToWalk)
        #expect(coordinator.state == .away)
        #expect(coordinator.isCongratsShowing)

        let effects = coordinator.transition(.activityDetected)
        #expect(coordinator.state == .away, "Activity should be ignored while congrats is showing")
        #expect(effects.isEmpty)
        #expect(coordinator.isCongratsShowing)
    }

    @Test func congratsTimedOutClearsFlagAndDismisses() {
        let coordinator = AppCoordinator(isEnabled: true)
        _ = coordinator.transition(.timerReachedZero)
        _ = coordinator.transition(.alertActionGettingUpToWalk)

        let effects = coordinator.transition(.congratsTimedOut)
        #expect(!coordinator.isCongratsShowing)
        #expect(coordinator.state == .away)
        #expect(effects == [.dismissCongrats])

        // Now activity should work normally
        let returnEffects = coordinator.transition(.activityDetected)
        #expect(coordinator.state == .running)
        #expect(returnEffects == [.markPresent, .resetTimer])
    }

    @Test func resetDuringCongratsClearsCongratsFlag() {
        let coordinator = AppCoordinator(isEnabled: true)
        _ = coordinator.transition(.timerReachedZero)
        _ = coordinator.transition(.alertActionGettingUpToWalk)
        #expect(coordinator.isCongratsShowing)

        let effects = coordinator.transition(.resetRequested)
        #expect(coordinator.state == .running)
        #expect(!coordinator.isCongratsShowing)
        #expect(effects.contains(.dismissCongrats))
        #expect(effects.contains(.resetTimer))
    }

    // MARK: - Test 1: Walk reminder appears after timer expires with activity

    @Test func walkReminderAppearsAfterTimerExpires() {
        // Setup
        let mockTime = MockTimeProvider()
        let timerInterval: TimeInterval = 5.0  // 5 seconds for testing

        let timerManager = TimerManager(
            timeProvider: mockTime,
            settingsProvider: { (timerInterval, true) }
        )

        var timerCompletedCalled = false
        timerManager.onTimerComplete = {
            timerCompletedCalled = true
        }

        // Act: Advance time by 5 seconds (timer should complete)
        mockTime.advance(by: 5.0)

        // Assert
        #expect(timerCompletedCalled, "Timer complete callback should be called after timer expires")
        #expect(timerManager.timeRemaining <= 0, "Time remaining should be 0 or less")
    }

    @Test func walkReminderDoesNotAppearBeforeTimerExpires() {
        // Setup
        let mockTime = MockTimeProvider()
        let timerInterval: TimeInterval = 10.0

        let timerManager = TimerManager(
            timeProvider: mockTime,
            settingsProvider: { (timerInterval, true) }
        )

        var timerCompletedCalled = false
        timerManager.onTimerComplete = {
            timerCompletedCalled = true
        }

        // Act: Advance time by only 5 seconds (timer should NOT complete)
        mockTime.advance(by: 5.0)

        // Assert
        #expect(!timerCompletedCalled, "Timer complete callback should NOT be called before timer expires")
        #expect(timerManager.timeRemaining == 5.0, "Time remaining should be 5 seconds")
    }

    // MARK: - Test 2: Still there dialog appears with inactivity

    @Test func stillThereDialogAppearsAfterIdleTimeout() {
        // Setup
        let mockTime = MockTimeProvider()
        let mockActivity = MockActivitySource()
        mockActivity.setTimeProvider(mockTime)
        let idleInterval: TimeInterval = 3.0  // 3 seconds for testing

        let activityMonitor = ActivityMonitor(
            timeProvider: mockTime,
            activitySource: mockActivity,
            settingsProvider: { idleInterval }
        )

        var idleCheckNeededCalled = false
        activityMonitor.onIdleCheckNeeded = {
            idleCheckNeededCalled = true
        }

        activityMonitor.startMonitoring()

        // Act: Advance time by 4 seconds with no activity
        mockTime.advance(by: 4.0)

        // Assert
        #expect(idleCheckNeededCalled, "Idle check callback should be called after idle timeout")
        #expect(activityMonitor.isCheckingStillThere, "Should be in 'checking still there' state")
    }

    @Test func stillThereDialogDoesNotAppearWithActivity() {
        // Setup
        let mockTime = MockTimeProvider()
        let mockActivity = MockActivitySource()
        mockActivity.setTimeProvider(mockTime)
        let idleInterval: TimeInterval = 3.0

        let activityMonitor = ActivityMonitor(
            timeProvider: mockTime,
            activitySource: mockActivity,
            settingsProvider: { idleInterval }
        )

        var idleCheckNeededCalled = false
        activityMonitor.onIdleCheckNeeded = {
            idleCheckNeededCalled = true
        }

        activityMonitor.startMonitoring()

        // Act: Advance 1 second, simulate activity, advance 1 second, simulate activity, etc.
        mockTime.advance(by: 1.0)
        mockActivity.simulateActivity()
        mockTime.advance(by: 1.0)
        mockActivity.simulateActivity()
        mockTime.advance(by: 1.0)
        mockActivity.simulateActivity()
        mockTime.advance(by: 1.0)

        // Assert
        #expect(!idleCheckNeededCalled, "Idle check callback should NOT be called when there is activity")
    }

    // MARK: - Test 3: Activity dismisses still there dialog

    @Test func activityDismissesStillThereState() {
        // Setup
        let mockTime = MockTimeProvider()
        let mockActivity = MockActivitySource()
        mockActivity.setTimeProvider(mockTime)
        let idleInterval: TimeInterval = 3.0

        let activityMonitor = ActivityMonitor(
            timeProvider: mockTime,
            activitySource: mockActivity,
            settingsProvider: { idleInterval }
        )

        var activityDetectedCalled = false
        activityMonitor.onActivityDetected = {
            activityDetectedCalled = true
        }

        activityMonitor.startMonitoring()

        // First, get into idle check state
        mockTime.advance(by: 4.0)
        #expect(activityMonitor.isCheckingStillThere, "Should be in 'checking still there' state")

        // Act: Simulate activity while in "still there" state
        mockActivity.simulateActivity()
        // Advance enough for the polling timer to fire and detect the activity
        mockTime.advance(by: 1.0)

        // Assert
        #expect(activityDetectedCalled, "Activity detected callback should be called")
        #expect(!activityMonitor.isCheckingStillThere, "Should no longer be in 'checking still there' state")
        #expect(!activityMonitor.isIdle, "Should not be marked as idle")
    }

    // MARK: - Test 4: Changing settings works

    @Test func changingTimerIntervalWorks() {
        // Setup
        let mockTime = MockTimeProvider()
        var timerInterval: TimeInterval = 10.0

        let timerManager = TimerManager(
            timeProvider: mockTime,
            settingsProvider: { (timerInterval, true) }
        )

        #expect(timerManager.timeRemaining == 10.0)

        // Act: Change the interval and reset
        timerInterval = 5.0
        timerManager.reset()

        // Assert
        #expect(timerManager.timeRemaining == 5.0, "Timer should use new interval after reset")
    }

    @Test func changingIdleIntervalWorks() {
        // Setup
        let mockTime = MockTimeProvider()
        let mockActivity = MockActivitySource()
        mockActivity.setTimeProvider(mockTime)
        var idleInterval: TimeInterval = 10.0  // 10 seconds - long

        let activityMonitor = ActivityMonitor(
            timeProvider: mockTime,
            activitySource: mockActivity,
            settingsProvider: { idleInterval }
        )

        var idleCheckNeededCalled = false
        activityMonitor.onIdleCheckNeeded = {
            idleCheckNeededCalled = true
        }

        activityMonitor.startMonitoring()

        // Advance 5 seconds - should NOT trigger with 10 second threshold
        mockTime.advance(by: 5.0)
        #expect(!idleCheckNeededCalled, "Should not trigger idle check before threshold")

        // Act: Change idle interval to 3 seconds and trigger activity to reset
        idleInterval = 3.0
        mockActivity.simulateActivity()

        // Now wait 4 seconds - should trigger with new 3 second threshold
        mockTime.advance(by: 4.0)

        // Assert
        #expect(idleCheckNeededCalled, "Should trigger idle check with new shorter threshold")
    }

    // MARK: - Additional Edge Case Tests

    @Test func timerPausesWhenUserAway() {
        // Setup
        let mockTime = MockTimeProvider()
        let timerInterval: TimeInterval = 10.0

        let timerManager = TimerManager(
            timeProvider: mockTime,
            settingsProvider: { (timerInterval, true) }
        )

        // Advance 5 seconds
        mockTime.advance(by: 5.0)
        #expect(timerManager.timeRemaining == 5.0)

        // Act: Pause as truly away
        timerManager.pauseAsTrulyAway()

        // Advance more time - timer should NOT count down
        mockTime.advance(by: 10.0)

        // Assert
        #expect(timerManager.timeRemaining == 5.0, "Timer should be paused")
        #expect(timerManager.isPaused)
        #expect(timerManager.wasTrulyAway)
    }

    @Test func timerResetsWhenUserReturnsFromAway() {
        // Setup
        let mockTime = MockTimeProvider()
        let timerInterval: TimeInterval = 10.0

        let timerManager = TimerManager(
            timeProvider: mockTime,
            settingsProvider: { (timerInterval, true) }
        )

        // Advance and pause
        mockTime.advance(by: 5.0)
        timerManager.pauseAsTrulyAway()

        // Act: Resume (simulating user returned)
        timerManager.resumeIfNeeded()

        // Assert: Timer should reset to full interval (user took a break)
        #expect(timerManager.timeRemaining == 10.0, "Timer should reset after returning from away")
        #expect(!timerManager.isPaused)
        #expect(!timerManager.wasTrulyAway)
    }

    @Test func disablingTimerStopsIt() {
        // Setup
        let mockTime = MockTimeProvider()
        let timerInterval: TimeInterval = 10.0

        let timerManager = TimerManager(
            timeProvider: mockTime,
            settingsProvider: { (timerInterval, true) }
        )

        var timerCompletedCalled = false
        timerManager.onTimerComplete = {
            timerCompletedCalled = true
        }

        // Act: Disable the timer
        timerManager.setEnabled(false)

        // Advance past when it would have fired
        mockTime.advance(by: 20.0)

        // Assert
        #expect(!timerCompletedCalled, "Timer should not fire when disabled")
        #expect(!timerManager.isEnabled)
    }

    // MARK: - Integration / Full Cycle Tests

    @Test func fullIdleCycleWorksCorrectly() {
        // The core user flow: timer running → go idle → still there prompt →
        // no response → marked away → activity → timer resets

        let mockTime = MockTimeProvider()
        let mockActivity = MockActivitySource()
        mockActivity.setTimeProvider(mockTime)
        let timerInterval: TimeInterval = 60.0
        let idleInterval: TimeInterval = 5.0

        let timerManager = TimerManager(
            timeProvider: mockTime,
            settingsProvider: { (timerInterval, true) }
        )

        let activityMonitor = ActivityMonitor(
            timeProvider: mockTime,
            activitySource: mockActivity,
            settingsProvider: { idleInterval }
        )

        // Wire up the interaction (simulating what MenuBarController does)
        activityMonitor.onIdleCheckNeeded = {
            // Still there prompt shown - we'll simulate no response
        }
        activityMonitor.onActivityDetected = {
            timerManager.resumeIfNeeded()
        }

        activityMonitor.startMonitoring()

        // Step 1: Timer counting down normally
        mockTime.advance(by: 30.0)
        #expect(timerManager.timeRemaining == 30.0, "Timer should have counted down 30 seconds")

        // Step 2: User goes idle - still there prompt appears
        mockTime.advance(by: 6.0)  // Exceeds 5 second idle threshold
        #expect(activityMonitor.isCheckingStillThere, "Should be showing still there prompt")

        // Step 3: No response - user confirmed away
        activityMonitor.userConfirmedAway()
        timerManager.pauseAsTrulyAway()
        #expect(activityMonitor.isIdle)
        #expect(timerManager.isPaused)
        #expect(timerManager.wasTrulyAway)

        // Step 4: Time passes while away (timer should NOT count down)
        let timeBeforeAway = timerManager.timeRemaining
        mockTime.advance(by: 100.0)
        #expect(timerManager.timeRemaining == timeBeforeAway, "Timer should be paused while away")

        // Step 5: User returns (activity detected)
        mockActivity.simulateActivity()
        mockTime.advance(by: 1.0)  // Let polling timer fire and detect the activity

        // Step 6: Timer should reset to full interval (user took a break)
        #expect(timerManager.timeRemaining == 60.0, "Timer should reset after returning from away")
        #expect(!timerManager.isPaused)
        #expect(!timerManager.wasTrulyAway)
    }

    @Test func multipleIdleReturnCyclesWork() {
        // Test that timer can be paused and resumed multiple times correctly
        let mockTime = MockTimeProvider()
        let timerInterval: TimeInterval = 60.0

        let timerManager = TimerManager(
            timeProvider: mockTime,
            settingsProvider: { (timerInterval, true) }
        )

        // Cycle 1: Count down, pause, resume
        mockTime.advance(by: 20.0)
        #expect(timerManager.timeRemaining == 40.0, "Cycle 1: Should count down to 40")

        timerManager.pauseAsTrulyAway()
        mockTime.advance(by: 100.0)  // Time passes while away
        #expect(timerManager.timeRemaining == 40.0, "Should stay paused at 40")

        timerManager.resumeIfNeeded()
        #expect(timerManager.timeRemaining == 60.0, "Should reset to 60 after returning from away")

        // Cycle 2: Count down, pause, resume again
        mockTime.advance(by: 25.0)
        #expect(timerManager.timeRemaining == 35.0, "Cycle 2: Should count down to 35")

        timerManager.pauseAsTrulyAway()
        timerManager.resumeIfNeeded()
        #expect(timerManager.timeRemaining == 60.0, "Should reset to 60 after second return")

        // Cycle 3: Verify timer still works
        mockTime.advance(by: 30.0)
        #expect(timerManager.timeRemaining == 30.0, "Timer should work normally after multiple cycles")
    }

    @Test func timerCompletesResetsAndCountsDownAgain() {
        let mockTime = MockTimeProvider()
        let timerInterval: TimeInterval = 10.0

        let timerManager = TimerManager(
            timeProvider: mockTime,
            settingsProvider: { (timerInterval, true) }
        )

        var completionCount = 0
        timerManager.onTimerComplete = {
            completionCount += 1
            timerManager.reset()  // Simulate snooze completing and user clicking OK
        }

        // First completion
        mockTime.advance(by: 10.0)
        #expect(completionCount == 1, "Timer should complete once")
        #expect(timerManager.timeRemaining == 10.0, "Timer should reset after completion")

        // Second completion
        mockTime.advance(by: 10.0)
        #expect(completionCount == 2, "Timer should complete twice")
        #expect(timerManager.timeRemaining == 10.0, "Timer should reset after second completion")
    }

    @Test func reEnablingTimerRestartsFromFullInterval() {
        let mockTime = MockTimeProvider()
        let timerInterval: TimeInterval = 60.0

        let timerManager = TimerManager(
            timeProvider: mockTime,
            settingsProvider: { (timerInterval, true) }
        )

        // Count down some
        mockTime.advance(by: 30.0)
        #expect(timerManager.timeRemaining == 30.0)

        // Disable
        timerManager.setEnabled(false)
        #expect(!timerManager.isEnabled)

        // Re-enable
        timerManager.setEnabled(true)

        // Should restart from full interval
        #expect(timerManager.isEnabled)
        #expect(timerManager.timeRemaining == 60.0, "Re-enabling should reset to full interval")
    }

    @Test func snoozeTimerCountsDownAndCompletes() {
        let mockTime = MockTimeProvider()
        let timerInterval: TimeInterval = 60.0

        let timerManager = TimerManager(
            timeProvider: mockTime,
            settingsProvider: { (timerInterval, true) }
        )

        var timerCompleted = false
        timerManager.onTimerComplete = {
            timerCompleted = true
        }

        // Snooze for 5 seconds (simulating 5 minutes in real app)
        timerManager.snooze(minutes: 0)  // 0 minutes = 0 seconds for testing
        // Actually let's set it manually
        timerManager.snooze(minutes: 1)  // 1 minute = 60 seconds
        #expect(timerManager.timeRemaining == 60.0)

        // Count down the snooze
        mockTime.advance(by: 60.0)
        #expect(timerCompleted, "Snoozed timer should complete")
    }

    @Test func activityDuringNormalCountdownDoesNotInterfere() {
        let mockTime = MockTimeProvider()
        let mockActivity = MockActivitySource()
        mockActivity.setTimeProvider(mockTime)
        let timerInterval: TimeInterval = 60.0
        let idleInterval: TimeInterval = 10.0

        let timerManager = TimerManager(
            timeProvider: mockTime,
            settingsProvider: { (timerInterval, true) }
        )

        let activityMonitor = ActivityMonitor(
            timeProvider: mockTime,
            activitySource: mockActivity,
            settingsProvider: { idleInterval }
        )

        var activityDetectedCount = 0
        activityMonitor.onActivityDetected = {
            activityDetectedCount += 1
        }

        activityMonitor.startMonitoring()

        // Simulate normal usage with activity
        mockTime.advance(by: 5.0)
        mockActivity.simulateActivity()
        mockTime.advance(by: 5.0)
        mockActivity.simulateActivity()
        mockTime.advance(by: 5.0)

        // Timer should have counted down normally (15 seconds total)
        #expect(timerManager.timeRemaining == 45.0, "Timer should count down normally with activity")

        // Activity callback should NOT have been called (not idle, not in still there state)
        #expect(activityDetectedCount == 0, "Activity callback should not fire during normal operation")

        // Should NOT be in idle check state (activity kept resetting idle timer)
        #expect(!activityMonitor.isCheckingStillThere)
    }

    // MARK: - UI Surface Deferral Tests

    @Test func timerDeferredWhileMenuOpen() {
        let coordinator = AppCoordinator(isEnabled: true)

        coordinator.transition(.menuOpened)
        #expect(coordinator.isMenuOpen)

        let effects = coordinator.transition(.timerReachedZero)
        #expect(effects.isEmpty, "Walk alert should be deferred while menu is open")
        #expect(coordinator.deferredWalkAlert)
        #expect(coordinator.state == .running)

        let closeEffects = coordinator.transition(.menuClosed)
        #expect(closeEffects == [.showWalkAlert])
        #expect(coordinator.state == .walkAlert)
        #expect(!coordinator.deferredWalkAlert)
    }

    @Test func settingsOpenDefersWalkAlertAndCloseBringsItBack() {
        let coordinator = AppCoordinator(isEnabled: true)

        // Walk alert fires, then gets deferred by menu open
        coordinator.transition(.timerReachedZero)
        coordinator.transition(.menuOpened)
        #expect(coordinator.deferredWalkAlert)

        // Open settings from menu — deferred alert preserved
        coordinator.transition(.settingsOpened)
        #expect(coordinator.deferredWalkAlert)

        // Menu closes while settings is open — alert stays deferred
        let menuCloseEffects = coordinator.transition(.menuClosed)
        #expect(menuCloseEffects.isEmpty, "Alert should stay deferred while settings is open")

        // Close settings without changes — deferred alert fires
        let closeEffects = coordinator.transition(.settingsClosed)
        #expect(closeEffects == [.showWalkAlert])
        #expect(coordinator.state == .walkAlert)
        #expect(!coordinator.deferredWalkAlert)
    }

    @Test func settingsOpenDeferredAlertClearedByReset() {
        let coordinator = AppCoordinator(isEnabled: true)

        // Walk alert fires, gets deferred by menu, settings opens
        coordinator.transition(.timerReachedZero)
        coordinator.transition(.menuOpened)
        coordinator.transition(.settingsOpened)
        #expect(coordinator.deferredWalkAlert)

        // User changes a setting → handleSettingsChanged fires resetRequested
        coordinator.transition(.resetRequested)
        #expect(!coordinator.deferredWalkAlert)

        // Close settings — no alert (it was cleared by reset)
        coordinator.transition(.menuClosed)
        let closeEffects = coordinator.transition(.settingsClosed)
        #expect(closeEffects.isEmpty)
        #expect(coordinator.state == .running)
    }

    @Test func settingsOpenDismissesWalkAlertDirectly() {
        let coordinator = AppCoordinator(isEnabled: true)

        coordinator.transition(.timerReachedZero)
        #expect(coordinator.state == .walkAlert)

        // Settings opened directly while walk alert showing → dismiss and defer
        let effects = coordinator.transition(.settingsOpened)
        #expect(effects == [.dismissWalkAlert])
        #expect(coordinator.state == .running)
        #expect(coordinator.deferredWalkAlert)

        // Close settings → alert comes back
        let closeEffects = coordinator.transition(.settingsClosed)
        #expect(closeEffects == [.showWalkAlert])
        #expect(coordinator.state == .walkAlert)
    }

    @Test func settingsOpenDismissesStillThere() {
        let coordinator = AppCoordinator(isEnabled: true)

        coordinator.transition(.idleThresholdReached(showStillThereDialog: true))
        #expect(coordinator.state == .confirmingPresence(previous: .running, pendingWalkAlert: false))

        let effects = coordinator.transition(.settingsOpened)
        #expect(effects == [.dismissStillThere, .markPresent])
        #expect(coordinator.state == .running)
    }

    @Test func settingsOpenPreservesPendingWalkAlertFromConfirmingPresence() {
        let coordinator = AppCoordinator(isEnabled: true)

        // Timer fires during confirming presence → pendingWalkAlert = true
        coordinator.transition(.idleThresholdReached(showStillThereDialog: true))
        coordinator.transition(.timerReachedZero)
        #expect(coordinator.state == .confirmingPresence(previous: .running, pendingWalkAlert: true))

        // Open settings → still there dismissed, pendingWalkAlert transferred to deferred
        let effects = coordinator.transition(.settingsOpened)
        #expect(effects == [.dismissStillThere, .markPresent])
        #expect(coordinator.deferredWalkAlert)

        // Close settings → walk alert fires
        let closeEffects = coordinator.transition(.settingsClosed)
        #expect(closeEffects == [.showWalkAlert])
        #expect(coordinator.state == .walkAlert)
    }

    @Test func auxiliaryWindowDefersWalkAlert() {
        let coordinator = AppCoordinator(isEnabled: true)

        // Walk alert fires, gets deferred by menu, about opens
        coordinator.transition(.timerReachedZero)
        coordinator.transition(.menuOpened)
        coordinator.transition(.auxiliaryWindowOpened)
        let menuCloseEffects = coordinator.transition(.menuClosed)
        #expect(menuCloseEffects.isEmpty, "Alert stays deferred while auxiliary window is open")

        // Close auxiliary window → alert comes back
        let closeEffects = coordinator.transition(.auxiliaryWindowClosed)
        #expect(closeEffects == [.showWalkAlert])
        #expect(coordinator.state == .walkAlert)
    }

    @Test func menuOpenDuringWalkAlertDefersIt() {
        let coordinator = AppCoordinator(isEnabled: true)
        coordinator.transition(.timerReachedZero)
        #expect(coordinator.state == .walkAlert)

        let effects = coordinator.transition(.menuOpened)
        #expect(coordinator.state == .running)
        #expect(coordinator.deferredWalkAlert)
        #expect(effects == [.dismissWalkAlert])

        // Close menu without doing anything → walk alert comes back
        let closeEffects = coordinator.transition(.menuClosed)
        #expect(closeEffects == [.showWalkAlert])
        #expect(coordinator.state == .walkAlert)
    }

    @Test func menuOpenDuringWalkAlertThenResetClearsDeferred() {
        let coordinator = AppCoordinator(isEnabled: true)
        coordinator.transition(.timerReachedZero)
        coordinator.transition(.menuOpened)
        #expect(coordinator.deferredWalkAlert)

        // User clicks "Reset Timer" from the menu
        let resetEffects = coordinator.transition(.resetRequested)
        #expect(coordinator.state == .running)
        #expect(!coordinator.deferredWalkAlert)
        #expect(resetEffects.contains(.resetTimer))

        // Close menu → no walk alert (reset cleared the deferred flag)
        let closeEffects = coordinator.transition(.menuClosed)
        #expect(closeEffects.isEmpty)
        #expect(coordinator.state == .running)
    }

    @Test func deferredAlertClearedOnDisable() {
        let coordinator = AppCoordinator(isEnabled: true)
        coordinator.transition(.menuOpened)
        coordinator.transition(.timerReachedZero)
        #expect(coordinator.deferredWalkAlert)

        coordinator.transition(.disableRequested)
        #expect(!coordinator.deferredWalkAlert)
        #expect(coordinator.state == .disabled)
    }

    @Test func deferredAlertClearedOnReset() {
        let coordinator = AppCoordinator(isEnabled: true)
        coordinator.transition(.menuOpened)
        coordinator.transition(.timerReachedZero)
        #expect(coordinator.deferredWalkAlert)

        coordinator.transition(.resetRequested)
        #expect(!coordinator.deferredWalkAlert)
        #expect(coordinator.state == .running)
    }

    @Test func deferredAlertTransferredToConfirmingPresence() {
        let coordinator = AppCoordinator(isEnabled: true)

        // Defer a walk alert while menu is open
        coordinator.transition(.menuOpened)
        coordinator.transition(.timerReachedZero)
        #expect(coordinator.deferredWalkAlert)

        // Close menu but before alert fires, idle kicks in
        // Actually: the deferred flag is still set, and idle fires while running
        coordinator.transition(.menuClosed)
        // menuClosed fires the deferred alert -> walkAlert state
        #expect(coordinator.state == .walkAlert)

        // Let's test the transfer differently: deferred + idle while menu still open
        let c2 = AppCoordinator(isEnabled: true)
        c2.transition(.menuOpened)
        c2.transition(.timerReachedZero)
        #expect(c2.deferredWalkAlert)
        #expect(c2.state == .running)

        // Idle fires while menu is open and deferred flag is set
        let idleEffects = c2.transition(.idleThresholdReached(showStillThereDialog: true))
        #expect(idleEffects == [.showStillThere])
        #expect(c2.state == .confirmingPresence(previous: .running, pendingWalkAlert: true))
        #expect(!c2.deferredWalkAlert, "Deferred flag should transfer to pendingWalkAlert")

        // Activity resolves -> should show walk alert
        let activityEffects = c2.transition(.activityDetected)
        #expect(activityEffects == [.dismissStillThere, .markPresent, .showWalkAlert])
        #expect(c2.state == .walkAlert)
    }

    // MARK: - Edge Cases

    @Test func veryShortIntervalsWorkCorrectly() {
        let mockTime = MockTimeProvider()
        let timerInterval: TimeInterval = 1.0  // 1 second

        let timerManager = TimerManager(
            timeProvider: mockTime,
            settingsProvider: { (timerInterval, true) }
        )

        var timerCompleted = false
        timerManager.onTimerComplete = {
            timerCompleted = true
        }

        mockTime.advance(by: 1.0)
        #expect(timerCompleted, "1-second timer should complete")
    }

    @Test func veryShortIdleIntervalWorksCorrectly() {
        let mockTime = MockTimeProvider()
        let mockActivity = MockActivitySource()
        mockActivity.setTimeProvider(mockTime)
        let idleInterval: TimeInterval = 1.0  // 1 second

        let activityMonitor = ActivityMonitor(
            timeProvider: mockTime,
            activitySource: mockActivity,
            settingsProvider: { idleInterval }
        )

        var idleCheckCalled = false
        activityMonitor.onIdleCheckNeeded = {
            idleCheckCalled = true
        }

        activityMonitor.startMonitoring()
        mockTime.advance(by: 2.0)

        #expect(idleCheckCalled, "1-second idle threshold should trigger")
    }

    @Test func idleTimeoutLongerThanReminderIntervalStillWorks() {
        // Edge case: idle timeout (5 min) > reminder interval (1 min)
        // This is a weird config but shouldn't break anything

        let mockTime = MockTimeProvider()
        let mockActivity = MockActivitySource()
        mockActivity.setTimeProvider(mockTime)
        let timerInterval: TimeInterval = 10.0   // Short reminder
        let idleInterval: TimeInterval = 30.0    // Long idle timeout

        let timerManager = TimerManager(
            timeProvider: mockTime,
            settingsProvider: { (timerInterval, true) }
        )

        let activityMonitor = ActivityMonitor(
            timeProvider: mockTime,
            activitySource: mockActivity,
            settingsProvider: { idleInterval }
        )

        var timerCompleted = false
        timerManager.onTimerComplete = {
            timerCompleted = true
        }

        var idleCheckCalled = false
        activityMonitor.onIdleCheckNeeded = {
            idleCheckCalled = true
        }

        activityMonitor.startMonitoring()

        // Timer should complete before idle check triggers
        mockTime.advance(by: 10.0)
        #expect(timerCompleted, "Timer should complete")
        #expect(!idleCheckCalled, "Idle check should not have triggered yet")

        // Continue to idle check
        mockTime.advance(by: 25.0)
        #expect(idleCheckCalled, "Idle check should trigger eventually")
    }

    // MARK: - Bug: Idle detection while walk alert is showing

    @Test func idleDetectedWhileWalkAlertShowingShouldPauseTimer() {
        // Bug scenario:
        // 1. Timer reaches 0, walk alert shows ("Time to Step Away!")
        // 2. User walks away without clicking anything
        // 3. Idle timer fires (no activity detected)
        // 4. EXPECTED: App should assume user stepped away, dismiss alert, pause timer
        // 5. When user returns, timer resets

        let mockTime = MockTimeProvider()
        let mockActivity = MockActivitySource()
        mockActivity.setTimeProvider(mockTime)
        let timerInterval: TimeInterval = 10.0
        let idleInterval: TimeInterval = 15.0  // Longer than timer so walk alert shows first

        let timerManager = TimerManager(
            timeProvider: mockTime,
            settingsProvider: { (timerInterval, true) }
        )

        let activityMonitor = ActivityMonitor(
            timeProvider: mockTime,
            activitySource: mockActivity,
            settingsProvider: { idleInterval }
        )

        var walkAlertShowing = false

        timerManager.onTimerComplete = {
            walkAlertShowing = true
            // In real code, this shows a modal alert via runModal() which blocks
        }

        activityMonitor.onIdleCheckNeeded = {
            // FIXED BEHAVIOR: Check if walk alert is showing
            if walkAlertShowing {
                // User went idle while walk alert showing - they already stepped away!
                walkAlertShowing = false  // Simulate dismissing the alert (NSApp.stopModal())
                activityMonitor.userConfirmedAway()
                timerManager.pauseAsTrulyAway()
                return
            }
            // Normal "still there?" handling would go here
        }

        activityMonitor.onActivityDetected = {
            timerManager.resumeIfNeeded()
        }

        activityMonitor.startMonitoring()

        // Step 1: Timer counts down to 0, walk alert shows (before idle threshold)
        mockTime.advance(by: 10.0)
        #expect(walkAlertShowing, "Walk alert should be showing")
        #expect(timerManager.timeRemaining <= 0, "Timer should have expired")

        // Step 2: User walks away - more time passes, idle is detected while walk alert is showing
        mockTime.advance(by: 6.0)  // Total 16 seconds, exceeds 15 second idle threshold

        // Step 3: Verify alert dismissed and timer paused
        #expect(!walkAlertShowing, "Walk alert should be auto-dismissed when user goes idle")
        #expect(timerManager.isPaused, "Timer should be paused")
        #expect(timerManager.wasTrulyAway, "Timer should be marked as truly away")

        // Step 4: User returns - timer should reset
        mockActivity.simulateActivity()
        mockTime.advance(by: 1.0)  // Let polling timer detect activity

        #expect(timerManager.timeRemaining == timerInterval, "Timer should reset when user returns")
        #expect(!timerManager.isPaused, "Timer should not be paused after return")
    }

    @Test func clickingOkIllWalkPausesTimerUntilReturn() {
        // Test the "OK, I'll Walk!" button behavior:
        // 1. Timer fires, walk alert shows
        // 2. User clicks "OK, I'll Walk!" - timer pauses
        // 3. User returns - timer resets

        let mockTime = MockTimeProvider()
        let mockActivity = MockActivitySource()
        mockActivity.setTimeProvider(mockTime)
        let timerInterval: TimeInterval = 10.0
        let idleInterval: TimeInterval = 5.0

        let timerManager = TimerManager(
            timeProvider: mockTime,
            settingsProvider: { (timerInterval, true) }
        )

        let activityMonitor = ActivityMonitor(
            timeProvider: mockTime,
            activitySource: mockActivity,
            settingsProvider: { idleInterval }
        )

        activityMonitor.onActivityDetected = {
            timerManager.resumeIfNeeded()
        }

        activityMonitor.startMonitoring()

        // Timer counts down to 0
        mockTime.advance(by: 10.0)
        #expect(timerManager.timeRemaining <= 0, "Timer should have expired")

        // User clicks "OK, I'll Walk!" - simulated by pausing as truly away
        activityMonitor.userConfirmedAway()
        timerManager.pauseAsTrulyAway()

        #expect(timerManager.isPaused, "Timer should be paused after clicking OK")
        #expect(timerManager.wasTrulyAway, "Timer should be marked as truly away")

        // Time passes while user is away
        mockTime.advance(by: 100.0)
        #expect(timerManager.isPaused, "Timer should remain paused while away")

        // User returns
        mockActivity.simulateActivity()
        mockTime.advance(by: 1.0)

        #expect(timerManager.timeRemaining == timerInterval, "Timer should reset to full interval on return")
        #expect(!timerManager.isPaused, "Timer should be running after return")
    }
}
