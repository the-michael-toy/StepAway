# StepAway.app

A macOS menu bar app that reminds you to take walking breaks.

## Specs

### Core Behavior
- Displays a walking person icon (🚶) in the menu bar with a countdown timer
- Default timer: 90 minutes
- When timer reaches zero, shows an alert dialog telling the user to take a walk
- Alert has two options: "OK, I'll Walk!" (resets timer) or "Snooze 5 min"

### Activity Monitoring
- Monitors mouse movement, clicks, keyboard, and scroll events
- If no activity for the idle timeout period (default: 3 minutes), shows "Still there?" window
- Any mouse/keyboard activity dismisses the window and keeps the timer running (user was just reading/thinking)
- If no response for 60 seconds, user is marked as "away" and timer pauses
- When user returns from being away, timer resets (they already took a break)

### Menu Bar Display
- Format: `🚶 MM:SS` (e.g., `🚶 89:32`)
- When user is away: `🚶 --:-- ⏸`
- When disabled: `🚶 --:--`

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
- Both sliders use discrete stops: 30 sec, 5, 10, 15, 30, 60, 90, 120, 150, 180 minutes

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
│   ├── MenuBarController.swift        # Menu bar UI and menu handling
│   ├── SettingsWindowController.swift # Settings window with sliders
│   ├── ActivityMonitor.swift          # Mouse/keyboard activity detection
│   ├── TimerManager.swift             # Countdown timer logic
│   ├── Settings.swift                 # AppSettings singleton (UserDefaults wrapper)
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

1. **Update version** in `StepAway/Info.plist`:
   - `CFBundleShortVersionString` - the user-visible version (e.g., "1.12")
   - `CFBundleVersion` - increment the build number

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

5. **Create GitHub release** at https://github.com/the-michael-toy/StepAway/releases
   - Use tag vX.XX
   - Copy release notes from CHANGELOG.md
   - Attach the DMG file

## Notes
- App sandbox is disabled to allow global event monitoring for activity detection
- The `AppSettings` class is named to avoid conflict with SwiftUI's `Settings` scene type
- License: CC0 1.0 (Public Domain)
- The walk alert uses `NSAlert.runModal()` which blocks but still allows timers to fire (run loop keeps running). This means idle detection can trigger while the modal is up. Use `NSApp.stopModal()` to dismiss programmatically.
- When writing tests, be wary of "simulation tests" that implement expected behavior in the test's callback handlers rather than testing the actual production wiring.

## Architecture Notes

### MenuBarController Coordination Logic

MenuBarController currently handles both UI concerns AND the coordination logic between TimerManager and ActivityMonitor. This coordination logic includes:

- When idle is detected (`onIdleCheckNeeded`), show "still there?" window OR pause timer
- When activity is detected (`onActivityDetected`), dismiss "still there?" window OR resume timer
- When walk alert is showing and idle is detected, auto-dismiss and reset timer (bug fix from Jan 2026)
- When timer completes (`onTimerComplete`), show walk alert

This coordination logic is not tested. The existing tests only test TimerManager and ActivityMonitor in isolation - they verify the components work correctly when methods are called, but don't verify the wiring that decides *when* to call those methods.

### Future: Extract AppCoordinator

To make the coordination logic testable, extract it from MenuBarController into an `AppCoordinator` class:

```swift
class AppCoordinator {
    let timerManager: TimerManager
    let activityMonitor: ActivityMonitor

    var onShowWalkAlert: (() -> Void)?
    var onDismissWalkAlert: (() -> Void)?
    var onShowStillThereWindow: (() -> Void)?
    var onDismissStillThereWindow: (() -> Void)?
    var onUpdateDisplay: ((TimeInterval) -> Void)?

    private(set) var isWalkAlertShowing = false
    // ... coordination logic here
}
```

### Tests That Would Catch Real Bugs

With an AppCoordinator, these tests would have caught the Jan 2026 bug:

1. **`testIdleWhileWalkAlertShowingResetsTimer`** - Trigger timer completion, then trigger idle detection, verify timer resets and `onDismissWalkAlert` is called.

2. **`testFullIdleCycleTriggersCorrectCallbacks`** - Don't manually call methods; instead advance time and verify the coordinator calls the right callbacks in the right order.

3. **`testActivityDuringStillThereWindowDismissesIt`** - Trigger idle, verify `onShowStillThereWindow` called, simulate activity, verify `onDismissStillThereWindow` called.

4. **`testNoResponseToStillTherePausesTimer`** - Trigger idle, wait for timeout, verify timer pauses without manual intervention.

## Future Improvements

### Better Activity Detection for Passive Media Consumption

**Current limitation:** Activity is only detected via mouse movement, clicks, keyboard, and scroll wheel. This means watching videos (in a browser, YouTube TV, Apple TV, etc.) does NOT count as activity - the timer will pause after the idle timeout because there's no input.

**Possible solutions:**
1. **Check if display is awake** - Use `IOKit` to detect if the screen is active (not sleeping)
2. **Check for audio output** - Detect if system audio is playing
3. **Check screen idle time** - Use `CGEventSourceSecondsSinceLastEventType` which some apps update even during video playback

This would allow the timer to keep counting down during passive viewing, which is arguably when you most need a reminder to get up and walk.
