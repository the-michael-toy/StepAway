# Changelog

## Version 1.18

- Added explicit AppCoordinator state machine (`State`/`Event`/`Effect`) for transition-driven behavior
- Added "Last task, then break" flow (pause reminders until away -> return)
- Updated walk alert actions to "5 more minutes" and "Last task, then break"
- Updated menu bar status icons for working/paused/away/disabled states
- Added hidden debug event log viewer (Option-open menu to reveal)
- Added 45-minute option to timer interval and idle timeout sliders

## Version 1.16

- Fixed menu bar not showing stop icon when app launches in disabled state

## Version 1.15

- Fixed "Still there?" window appearing when StepAway is disabled

## Version 1.14

- Menu bar now shows red stop symbol when disabled for clearer visual feedback

## Version 1.13

- Fixed idle detection not seeing keystrokes
- Fixed focus not restoring to previous app after "Still there?" dialog dismissed
- Fixed "OK, I'll Walk!" button: now pauses timer until you return
- Walk alert auto-dismisses when user goes idle
- Added progress bar to "Still there?" window showing countdown to auto-dismiss
- Added 5s and 10s test intervals in settings

## Version 1.12

- Walk alert now auto-dismisses if user goes idle while alert is showing
- Timer display now shows 0:00 when it fires (instead of 0:01)

## Version 1.11

- Added disclaimer to About window noting AI-assisted development
- Added "Built with Claude Code" link in About window

## Version 1.1

- Added Settings window with help tooltips for each option
- Added option to disable "Still there?" confirmation dialog
- Added configurable warning sound with sound picker and test button
- Added settings validation: sliders auto-adjust to prevent nonsensical configurations

## Version 1.01

- Fixed crash when closing About window
- "Still there?" dialog now appears near the mouse cursor instead of screen center
- "Still there?" dialog floats above other windows
- Added warning sound and yellow flash 10 seconds before "Still there?" auto-dismisses

## Version 1.0

- Initial release
