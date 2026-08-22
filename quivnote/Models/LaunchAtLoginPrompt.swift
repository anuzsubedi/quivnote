//
//  LaunchAtLoginPrompt.swift
//  quivnote
//

import Foundation
import ServiceManagement

/// Decides when to show the "Launch at login" prompt.
///
/// Shows once on first launch, and if the user answers "later", again at
/// increasing intervals (1 week, then monthly) until they pick yes or never.
@MainActor
enum LaunchAtLoginPrompt {
    enum Answer: Int {
        case none = 0
        case yes = 1
        case later = 2
        case never = 3
    }

    static func shouldShow() -> Bool {
        guard SMAppService.mainApp.status != .enabled else { return false }
        let defaults = UserDefaults.standard
        let answer = Answer(rawValue: defaults.integer(forKey: "quiv.launchAtLogin.answer")) ?? .none
        // Mark that this user had the app before this version introduced the prompt.
        if defaults.object(forKey: "quiv.installed.before.update") == nil {
            let isReturningUser = defaults.object(forKey: "quiv.hotkey.enabled") != nil
                || FileManager.default.fileExists(atPath: AppPaths.workspace.path)
            defaults.set(isReturningUser, forKey: "quiv.installed.before.update")
        }
        switch answer {
        case .none, .yes, .never:
            // ".yes" can regress if the user disables the login item in
            // System Settings; still only show on a fresh install (answer .none).
            return answer == .none
        case .later:
            let lastShown = defaults.object(forKey: "quiv.launchAtLogin.lastPrompt") as? Date ?? .distantPast
            let installsBeforeThisVersion = defaults.bool(forKey: "quiv.installed.before.update")
            let interval: TimeInterval = installsBeforeThisVersion ? 30 * 86400 : 7 * 86400
            return Date.now.timeIntervalSince(lastShown) >= interval
        }
    }

    static func record(answer: Answer) {
        UserDefaults.standard.set(answer.rawValue, forKey: "quiv.launchAtLogin.answer")
        UserDefaults.standard.set(Date.now, forKey: "quiv.launchAtLogin.lastPrompt")
    }

}
