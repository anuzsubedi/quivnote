//
//  QuivPalette.swift
//  quivnote
//

import AppKit
import SwiftUI

enum QuivPalette {
    // MARK: Adaptive NSColors (auto-resolve for light/dark)

    private static func isDark(_ appearance: NSAppearance) -> Bool {
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    static let nsBase: NSColor = NSColor(name: nil) { a in
        isDark(a) ? NSColor(srgbRed: 0.075, green: 0.078, blue: 0.086, alpha: 1)
                  : NSColor(srgbRed: 0.982, green: 0.979, blue: 0.974, alpha: 1)
    }

    static let nsSurface: NSColor = NSColor(name: nil) { a in
        isDark(a) ? NSColor(srgbRed: 0.105, green: 0.108, blue: 0.118, alpha: 1)
                  : NSColor(srgbRed: 0.946, green: 0.94, blue: 0.93, alpha: 1)
    }

    static let nsRaised: NSColor = NSColor(name: nil) { a in
        isDark(a) ? NSColor(srgbRed: 0.145, green: 0.148, blue: 0.16, alpha: 1)
                  : NSColor(srgbRed: 1.0, green: 0.998, blue: 0.992, alpha: 1)
    }

    static let nsInk: NSColor = NSColor(name: nil) { a in
        isDark(a) ? NSColor(srgbRed: 0.94, green: 0.935, blue: 0.92, alpha: 1)
                  : NSColor(srgbRed: 0.105, green: 0.108, blue: 0.118, alpha: 1)
    }

    static let nsMuted: NSColor = NSColor(name: nil) { a in
        isDark(a) ? NSColor(srgbRed: 0.64, green: 0.625, blue: 0.59, alpha: 1)
                  : NSColor(srgbRed: 0.39, green: 0.38, blue: 0.36, alpha: 1)
    }

    static let nsBorder: NSColor = NSColor(name: nil) { a in
        isDark(a) ? NSColor.white.withAlphaComponent(0.08)
                  : NSColor.black.withAlphaComponent(0.10)
    }

    static let nsBorderSubtle: NSColor = NSColor(name: nil) { a in
        isDark(a) ? NSColor.white.withAlphaComponent(0.04)
                  : NSColor.black.withAlphaComponent(0.05)
    }

    // Accent — reads from user settings (not appearance-dependent)
    static var nsAccent: NSColor {
        AppearanceSettings.shared.accentChoice.nsColor
    }

    // MARK: SwiftUI Color wrappers

    static var base: Color { Color(nsColor: nsBase) }
    static var surface: Color { Color(nsColor: nsSurface) }
    static var raised: Color { Color(nsColor: nsRaised) }
    static var ink: Color { Color(nsColor: nsInk) }
    static var muted: Color { Color(nsColor: nsMuted) }
    static var border: Color { Color(nsColor: nsBorder) }
    static var borderSubtle: Color { Color(nsColor: nsBorderSubtle) }

    static var accent: Color { AppearanceSettings.shared.accentChoice.color }
    static var accentSoft: Color { accent.opacity(0.55) }
    static var onAccent: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            isDark(appearance)
                ? NSColor(srgbRed: 0.08, green: 0.08, blue: 0.09, alpha: 0.88)
                : NSColor.white
        })
    }

    // Semantic surfaces keep interaction states consistent across the editor and sheets.
    static var chrome: Color { surface.opacity(0.72) }
    static var control: Color { ink.opacity(0.055) }
    static var controlHover: Color { ink.opacity(0.09) }
    static var selection: Color { accent.opacity(0.14) }
    static var scrim: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            NSColor.black.withAlphaComponent(isDark(appearance) ? 0.42 : 0.22)
        })
    }
    static var success: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            isDark(appearance)
                ? NSColor(srgbRed: 0.38, green: 0.82, blue: 0.57, alpha: 1)
                : NSColor(srgbRed: 0.12, green: 0.49, blue: 0.29, alpha: 1)
        })
    }

}
