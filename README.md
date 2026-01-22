<table><tr>
<td><img src="app-icon.png" width="128" alt="StepAway icon"></td>
<td valign="top"><h1>StepAway</h1></td>
</tr></table>

A macOS menu bar app that reminds you to take walking breaks. I find that when using an AI it is too easy to forget to do this. It was entirely written by [Claude](https://claude.ai).  I welcome contributions (like a better icon).

![StepAway Alert](step-away-activated.png)

## What it does

- Shows a countdown timer in your menu bar: 🚶 45:00
- Alerts you when it's time to step away
- Pauses automatically when you're away from your computer
- Resumes when you return

![StepAway Menu](step-away-menu.png)

## Install

### Download

1. Download the latest DMG from [Releases](https://github.com/the-michael-toy/StepAway/releases/latest)
2. Open the DMG and drag StepAway to Applications
3. On first launch, macOS may warn about an unidentified developer - right-click the app and choose "Open" to bypass this

### Build from source

```bash
git clone https://github.com/the-michael-toy/StepAway.git
cd StepAway
xcodebuild -project StepAway.xcodeproj -scheme StepAway -configuration Release build
cp -R ~/Library/Developer/Xcode/DerivedData/StepAway-*/Build/Products/Release/StepAway.app /Applications/
```

## Requirements

macOS 12.0 or later

## License

[CC0 1.0](LICENSE.md) - Public domain. Do whatever you want with it.

---

A product of the [Apocalyptic Art Collective](https://apocalypticartcollective.com/) | Built with [Claude Code](https://claude.ai/claude-code)

*This software is provided as-is. It was developed with AI assistance. Please review the source code and exercise your own judgment before use.*
