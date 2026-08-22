//
//  HotKeyManager.swift
//  quivnote
//

import AppKit
import Carbon
import Observation

@Observable
@MainActor
final class HotKeyManager {
    private static weak var currentManager: HotKeyManager?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let onHotKey: () -> Void
    private var handlerError: String?
    private var isUpdatingHotKey = false
    private var isActive = true

    private(set) var registrationError: String?
    private(set) var isRegistered = false

    init(onHotKey: @escaping () -> Void) {
        self.onHotKey = onHotKey
        Self.currentManager = self
        installHandler()
        register()
    }

    func tearDown() {
        guard isActive else { return }
        isActive = false
        if Self.currentManager === self {
            Self.currentManager = nil
        }
        unregister()
        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
    }

    /// Updates the configured shortcut as one registration transaction.
    static func updateHotKey(keyCode: UInt32, modifiers: UInt32) {
        guard let manager = currentManager else {
            let settings = GeneralSettings.shared
            settings.hotKeyCode = keyCode
            settings.hotKeyModifiers = modifiers
            return
        }
        manager.applyHotKeyUpdate(keyCode: keyCode, modifiers: modifiers)
    }

    /// (Re)registers the global hotkey from GeneralSettings.
    func register() {
        guard isActive, !isUpdatingHotKey else { return }
        unregister()

        let settings = GeneralSettings.shared
        guard settings.hotKeyEnabled else {
            registrationError = handlerError
            return
        }

        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x51564E54), id: 1) // 'QVNT'
        let status = RegisterEventHotKey(
            settings.hotKeyCode,
            settings.hotKeyModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard status == noErr else {
            registrationError = "RegisterEventHotKey failed with OSStatus \(status)."
            return
        }
        self.hotKeyRef = hotKeyRef
        isRegistered = handlerError == nil && hotKeyRef != nil
        registrationError = handlerError
    }

    private func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        isRegistered = false
    }

    private func applyHotKeyUpdate(keyCode: UInt32, modifiers: UInt32) {
        guard isActive else { return }

        let settings = GeneralSettings.shared
        let wasUpdatingHotKey = isUpdatingHotKey
        isUpdatingHotKey = true
        defer {
            isUpdatingHotKey = wasUpdatingHotKey
            if !wasUpdatingHotKey {
                register()
            }
        }

        settings.hotKeyCode = keyCode
        settings.hotKeyModifiers = modifiers
    }

    private func installHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let userData = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let userData else { return noErr }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                guard manager.isActive else { return noErr }
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                if hotKeyID.id == 1 {
                    DispatchQueue.main.async { [weak manager] in
                        guard let manager, manager.isActive else { return }
                        manager.onHotKey()
                    }
                }
                return noErr
            },
            1,
            &eventType,
            userData,
            &handlerRef
        )

        guard status == noErr else {
            let message = "InstallEventHandler failed with OSStatus \(status)."
            handlerError = message
            registrationError = message
            return
        }
    }
}
