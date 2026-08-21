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
        isDark(a) ? NSColor(srgbRed: 0.09, green: 0.09, blue: 0.10, alpha: 1)
                  : NSColor(srgbRed: 0.98, green: 0.97, blue: 0.96, alpha: 1)
    }

    static let nsSurface: NSColor = NSColor(name: nil) { a in
        isDark(a) ? NSColor(srgbRed: 0.12, green: 0.12, blue: 0.13, alpha: 1)
                  : NSColor(srgbRed: 0.93, green: 0.92, blue: 0.91, alpha: 1)
    }

    static let nsRaised: NSColor = NSColor(name: nil) { a in
        isDark(a) ? NSColor(srgbRed: 0.15, green: 0.15, blue: 0.16, alpha: 1)
                  : NSColor(srgbRed: 1.0, green: 1.0, blue: 0.99, alpha: 1)
    }

    static let nsInk: NSColor = NSColor(name: nil) { a in
        isDark(a) ? NSColor(srgbRed: 0.92, green: 0.91, blue: 0.88, alpha: 1)
                  : NSColor(srgbRed: 0.12, green: 0.12, blue: 0.13, alpha: 1)
    }

    static let nsMuted: NSColor = NSColor(name: nil) { a in
        isDark(a) ? NSColor(srgbRed: 0.52, green: 0.50, blue: 0.46, alpha: 1)
                  : NSColor(srgbRed: 0.48, green: 0.46, blue: 0.42, alpha: 1)
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
        NSColor(AppearanceSettings.shared.accentChoice.color)
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

}
