// SPDX-License-Identifier: CC0-1.0
// This file is part of StepAway - https://github.com/the-michael-toy/StepAway

import AppKit

final class AboutWindowController {
    private var aboutWindow: NSWindow?
    private var closeObserver: NSObjectProtocol?

    var onWindowClosed: (() -> Void)?

    var isShowing: Bool { aboutWindow?.isVisible == true }

    func show() {
        if let existingWindow = aboutWindow, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 270),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About StepAway"
        window.center()
        window.isReleasedWhenClosed = false

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 380, height: 270))

        // App icon on the left
        let iconView = NSImageView(frame: NSRect(x: 20, y: 195, width: 64, height: 64))
        iconView.image = NSApp.applicationIconImage
        iconView.imageScaling = .scaleProportionallyUpOrDown
        contentView.addSubview(iconView)

        // App name to the right of icon
        let titleLabel = NSTextField(labelWithString: "StepAway")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 18)
        titleLabel.frame = NSRect(x: 100, y: 235, width: 260, height: 22)
        contentView.addSubview(titleLabel)

        // Version
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let versionLabel = NSTextField(labelWithString: "Version \(version)")
        versionLabel.font = NSFont.systemFont(ofSize: 12)
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.frame = NSRect(x: 100, y: 215, width: 260, height: 16)
        contentView.addSubview(versionLabel)

        // Description - below icon, full width
        let descLabel = NSTextField(labelWithString: "A macOS menu bar app that reminds you to take walking breaks.")
        descLabel.font = NSFont.systemFont(ofSize: 11)
        descLabel.textColor = .secondaryLabelColor
        descLabel.frame = NSRect(x: 20, y: 162, width: 340, height: 28)
        descLabel.usesSingleLineMode = false
        descLabel.cell?.wraps = true
        contentView.addSubview(descLabel)

        // Collective attribution - left aligned
        let collectiveLabel = NSTextField(labelWithString: "A product of the")
        collectiveLabel.font = NSFont.systemFont(ofSize: 11)
        collectiveLabel.textColor = .secondaryLabelColor
        collectiveLabel.frame = NSRect(x: 20, y: 130, width: 90, height: 16)
        contentView.addSubview(collectiveLabel)

        let collectiveButton = NSButton(frame: NSRect(x: 106, y: 130, width: 155, height: 16))
        collectiveButton.title = "Apocalyptic Art Collective"
        collectiveButton.bezelStyle = .inline
        collectiveButton.isBordered = false
        collectiveButton.font = NSFont.systemFont(ofSize: 11)
        collectiveButton.contentTintColor = .linkColor
        collectiveButton.target = self
        collectiveButton.action = #selector(openCollective)
        contentView.addSubview(collectiveButton)

        // GitHub link - below collective, left aligned
        let linkButton = NSButton(frame: NSRect(x: 16, y: 112, width: 230, height: 16))
        linkButton.title = "github.com/the-michael-toy/StepAway"
        linkButton.bezelStyle = .inline
        linkButton.isBordered = false
        linkButton.font = NSFont.systemFont(ofSize: 11)
        linkButton.contentTintColor = .linkColor
        linkButton.target = self
        linkButton.action = #selector(openRepo)
        contentView.addSubview(linkButton)

        // Horizontal separator line
        let separator = NSBox(frame: NSRect(x: 20, y: 98, width: 340, height: 1))
        separator.boxType = .separator
        contentView.addSubview(separator)

        // Built with Claude link
        let claudeButton = NSButton(frame: NSRect(x: 16, y: 75, width: 180, height: 16))
        claudeButton.title = "Built with Claude Code"
        claudeButton.bezelStyle = .inline
        claudeButton.isBordered = false
        claudeButton.font = NSFont.systemFont(ofSize: 11)
        claudeButton.contentTintColor = .linkColor
        claudeButton.target = self
        claudeButton.action = #selector(openClaude)
        contentView.addSubview(claudeButton)

        // Disclaimer
        let disclaimerLabel = NSTextField(labelWithString: "This software is provided as-is. It was developed with AI assistance. Please review the source code and exercise your own judgment before use.")
        disclaimerLabel.font = NSFont.systemFont(ofSize: 10)
        disclaimerLabel.textColor = .tertiaryLabelColor
        disclaimerLabel.frame = NSRect(x: 20, y: 38, width: 340, height: 32)
        disclaimerLabel.usesSingleLineMode = false
        disclaimerLabel.cell?.wraps = true
        contentView.addSubview(disclaimerLabel)

        // OK button
        let okButton = NSButton(frame: NSRect(x: 290, y: 10, width: 70, height: 24))
        okButton.title = "OK"
        okButton.bezelStyle = .rounded
        okButton.target = window
        okButton.action = #selector(NSWindow.close)
        okButton.keyEquivalent = "\r"
        contentView.addSubview(okButton)

        window.contentView = contentView
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        aboutWindow = window
        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.closeObserver = nil
            self?.aboutWindow = nil
            self?.onWindowClosed?()
        }
    }

    @objc private func openRepo() {
        if let url = URL(string: "https://github.com/the-michael-toy/StepAway") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openCollective() {
        if let url = URL(string: "https://apocalypticartcollective.com/") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openClaude() {
        if let url = URL(string: "https://claude.ai/claude-code") {
            NSWorkspace.shared.open(url)
        }
    }
}
