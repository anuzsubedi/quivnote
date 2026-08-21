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

        /// Bright, literal color used only by the appearance picker.
        var swatchColor: Color {
            switch self {
            case .lavender: Color(red: 0.68, green: 0.55, blue: 0.92)
            case .blue: Color(red: 0.40, green: 0.62, blue: 0.95)
            case .teal: Color(red: 0.30, green: 0.72, blue: 0.68)
            case .rose: Color(red: 0.88, green: 0.48, blue: 0.52)
            case .mint: Color(red: 0.35, green: 0.78, blue: 0.62)
            case .amber: Color(red: 0.88, green: 0.70, blue: 0.32)
            }
        }

        /// Adaptive semantic accent with enough weight for text and controls in light mode.
        var nsColor: NSColor {
            NSColor(name: nil) { appearance in
                let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                return switch (self, dark) {
                case (.lavender, false): NSColor(srgbRed: 0.43, green: 0.26, blue: 0.68, alpha: 1)
                case (.blue, false): NSColor(srgbRed: 0.20, green: 0.40, blue: 0.70, alpha: 1)
                case (.teal, false): NSColor(srgbRed: 0.06, green: 0.43, blue: 0.40, alpha: 1)
                case (.rose, false): NSColor(srgbRed: 0.65, green: 0.23, blue: 0.29, alpha: 1)
                case (.mint, false): NSColor(srgbRed: 0.08, green: 0.45, blue: 0.29, alpha: 1)
                case (.amber, false): NSColor(srgbRed: 0.52, green: 0.34, blue: 0.03, alpha: 1)
                case (.lavender, true): NSColor(srgbRed: 0.72, green: 0.61, blue: 0.96, alpha: 1)
                case (.blue, true): NSColor(srgbRed: 0.48, green: 0.68, blue: 0.98, alpha: 1)
                case (.teal, true): NSColor(srgbRed: 0.38, green: 0.78, blue: 0.73, alpha: 1)
                case (.rose, true): NSColor(srgbRed: 0.94, green: 0.57, blue: 0.61, alpha: 1)
                case (.mint, true): NSColor(srgbRed: 0.43, green: 0.83, blue: 0.66, alpha: 1)
                case (.amber, true): NSColor(srgbRed: 0.94, green: 0.76, blue: 0.39, alpha: 1)
                }
            }
        }

        var color: Color { Color(nsColor: nsColor) }

        var label: String { rawValue.capitalized }
    }

    var mode: Mode {
        didSet {
            save()
            NotificationCenter.default.post(name: .quivAppearanceChanged, object: nil)
        }
    }

    var accentChoice: AccentChoice {
        didSet {
            save()
            NotificationCenter.default.post(name: .quivAppearanceChanged, object: nil)
        }
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
