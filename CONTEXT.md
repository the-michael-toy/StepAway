# StepAway.app

A macOS menu bar app that reminds you to take walking breaks.

## Specs

### Core Behavior
- Displays a working icon (🧑‍💻) in the menu bar with a countdown timer
- Default timer: 90 minutes
- When timer reaches zero, shows an alert dialog telling the user to take a walk
- Alert has two options: "5 more minutes" or "Last task, then break"
- "Last task, then break" pauses reminders until one away -> return cycle is detected
- If user goes idle while walk alert is showing, alert auto-dismisses (they already stepped away)
- If `Still there?` is currently visible when the walk timer expires, the walk alert is deferred until presence check resolves (activity -> show alert, timeout -> away)

### Activity Monitoring
- Monitors mouse movement, clicks, keyboard, and scroll events
- If no activity for the idle timeout period (default: 3 minutes), shows "Still there?" window
- Any mouse/keyboard activity dismisses the window and keeps the timer running (user was just reading/thinking)
- If no response for 60 seconds, user is marked as "away" and timer pauses
- When user returns from being away, timer resets (they already took a break)

### Menu Bar Display
- Active countdown: `🧑‍💻 MM:SS` (e.g., `🧑‍💻 89:32`)
- Paused until next break: `🧑‍💻 --:-- ⏸`
- When user is away: `🚶 --:-- ⏸`
- When disabled: `🧑‍💻 --:-- ⏹` (stop symbol in red)

### Dropdown Menu Options
- **Settings...** - opens Settings window with sliders for timer interval and idle timeout
- **Launch at Login** - toggles auto-start (greyed out if not running from /Applications)
- **Reset Timer** - resets countdown to full interval
- **About StepAway...** - shows About window with version and links
- **Quit StepAway** - exits the app

### Settings Window
- **Enable StepAway** checkbox - toggles the timer on/off
- **Reminder interval** slider - time between walk reminders
- **Idle timeout** slider - time before "Still there?" prompt appears
- Both sliders use discrete stops: 5 sec, 10 sec, 30 sec, 5, 10, 15, 30, 45, 60, 90, 120, 150, 180 minutes

### About Window
- App icon, name, and version
- Description
- Link to Apocalyptic Art Collective
- Link to GitHub repository

### Technical Details
- Written in Swift using AppKit
- Menu bar only app (no dock icon) - uses `LSUIElement = true`
- Settings persisted via UserDefaults
- Launch at login uses SMAppService (macOS 13+)
- Minimum deployment target: macOS 12.0
- Bundle ID: `io.github.the-michael-toy.StepAway`

## Project Structure

```
StepAway/
├── StepAway.xcodeproj/
├── StepAway/
│   ├── StepAwayApp.swift              # App entry point and AppDelegate
│   ├── AppCoordinator.swift           # Pure state machine (events in, effects out)
│   ├── DebugEventLog.swift            # In-memory ring buffer for debug records
│   ├── MenuBarController.swift        # Wiring: events → coordinator → effects → controllers
│   ├── WalkAlertController.swift      # Walk alert lifecycle + modal key/mouse monitors
│   ├── StillThereController.swift     # "Still there?" window + timers + focus restore
│   ├── AboutWindowController.swift    # About window
│   ├── DebugLogWindowController.swift # Debug Log viewer window
│   ├── SettingsWindowController.swift # Settings window with sliders
│   ├── ActivityMonitor.swift          # Mouse/keyboard activity detection
│   ├── TimerManager.swift             # Countdown timer logic
│   ├── Settings.swift                 # AppSettings singleton (UserDefaults wrapper)
│   ├── TestSupport.swift              # Mock time/activity providers for tests
│   ├── Assets.xcassets/               # App icon
│   ├── Info.plist
│   └── StepAway.entitlements
├── README.md
├── LICENSE.md
├── CONTEXT.md
├── app-icon.png
├── step-away-activated.png
└── step-away-menu.png
```

## Building

```bash
# Debug build
xcodebuild -project StepAway.xcodeproj -scheme StepAway -configuration Debug build

# Release build
xcodebuild -project StepAway.xcodeproj -scheme StepAway -configuration Release build

# Install to Applications
cp -R ~/Library/Developer/Xcode/DerivedData/StepAway-*/Build/Products/Release/StepAway.app /Applications/
```

## Releasing

1. **Update version** in two places:
   - `StepAway/Info.plist`:
     - `CFBundleShortVersionString` - the user-visible version (e.g., "1.13")
     - `CFBundleVersion` - increment the build number
   - `StepAway.xcodeproj/project.pbxproj`:
     - `MARKETING_VERSION` - appears twice (Debug and Release), update both

2. **Update CHANGELOG.md** with the new version and changes

3. **Commit and tag**:
   ```bash
   git add -A
   git commit -m "Version X.XX: summary of changes"
   git tag vX.XX
   git push && git push --tags
   ```

4. **Build DMG**:
   ```bash
   ./build-dmg.sh
   ```
   This creates `build/StepAway-X.XX.dmg`

5. **Create GitHub release**:
   ```bash
   gh auth switch -u the-michael-toy
   gh release create vX.XX build/StepAway-X.XX.dmg --title "StepAway X.XX" --notes "paste release notes"
   gh auth switch -u mtoy-googly-moogly  # switch back
   ```

## Notes
- App sandbox is disabled to allow global event monitoring for activity detection
- The `AppSettings` class is named to avoid conflict with SwiftUI's `Settings` scene type
- License: CC0 1.0 (Public Domain)
- The walk alert is a modal-level panel (`NSWindow.Level.modalPanel`) with both key and mouse event monitors. Keystrokes beep and are swallowed; clicks outside the alert beep and are swallowed (except menu bar clicks, which pass through for the coordinator's deferral logic). `runModal` was abandoned because it blocks the run loop.
- When writing tests, be wary of "simulation tests" that implement expected behavior in the test's callback handlers rather than testing the actual production wiring.

## Architecture Notes

### AppCoordinator Reducer

`AppCoordinator` (in `AppCoordinator.swift`) is the single source of truth, with:

- A closed `State` enum (`disabled`, `running`, `snoozed`, `walkAlert`, `pausedUntilBreak`, `confirmingPresence`, `away`)
- A closed `Event` enum (`timerReachedZero`, alert actions, idle/activity, enable/disable/reset, etc.)
- A closed `Effect` enum that drives side effects (show/dismiss windows, timer actions, away/present markers)
- A single transition function: `transition(_ event: Event) -> [Effect]`

`MenuBarController` is pure wiring: it receives callbacks from `TimerManager`, `ActivityMonitor`, and window controllers, maps them to events, feeds them to the coordinator, and dispatches the resulting effects to the appropriate controllers.

Window controllers (`WalkAlertController`, `StillThereController`, `AboutWindowController`, `DebugLogWindowController`) report user actions via closures. `MenuBarController` wires those closures to `handle(event:)`.

### Reducer Test Coverage

Reducer behavior is covered by tests in `StepAwayTests.swift`, including:

1. `lastTaskThenBreakRequiresAwayReturnCycle`
2. `fiveMoreMinutesTransitionsToSnoozed`
3. `disableThenEnableTransitionsBackToRunning`

## vNext State Machine Spec (Design Draft - February 16, 2026)

This section defines the planned behavior to prevent "accidentally disabled overnight" while keeping the app simple to reason about.
Most of this spec is now implemented; keep it as the canonical transition reference and update it if code behavior changes.

### UX Decisions Locked In

- Walk alert has exactly two buttons:
  - `5 more minutes`
  - `Last task, then break`
- `Last task, then break` means: pause reminders now, then automatically resume normal behavior after one away -> return cycle.
- There is no explicit "I'm walking now" button; walking away is inferred from inactivity.

### Primary Goals

1. Prevent users from using persistent disable as a temporary "stop bugging me" control.
2. Make temporary pause explicit and recoverable.
3. Keep the behavior representable as an explicit state machine.

### States

Use a single coordinator state enum:

- `disabled`
- `running`
- `snoozed`
- `walkAlert`
- `confirmingPresence(previous, pendingWalkAlert)` (the "Still there?" window is visible; can carry a deferred walk alert)
- `pausedUntilBreak` (temporary pause while user finishes current task)
- `away` (user is away; next activity completes break and resets timer)

### Events

- `timerReachedZero`
- `alertActionFiveMoreMinutes`
- `alertActionLastTaskThenBreak`
- `idleThresholdReached`
- `activityDetected`
- `stillThereTimeout`
- `disableRequested`
- `enableRequested`
- `resetRequested`
- `menuOpened`
- `menuClosed`
- `settingsOpened`
- `settingsClosed`
- `auxiliaryWindowOpened` (About, Debug Log)
- `auxiliaryWindowClosed`

### Transition Rules

| Current State | Event | Next State | Actions |
|---|---|---|---|
| `running` or `snoozed` | `timerReachedZero` (UI surface active) | same | Set `deferredWalkAlert=true` |
| `running` | `timerReachedZero` (no UI surface) | `walkAlert` | Show walk alert |
| `snoozed` | `timerReachedZero` (no UI surface) | `walkAlert` | Show walk alert |
| `walkAlert` | `alertActionFiveMoreMinutes` | `snoozed` | Set timer to 5:00, close alert |
| `walkAlert` | `alertActionLastTaskThenBreak` | `pausedUntilBreak` | Pause timer display, close alert |
| `walkAlert` | `idleThresholdReached` | `away` | Auto-dismiss alert, mark away |
| `walkAlert` | `menuOpened` | `running` | Dismiss alert, set `deferredWalkAlert=true` (alert returns when menu closes) |
| `running` or `snoozed` | `idleThresholdReached` | `confirmingPresence` or `away` | Show "Still there?" if enabled, otherwise mark away; transfers `deferredWalkAlert` to `pendingWalkAlert` |
| `confirmingPresence` | `timerReachedZero` | `confirmingPresence` | Set `pendingWalkAlert=true` (do not show walk alert yet) |
| `confirmingPresence` | `activityDetected` | `running` / `snoozed` / `pausedUntilBreak` / `walkAlert` | Close window; if `pendingWalkAlert=true`, show walk alert; otherwise return to prior mode |
| `confirmingPresence` | `stillThereTimeout` | `away` | Close window, mark away |
| `pausedUntilBreak` | `activityDetected` | `pausedUntilBreak` | Ignore activity for reminder purposes |
| `pausedUntilBreak` | `idleThresholdReached` | `confirmingPresence` or `away` | Show "Still there?" if enabled; timeout then marks away |
| `away` | `activityDetected` | `running` | Reset timer to full interval, clear away/paused flags |
| any non-`disabled` state | `disableRequested` | `disabled` | Close modal windows, stop timer, clear `deferredWalkAlert` |
| `disabled` | `enableRequested` | `running` | Reset timer to full interval, start timer |
| any non-`disabled` state | `resetRequested` | `running` | Reset timer to full interval, clear `deferredWalkAlert` |
| any | `menuOpened` (non-walkAlert) | same | Set `isMenuOpen=true` |
| any | `menuClosed` | same | Set `isMenuOpen=false`; if deferred and no UI surface active, fire walk alert |
| any | `settingsOpened` (walkAlert) | `running` | Dismiss alert, set `deferredWalkAlert=true`; MenuBarController stops timer + activity monitor |
| any | `settingsOpened` (confirmingPresence) | previous | Dismiss still there, mark present; transfer `pendingWalkAlert` to `deferredWalkAlert` |
| any | `settingsOpened` (other) | same | Set `isSettingsOpen=true`; MenuBarController stops timer + activity monitor |
| any | `settingsClosed` | same | Set `isSettingsOpen=false`; if deferred and no UI surface active, fire walk alert; MenuBarController restarts activity monitor and resets timer (unless walk alert just fired) |
| any | `auxiliaryWindowOpened` (walkAlert) | `running` | Dismiss alert, set `deferredWalkAlert=true`, increment `auxiliaryWindowCount` |
| any | `auxiliaryWindowOpened` (other) | same | Increment `auxiliaryWindowCount` |
| any | `auxiliaryWindowClosed` | same | Decrement `auxiliaryWindowCount`; if deferred and no UI surface active, fire walk alert |

### Display Mapping (Proposed)

- `running` / `snoozed`: `🧑‍💻 MM:SS`
- `pausedUntilBreak`: `🧑‍💻 --:-- ⏸`
- `away`: `🚶 --:-- ⏸`
- `disabled`: `🧑‍💻 --:-- ⏹` (stop symbol in red)

### Persistence Rules

- Persist: user settings, including `disabled` on/off.
- Do not persist transient states (`walkAlert`, `confirmingPresence`, `pausedUntilBreak`, `away`, `snoozed`).
- On app launch:
  - if disabled persisted as on -> start in `disabled`
  - otherwise -> start in `running` with full interval

This avoids getting "stuck paused" across sessions.

### Invariants

1. At most one modal UI surface can be visible (`walkAlert` xor `confirmingPresence`).
2. `disabled` suppresses all reminders and presence checks.
3. `pausedUntilBreak` cannot transition directly to `walkAlert`; it must go through `away` then `running`.
4. Returning from `away` always resets to full interval.

### Implementation Shape (When Coding)

- Add an explicit coordinator reducer:
  - `func transition(_ event: Event) -> [Effect]`
- Keep state mutation in one place (the reducer).
- Execute side effects (show/dismiss UI, start/stop timer, update menu text) from returned effects.
- Unit-test transitions directly with table-driven tests.

### Test Cases Required for vNext

1. `testLastTaskThenBreakDoesNotAlertAgainBeforeAway`
2. `testPausedUntilBreakResumesAfterAwayReturnCycle`
3. `testDisableIsPersistentButPausedUntilBreakIsNot`
4. `testWalkAlertIdleAutoDismissTransitionsToAway`
5. `testDisabledSuppressesStillThereFlow`
6. `testOnlyOneModalVisibleAtATime`

### Debug Event Log (Hidden/Advanced)

Purpose: make bad UX reports debuggable by showing a recent timeline of events and state transitions that can be copied and shared.

#### Entry Point

- Keep this out of normal UI by default.
- Add an alternate menu item shown only when Option is held while opening the menu:
  - `Show Debug Event Log...`

#### What to Log

Log these records with millisecond precision timestamps:

- Incoming events (for example `timerReachedZero`, `idleThresholdReached`, `activityDetected`, alert button presses).
- State transitions (`fromState -> toState`), including no-op/ignored transitions when relevant.
- Side effects executed (show/dismiss alert, show/dismiss still-there window, timer reset/start/stop, enable/disable).
- Settings changes affecting behavior (`isEnabled`, timer interval, idle interval, still-there enabled).
- App lifecycle markers (launch, quit, wake from sleep if later added).

Do not log personal content (typed keys, app/window titles, URLs, clipboard data).

#### Log Record Format

One line per record, designed for copy/paste:

`2026-02-16T09:41:22.184-0800 | event=alertActionLastTaskThenBreak | state=walkAlert->pausedUntilBreak | effects=[closeWalkAlert,pauseCountdown]`

#### Retention

- In-memory ring buffer, default size: 500 records.
- Optional time cutoff in viewer: last 5m / 15m / 60m.
- Not persisted across app restarts in v1 of this feature.

#### Viewer UI

- Small read-only window with monospaced text.
- Controls:
  - `Copy Last 5 Minutes`
  - `Copy Visible`
  - `Clear`
  - Time filter dropdown (`5m`, `15m`, `60m`, `All`)
- Include app version and current state header at top for context.

#### Implementation Notes

- Emit records from the state-machine reducer boundary so logs reflect true event ordering.
- Use a monotonic sequence number in addition to wall-clock time to avoid ambiguity.
- Keep logging lightweight and non-blocking (append to buffer on main thread; no file I/O in transition path).

#### Minimum Test Cases

1. `testLogIncludesEventAndTransitionForLastTaskThenBreak`
2. `testLogOrdersRecordsBySequenceNumber`
3. `testRingBufferDropsOldestRecordsAtCapacity`
4. `testCopyLastFiveMinutesFiltersByTimestamp`
5. `testNoSensitiveFieldsInLogRecords`

## Walk Alert Implementation (Resolved February 19, 2026)

The walk alert uses a modal-level panel (`.modalPanel`, level 8) with event monitors instead of `runModal`:

- **Key monitor (local):** Intercepts all `keyDown` events within StepAway. Button key equivalents (Return) pass through via `performKeyEquivalent`; everything else beeps and is swallowed.
- **Mouse monitor (local):** Intercepts `leftMouseDown` and `rightMouseDown` within StepAway. Clicks inside the alert panel pass through. Clicks in the menu bar area (top 24pt of any screen) pass through (so the coordinator's `menuOpened` deferral works). All other clicks beep and are swallowed.
- **Mouse monitor (global):** Intercepts clicks in other apps. Beeps and yanks focus back to the walk alert panel. Menu bar clicks pass through.
- **Activation observer:** Re-activates the panel whenever another app steals focus (`NSWorkspace.didActivateApplicationNotification` with `bundleIdentifier != ours`).
- **No run loop blocking:** TimerManager, ActivityMonitor, and menu delegate all work normally during the walk alert.

Three earlier approaches (`runModal`, deferred `runModal`, floating panel without mouse monitor) were tried and abandoned. See git history for details.

### UI State Deferral

The coordinator tracks `isMenuOpen`, `isSettingsOpen`, `auxiliaryWindowCount`, and `deferredWalkAlert` as orthogonal flags. `uiSurfaceActive` is true when any of these indicate an open surface.

- `timerReachedZero` while a UI surface is active sets `deferredWalkAlert=true` and returns no effects
- Closing the last UI surface checks the flag and fires the walk alert if the state is still `running`/`snoozed`
- `disableRequested` and `resetRequested` clear the deferred flag
- `idleThresholdReached` while deferred transfers the flag to `pendingWalkAlert` in `confirmingPresence`
- `menuOpened` while in `walkAlert` defers the alert (dismisses temporarily, comes back when menu closes; "Reset Timer" from the menu clears the deferred flag)
- `settingsOpened` while in `walkAlert` or `confirmingPresence` dismisses the window and preserves the deferred flag; MenuBarController also stops the timer and activity monitor
- `auxiliaryWindowOpened` (About, Debug Log) while in `walkAlert` dismisses and defers; fired inline from menu action to avoid race with `menuDidClose`
- UI surface tracking cases are ordered before the `(.disabled, _)` catch-all in the coordinator switch, so flags are maintained even when disabled

## Future Improvements

### Better Activity Detection for Passive Media Consumption

**Current limitation:** Activity is only detected via mouse movement, clicks, keyboard, and scroll wheel. This means watching videos (in a browser, YouTube TV, Apple TV, etc.) does NOT count as activity - the timer will pause after the idle timeout because there's no input.

**Possible solutions:**
1. **Check if display is awake** - Use `IOKit` to detect if the screen is active (not sleeping)
2. **Check for audio output** - Detect if system audio is playing
3. **Check screen idle time** - Use `CGEventSourceSecondsSinceLastEventType` which some apps update even during video playback

This would allow the timer to keep counting down during passive viewing, which is arguably when you most need a reminder to get up and walk.

## Manual Test Suite

Use short intervals for testing (e.g., 10s walk timer, 5s idle timeout).

### State Table (Reference)

| State | Activity Detected | Idle Timeout Fires | Still-There 60s Expires |
|-------|-------------------|-------------------|------------------------|
| **No windows** | Keep timer running | Show "Still there?" | n/a |
| **Step away window** | User clicks button | Dismiss alert, apply selected action | n/a |
| **Still there window** | Dismiss window, keep timer running | n/a | Mark away, pause timer |
| **Both windows** | *Invalid state - prevent this* | *Invalid state* | *Invalid state* |

### Tests

1. **Click "Last task, then break" pauses reminders**
   - Type for 10s → walk alert appears
   - Click "Last task, then break"
   - Expected: Timer shows `--:-- ⏸` and stays paused until an away -> return cycle

2. **Walk alert auto-dismisses when idle**
   - Type for 10s → walk alert appears
   - Stop all activity, wait 5+ seconds
   - Expected: Alert auto-dismisses, timer shows `--:-- ⏸`

3. **Return from away restarts timer**
   - With timer paused (`--:-- ⏸`), start typing
   - Expected: Timer resets to full interval and starts counting

4. **"Still there?" dismissed by mouse**
   - Do nothing for 5s → "Still there?" appears
   - Move mouse
   - Expected: Window dismisses, timer keeps running (not reset)

5. **"Still there?" dismissed by key press**
   - Do nothing for 5s → "Still there?" appears
   - Press a key
   - Expected: Window dismisses, timer keeps running

6. **"Still there?" auto-dismiss after 60s**
   - Do nothing for 5s → "Still there?" appears
   - Wait 60 seconds (watch progress bar fill)
   - Expected: Warning sound at ~50s (if enabled), window auto-dismisses, timer shows `--:-- ⏸`

7. **Timer shows 0:00 when alert fires**
   - Watch menu bar countdown
   - Expected: Shows `0:00` when walk alert appears (not `0:01`)

8. **"5 more minutes" works**
   - Type for 10s → walk alert appears
   - Click "5 more minutes"
   - Expected: Timer shows 5:00 and counts down

9. **Focus restoration**
   - Open another app (e.g., iTerm)
   - Do nothing for 5s → "Still there?" appears
   - Press key or move mouse to dismiss
   - Expected: Focus returns to previous app

10. **Walk alert blocks clicks on other apps**
    - Type for 10s → walk alert appears
    - Click on another app's window
    - Expected: Beep, focus yanks back to walk alert

11. **Walk alert blocks keystrokes**
    - Type for 10s → walk alert appears
    - Press any key (not Return/Enter)
    - Expected: Beep, keystroke not passed through

12. **Settings opens cleanly during walk alert**
    - Type for 10s → walk alert appears
    - Click menu bar → open Settings
    - Expected: Walk alert dismissed, Settings opens, timer stops
    - Close Settings without changes
    - Expected: Walk alert comes back

13. **About opens cleanly during walk alert**
    - Type for 10s → walk alert appears
    - Click menu bar → open About
    - Expected: Walk alert dismissed, About opens cleanly
    - Close About
    - Expected: Walk alert comes back

14. **Settings disable clears deferred alert**
    - Type for 10s → walk alert appears
    - Click menu bar → open Settings → uncheck Enable
    - Close Settings
    - Expected: App is disabled (`--:-- ⏹`), no walk alert
