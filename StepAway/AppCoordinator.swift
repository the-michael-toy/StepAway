// SPDX-License-Identifier: CC0-1.0
// This file is part of StepAway - https://github.com/the-michael-toy/StepAway

import Foundation

final class AppCoordinator {
    enum CountdownMode: Equatable {
        case running
        case snoozed
        case pausedUntilBreak
    }

    enum State: Equatable {
        case disabled
        case running
        case snoozed
        case walkAlert
        case pausedUntilBreak
        case confirmingPresence(previous: CountdownMode, pendingWalkAlert: Bool)
        case away
    }

    enum Event: Equatable {
        case timerReachedZero
        case alertActionGettingUpToWalk
        case alertActionFiveMoreMinutes
        case alertActionLastTaskThenBreak
        case idleThresholdReached(showStillThereDialog: Bool)
        case activityDetected
        case congratsTimedOut
        case stillThereTimeout
        case disableRequested
        case enableRequested
        case resetRequested
        case menuOpened
        case menuClosed
        case settingsOpened
        case settingsClosed
        case auxiliaryWindowOpened
        case auxiliaryWindowClosed
    }

    enum Effect: Equatable {
        case showWalkAlert
        case dismissWalkAlert
        case showCongrats
        case dismissCongrats
        case showStillThere
        case dismissStillThere
        case markPresent
        case markAwayAndPause
        case pauseUntilBreak
        case setSnooze(minutes: Int)
        case resetTimer
        case disableTimer
        case enableTimer
    }

    private(set) var state: State
    private(set) var isMenuOpen = false
    private(set) var isSettingsOpen = false
    private(set) var deferredWalkAlert = false
    private(set) var isCongratsShowing = false
    private(set) var auxiliaryWindowCount = 0
    var uiSurfaceActive: Bool { isMenuOpen || isSettingsOpen || auxiliaryWindowCount > 0 }

    init(isEnabled: Bool) {
        state = isEnabled ? .running : .disabled
    }

    @discardableResult
    func transition(_ event: Event) -> [Effect] {
        switch (state, event) {
        // UI surface tracking — must come before (.disabled, _) catch-all
        // so these flags are always maintained regardless of state.
        case (_, .menuOpened):
            isMenuOpen = true
            if state == .walkAlert {
                state = .running
                deferredWalkAlert = true
                return [.dismissWalkAlert]
            }
            return []

        case (_, .menuClosed):
            isMenuOpen = false
            return checkDeferredWalkAlert()

        case (_, .settingsOpened):
            isSettingsOpen = true
            // Don't clear deferredWalkAlert — if the user changes settings,
            // handleSettingsChanged fires resetRequested/disableRequested which
            // clears it. If they don't change anything, the alert should come back.
            switch state {
            case .walkAlert:
                state = .running
                deferredWalkAlert = true
                return [.dismissWalkAlert]
            case .confirmingPresence(let previous, let pendingWalkAlert):
                if pendingWalkAlert { deferredWalkAlert = true }
                switch previous {
                case .running: state = .running
                case .snoozed: state = .snoozed
                case .pausedUntilBreak: state = .pausedUntilBreak
                }
                return [.dismissStillThere, .markPresent]
            default:
                return []
            }

        case (_, .settingsClosed):
            isSettingsOpen = false
            return checkDeferredWalkAlert()

        case (_, .auxiliaryWindowOpened):
            auxiliaryWindowCount += 1
            if state == .walkAlert {
                state = .running
                deferredWalkAlert = true
                return [.dismissWalkAlert]
            }
            return []

        case (_, .auxiliaryWindowClosed):
            auxiliaryWindowCount = max(0, auxiliaryWindowCount - 1)
            return checkDeferredWalkAlert()

        // Disabled state
        case (.disabled, .enableRequested):
            state = .running
            return [.enableTimer, .markPresent, .resetTimer]
        case (.disabled, .idleThresholdReached):
            return [.markPresent]
        case (.disabled, _):
            return []

        case (_, .disableRequested):
            state = .disabled
            deferredWalkAlert = false
            isCongratsShowing = false
            return [.dismissWalkAlert, .dismissStillThere, .dismissCongrats, .disableTimer, .markPresent]

        case (_, .resetRequested):
            state = .running
            deferredWalkAlert = false
            isCongratsShowing = false
            return [.dismissWalkAlert, .dismissStillThere, .dismissCongrats, .markPresent, .resetTimer]

        case (.running, .timerReachedZero), (.snoozed, .timerReachedZero):
            if uiSurfaceActive {
                deferredWalkAlert = true
                return []
            }
            state = .walkAlert
            return [.showWalkAlert]

        case (.walkAlert, .alertActionGettingUpToWalk):
            state = .away
            isCongratsShowing = true
            return [.dismissWalkAlert, .showCongrats, .markAwayAndPause]

        case (.walkAlert, .alertActionFiveMoreMinutes):
            state = .snoozed
            return [.dismissWalkAlert, .setSnooze(minutes: 5)]

        case (.walkAlert, .alertActionLastTaskThenBreak):
            state = .pausedUntilBreak
            return [.dismissWalkAlert, .pauseUntilBreak]

        case (.walkAlert, .idleThresholdReached):
            state = .away
            return [.dismissWalkAlert, .markAwayAndPause]

        case (.running, .idleThresholdReached(let showStillThereDialog)):
            if showStillThereDialog {
                let pendingWalkAlert = deferredWalkAlert
                deferredWalkAlert = false
                state = .confirmingPresence(previous: .running, pendingWalkAlert: pendingWalkAlert)
                return [.showStillThere]
            }
            state = .away
            return [.markAwayAndPause]

        case (.snoozed, .idleThresholdReached(let showStillThereDialog)):
            if showStillThereDialog {
                let pendingWalkAlert = deferredWalkAlert
                deferredWalkAlert = false
                state = .confirmingPresence(previous: .snoozed, pendingWalkAlert: pendingWalkAlert)
                return [.showStillThere]
            }
            state = .away
            return [.markAwayAndPause]

        case (.confirmingPresence(let previous, let pendingWalkAlert), .activityDetected):
            if pendingWalkAlert {
                state = .walkAlert
                return [.dismissStillThere, .markPresent, .showWalkAlert]
            }
            switch previous {
            case .running:
                state = .running
            case .snoozed:
                state = .snoozed
            case .pausedUntilBreak:
                state = .pausedUntilBreak
            }
            return [.dismissStillThere, .markPresent]

        case (.confirmingPresence, .stillThereTimeout):
            state = .away
            return [.dismissStillThere, .markAwayAndPause]

        case (.confirmingPresence(let previous, _), .timerReachedZero):
            state = .confirmingPresence(previous: previous, pendingWalkAlert: true)
            return []

        case (.pausedUntilBreak, .idleThresholdReached(let showStillThereDialog)):
            if showStillThereDialog {
                state = .confirmingPresence(previous: .pausedUntilBreak, pendingWalkAlert: false)
                return [.showStillThere]
            }
            state = .away
            return [.markAwayAndPause]

        case (.away, .activityDetected):
            if isCongratsShowing { return [] }
            state = .running
            return [.markPresent, .resetTimer]

        case (_, .congratsTimedOut):
            isCongratsShowing = false
            return [.dismissCongrats]

        default:
            return []
        }
    }

    private func checkDeferredWalkAlert() -> [Effect] {
        guard !uiSurfaceActive && deferredWalkAlert else { return [] }
        switch state {
        case .running, .snoozed:
            deferredWalkAlert = false
            state = .walkAlert
            return [.showWalkAlert]
        default:
            return []
        }
    }

    static func stateName(_ state: State) -> String {
        switch state {
        case .disabled:
            return "disabled"
        case .running:
            return "running"
        case .snoozed:
            return "snoozed"
        case .walkAlert:
            return "walkAlert"
        case .pausedUntilBreak:
            return "pausedUntilBreak"
        case .confirmingPresence(let previous, let pendingWalkAlert):
            return "confirmingPresence(previous:\(countdownModeName(previous)),pendingWalkAlert:\(pendingWalkAlert))"
        case .away:
            return "away"
        }
    }

    static func eventName(_ event: Event) -> String {
        switch event {
        case .timerReachedZero:
            return "timerReachedZero"
        case .alertActionGettingUpToWalk:
            return "alertActionGettingUpToWalk"
        case .alertActionFiveMoreMinutes:
            return "alertActionFiveMoreMinutes"
        case .alertActionLastTaskThenBreak:
            return "alertActionLastTaskThenBreak"
        case .idleThresholdReached(let showStillThereDialog):
            return "idleThresholdReached(showStillThereDialog:\(showStillThereDialog))"
        case .activityDetected:
            return "activityDetected"
        case .congratsTimedOut:
            return "congratsTimedOut"
        case .stillThereTimeout:
            return "stillThereTimeout"
        case .disableRequested:
            return "disableRequested"
        case .enableRequested:
            return "enableRequested"
        case .resetRequested:
            return "resetRequested"
        case .menuOpened:
            return "menuOpened"
        case .menuClosed:
            return "menuClosed"
        case .settingsOpened:
            return "settingsOpened"
        case .settingsClosed:
            return "settingsClosed"
        case .auxiliaryWindowOpened:
            return "auxiliaryWindowOpened"
        case .auxiliaryWindowClosed:
            return "auxiliaryWindowClosed"
        }
    }

    static func effectName(_ effect: Effect) -> String {
        switch effect {
        case .showWalkAlert:
            return "showWalkAlert"
        case .dismissWalkAlert:
            return "dismissWalkAlert"
        case .showCongrats:
            return "showCongrats"
        case .dismissCongrats:
            return "dismissCongrats"
        case .showStillThere:
            return "showStillThere"
        case .dismissStillThere:
            return "dismissStillThere"
        case .markPresent:
            return "markPresent"
        case .markAwayAndPause:
            return "markAwayAndPause"
        case .pauseUntilBreak:
            return "pauseUntilBreak"
        case .setSnooze(let minutes):
            return "setSnooze(minutes:\(minutes))"
        case .resetTimer:
            return "resetTimer"
        case .disableTimer:
            return "disableTimer"
        case .enableTimer:
            return "enableTimer"
        }
    }

    static func countdownModeName(_ mode: CountdownMode) -> String {
        switch mode {
        case .running:
            return "running"
        case .snoozed:
            return "snoozed"
        case .pausedUntilBreak:
            return "pausedUntilBreak"
        }
    }
}
