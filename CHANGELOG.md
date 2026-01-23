# Changelog

## Version 1.12

- Fixed bug: "Time to Step Away" alert now auto-dismisses and timer resets if user goes idle while alert is showing
- Timer display now shows 0:00 when it fires (instead of 0:01)
- Removed trivial tests, added architecture notes for future AppCoordinator refactoring
- Added release instructions to CONTEXT.md

## Version 1.11

- Added disclaimer to About window noting AI-assisted development
- Added "Built with Claude Code" link in About window

## Version 1.1

- Added Settings window with help tooltips for each option
- Added option to disable "Still there?" confirmation dialog
- Added configurable warning sound with sound picker and test button
- Added settings validation: sliders auto-adjust to prevent nonsensical configurations
- Added comprehensive test suite (21 tests)
- Added build-dmg.sh script for creating release DMGs
- Changed bundle identifier to io.github.the-michael-toy.StepAway

## Version 1.01

- Fixed crash caused by About window use-after-free during close animation
- "Still there?" dialog now appears near the mouse cursor instead of screen center
- "Still there?" dialog floats above other windows
- Added warning sound (Glass) and yellow flash 10 seconds before "Still there?" auto-dismisses
- About window now reads version from bundle dynamically

## Version 1.0

- Initial release
