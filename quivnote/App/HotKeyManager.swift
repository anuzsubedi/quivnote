//
//  HotKeyManager.swift
//  quivnote
//

import AppKit
import Carbon

@MainActor
final class HotKeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let onHotKey: () -> Void

    init(onHotKey: @escaping () -> Void) {
        self.onHotKey = onHotKey
        installHandler()
        register()
    }

    func tearDown() {
        unregister()
        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
    }

    /// (Re)registers the global hotkey from GeneralSettings.
    func register() {
        unregister()

        let settings = GeneralSettings.shared
        guard settings.hotKeyEnabled else { return }

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
        guard status == noErr else { return }
        self.hotKeyRef = hotKeyRef
    }

    private func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
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
                    DispatchQueue.main.async {
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

        guard status == noErr else { return }
    }
}
