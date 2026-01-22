// SPDX-License-Identifier: CC0-1.0
// This file is part of StepAway - https://github.com/the-michael-toy/StepAway

import Foundation

class AppSettings {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let timerInterval = "timerInterval"
        static let idleInterval = "idleInterval"
        static let launchAtLogin = "launchAtLogin"
        static let isEnabled = "isEnabled"
        static let showStillThereDialog = "showStillThereDialog"
        static let playWarningSound = "playWarningSound"
        static let warningSound = "warningSound"
    }

    var timerInterval: TimeInterval {
        get {
            let value = defaults.double(forKey: Keys.timerInterval)
            return value > 0 ? value : 90 * 60 // Default: 90 minutes
        }
        set {
            defaults.set(newValue, forKey: Keys.timerInterval)
        }
    }

    var idleInterval: TimeInterval {
        get {
            let value = defaults.double(forKey: Keys.idleInterval)
            return value > 0 ? value : 3 * 60 // Default: 3 minutes
        }
        set {
            defaults.set(newValue, forKey: Keys.idleInterval)
        }
    }

    var launchAtLogin: Bool {
        get {
            return defaults.bool(forKey: Keys.launchAtLogin)
        }
        set {
            defaults.set(newValue, forKey: Keys.launchAtLogin)
        }
    }

    var isEnabled: Bool {
        get {
            // Default to true if not set
            if defaults.object(forKey: Keys.isEnabled) == nil {
                return true
            }
            return defaults.bool(forKey: Keys.isEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.isEnabled)
        }
    }

    var showStillThereDialog: Bool {
        get {
            if defaults.object(forKey: Keys.showStillThereDialog) == nil {
                return true
            }
            return defaults.bool(forKey: Keys.showStillThereDialog)
        }
        set {
            defaults.set(newValue, forKey: Keys.showStillThereDialog)
        }
    }

    var playWarningSound: Bool {
        get {
            if defaults.object(forKey: Keys.playWarningSound) == nil {
                return true
            }
            return defaults.bool(forKey: Keys.playWarningSound)
        }
        set {
            defaults.set(newValue, forKey: Keys.playWarningSound)
        }
    }

    var warningSound: String {
        get {
            return defaults.string(forKey: Keys.warningSound) ?? "Glass"
        }
        set {
            defaults.set(newValue, forKey: Keys.warningSound)
        }
    }

    fileprivate init() {}
}
