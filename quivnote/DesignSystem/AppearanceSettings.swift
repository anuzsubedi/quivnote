//
//  AppearanceSettings.swift
//  quivnote
//

import AppKit
import Observation
import SwiftUI

@Observable
@MainActor
final class AppearanceSettings {
    static let shared = AppearanceSettings()

    enum Mode: String, CaseIterable {
        case system, light, dark

        var label: String {
            switch self {
            case .system: "System"
            case .light: "Light"
            case .dark: "Dark"
            }
        }

        var icon: String {
            switch self {
            case .system: "circle.lefthalf.filled"
            case .light: "sun.max.fill"
            case .dark: "moon.fill"
            }
        }

        var nsAppearance: NSAppearance? {
            switch self {
            case .system: nil
            case .light: NSAppearance(named: .aqua)
            case .dark: NSAppearance(named: .darkAqua)
            }
        }
    }

    enum AccentChoice: String, CaseIterable {
        case lavender, blue, teal, rose, mint, amber

        var color: Color {
            switch self {
            case .lavender: Color(red: 0.68, green: 0.55, blue: 0.92)
            case .blue: Color(red: 0.40, green: 0.62, blue: 0.95)
            case .teal: Color(red: 0.30, green: 0.72, blue: 0.68)
            case .rose: Color(red: 0.88, green: 0.48, blue: 0.52)
            case .mint: Color(red: 0.35, green: 0.78, blue: 0.62)
            case .amber: Color(red: 0.88, green: 0.70, blue: 0.32)
            }
        }

        var label: String { rawValue.capitalized }
    }

    var mode: Mode {
        didSet {
            save()
            NotificationCenter.default.post(name: .quivAppearanceChanged, object: nil)
        }
    }

    var accentChoice: AccentChoice {
        didSet { save() }
    }

    private init() {
        let defaults = UserDefaults.standard
        mode = Mode(rawValue: defaults.string(forKey: "quiv.appearance.mode") ?? "") ?? .system
        accentChoice = AccentChoice(rawValue: defaults.string(forKey: "quiv.appearance.accent") ?? "") ?? .lavender
    }

    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(mode.rawValue, forKey: "quiv.appearance.mode")
        defaults.set(accentChoice.rawValue, forKey: "quiv.appearance.accent")
    }
}
