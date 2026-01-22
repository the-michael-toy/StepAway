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
- **Enable/Disable Timer** - toggles the timer on/off
- **Timer Interval** - submenu with options: 1, 30, 45, 60, 90, 120 minutes (checkmark on current)
- **Idle Timeout** - submenu with options: 1, 2, 3, 5, 10 minutes (checkmark on current)
- **Launch at Login** - toggles auto-start (greyed out if not running from /Applications)
- **Reset Timer** - resets countdown to full interval
- **Quit StepAway** - exits the app

### Technical Details
- Written in Swift using AppKit
- Menu bar only app (no dock icon) - uses `LSUIElement = true`
- Settings persisted via UserDefaults
- Launch at login uses SMAppService (macOS 13+)
- Minimum deployment target: macOS 12.0
- Bundle ID: `com.stepaway.app`

## Project Structure

```
StepAway/
├── StepAway.xcodeproj/
├── StepAway/
│   ├── StepAwayApp.swift           # App entry point and AppDelegate
│   ├── MenuBarController.swift  # Menu bar UI and menu handling
│   ├── ActivityMonitor.swift    # Mouse/keyboard activity detection
│   ├── TimerManager.swift       # Countdown timer logic
│   ├── Settings.swift           # AppSettings singleton (UserDefaults wrapper)
│   ├── Assets.xcassets/         # App icon (XKCD-style stick figure walking away from laptop)
│   ├── Info.plist
│   └── StepAway.entitlements
└── CONTEXT.md
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

## Notes
- App sandbox is disabled to allow global event monitoring for activity detection
- The `AppSettings` class is named to avoid conflict with SwiftUI's `Settings` scene type

## Future Improvements

### Settings Panel
Replace individual menu items for Timer Interval and Idle Timeout with a single "Settings..." menu item that opens a preferences panel.

### About Panel
Add an "About StepAway" menu item with version info and attribution.

### Publish to GitHub
Create a public repository for the project.

### Better Activity Detection for Passive Media Consumption

**Current limitation:** Activity is only detected via mouse movement, clicks, keyboard, and scroll wheel. This means watching videos (in a browser, YouTube TV, Apple TV, etc.) does NOT count as activity - the timer will pause after the idle timeout because there's no input.

**Possible solutions:**
1. **Check if display is awake** - Use `IOKit` to detect if the screen is active (not sleeping)
2. **Check for audio output** - Detect if system audio is playing
3. **Check screen idle time** - Use `CGEventSourceSecondsSinceLastEventType` which some apps update even during video playback

This would allow the timer to keep counting down during passive viewing, which is arguably when you most need a reminder to get up and walk.
