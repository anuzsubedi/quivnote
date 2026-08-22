//
//  GeneralSettings.swift
//  quivnote
//

import AppKit
import Carbon.HIToolbox
import CoreGraphics
import Observation

@Observable
@MainActor
final class GeneralSettings {
    static let shared = GeneralSettings()

    // MARK: - Editor defaults

    var defaultEditorMode: NoteEditorMode {
        didSet {
            save()
            NotificationCenter.default.post(name: .quivGeneralSettingsChanged, object: nil)
        }
    }

    var defaultLineNumbers: Bool {
        didSet {
            save()
            NotificationCenter.default.post(name: .quivGeneralSettingsChanged, object: nil)
        }
    }

    var editorFontSize: Double {
        didSet {
            guard editorFontSize != oldValue else { return }
            save()
            NotificationCenter.default.post(name: .quivGeneralSettingsChanged, object: nil)
        }
    }

    // MARK: - Window behavior

    var hideWhenClickingOutside: Bool {
        didSet {
            guard hideWhenClickingOutside != oldValue else { return }
            save()
            NotificationCenter.default.post(name: .quivGeneralSettingsChanged, object: nil)
        }
    }

    // MARK: - Global hotkey

    var hotKeyEnabled: Bool {
        didSet {
            save()
            NotificationCenter.default.post(name: .quivHotKeyChanged, object: nil)
        }
    }

    /// Carbon virtual keycode (kVK_ANSI_*).
    var hotKeyCode: UInt32 {
        didSet {
            guard hotKeyCode != oldValue else { return }
            save()
            NotificationCenter.default.post(name: .quivHotKeyChanged, object: nil)
        }
    }

    /// Carbon modifier mask (cmdKey | optionKey | shiftKey | controlKey).
    var hotKeyModifiers: UInt32 {
        didSet {
            guard hotKeyModifiers != oldValue else { return }
            save()
            NotificationCenter.default.post(name: .quivHotKeyChanged, object: nil)
        }
    }

    var nsModifierFlags: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if hotKeyModifiers & UInt32(cmdKey) != 0 { flags.insert(.command) }
        if hotKeyModifiers & UInt32(optionKey) != 0 { flags.insert(.option) }
        if hotKeyModifiers & UInt32(shiftKey) != 0 { flags.insert(.shift) }
        if hotKeyModifiers & UInt32(controlKey) != 0 { flags.insert(.control) }
        return flags
    }

    /// Human-readable glyph for a virtual keycode (letters, digits, punctuation).
    static func keyGlyph(forCode code: UInt32) -> String {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(code), keyDown: true)
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0
        event?.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: &chars)
        let glyph = String(String(decoding: chars.prefix(length), as: UTF16.self)).uppercased()
        return glyph.isEmpty ? "?" : glyph
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        return carbon
    }

    // MARK: - Persistence

    private init() {
        let defaults = UserDefaults.standard
        defaultEditorMode = NoteEditorMode(
            rawValue: defaults.string(forKey: "quiv.editor.mode") ?? ""
        ) ?? .wysiwyg
        defaultLineNumbers = defaults.bool(forKey: "quiv.editor.lineNumbers")
        let storedSize = defaults.double(forKey: "quiv.editor.fontSize")
        editorFontSize = storedSize == 0 ? 15.5 : storedSize
        hideWhenClickingOutside = defaults.bool(forKey: "quiv.window.hideOnOutsideClick")

        hotKeyEnabled = defaults.object(forKey: "quiv.hotkey.enabled") as? Bool ?? true
        let storedCode = defaults.object(forKey: "quiv.hotkey.keyCode") as? UInt32
        hotKeyCode = storedCode ?? UInt32(kVK_ANSI_N)
        let storedModifiers = defaults.object(forKey: "quiv.hotkey.modifiers") as? UInt32
        hotKeyModifiers = storedModifiers ?? UInt32(cmdKey | optionKey | shiftKey)
    }

    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(defaultEditorMode.rawValue, forKey: "quiv.editor.mode")
        defaults.set(defaultLineNumbers, forKey: "quiv.editor.lineNumbers")
        defaults.set(editorFontSize, forKey: "quiv.editor.fontSize")
        defaults.set(hideWhenClickingOutside, forKey: "quiv.window.hideOnOutsideClick")
        defaults.set(hotKeyEnabled, forKey: "quiv.hotkey.enabled")
        defaults.set(hotKeyCode, forKey: "quiv.hotkey.keyCode")
        defaults.set(hotKeyModifiers, forKey: "quiv.hotkey.modifiers")
    }
}
