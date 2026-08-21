//
//  ShortcutMonitor.swift
//  quivnote
//

import AppKit
import Carbon.HIToolbox

/// Menu key-equivalents are unreliable for accessory / MenuBarExtra apps.
/// This local monitor is the source of truth while the note panel is key.
@MainActor
final class ShortcutMonitor {
    private var keyDownMonitor: Any?
    private var flagsMonitor: Any?
    private var cmdHoldTask: Task<Void, Never>?
    private var commandHeldAlone = false

    private let workspace: Workspace
    private let panel: NotePanelController

    init(workspace: Workspace, panel: NotePanelController) {
        self.workspace = workspace
        self.panel = panel
    }

    func start() {
        stop()

        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handleKeyDown(event)
        }

        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self else { return event }
            self.handleFlagsChanged(event)
            return event
        }
    }

    func stop() {
        cmdHoldTask?.cancel()
        cmdHoldTask = nil
        if let keyDownMonitor {
            NSEvent.removeMonitor(keyDownMonitor)
            self.keyDownMonitor = nil
        }
        if let flagsMonitor {
            NSEvent.removeMonitor(flagsMonitor)
            self.flagsMonitor = nil
        }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        guard panel.isVisible else { return }

        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        let cmdDown = flags.contains(.command)
        let onlyCommand = cmdDown && flags == .command

        if onlyCommand {
            guard !commandHeldAlone else { return }
            commandHeldAlone = true
            cmdHoldTask?.cancel()
            cmdHoldTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(380))
                guard !Task.isCancelled, self.commandHeldAlone, self.panel.isVisible else { return }
                self.workspace.showShortcutsOverlay()
            }
        } else {
            let wasHolding = commandHeldAlone
            commandHeldAlone = false
            cmdHoldTask?.cancel()
            cmdHoldTask = nil
            if wasHolding || (!cmdDown && !workspace.shortcutsPinned) {
                workspace.hideShortcutsOverlay()
            }
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        // Any key while holding ⌘ cancels the hold-to-reveal gesture
        if commandHeldAlone {
            commandHeldAlone = false
            cmdHoldTask?.cancel()
            cmdHoldTask = nil
            if !workspace.shortcutsPinned {
                workspace.hideShortcutsOverlay()
            }
        }

        // Escape — dismiss overlay / library / find / panel
        if event.keyCode == UInt16(kVK_Escape) {
            guard panel.isVisible else { return event }
            if workspace.shortcutsVisible {
                workspace.shortcutsPinned = false
                workspace.hideShortcutsOverlay(force: true)
                return nil
            }
            if workspace.settingsVisible {
                workspace.hideSettings()
                return nil
            }
            if workspace.libraryVisible {
                if workspace.isLibraryRenaming {
                    // Let the rename field handle typing; Esc cancels
                    if event.keyCode == UInt16(kVK_Escape) {
                        workspace.cancelLibraryRename()
                        return nil
                    }
                    return event
                }
                workspace.hideLibrary()
                return nil
            }
            if workspace.pendingCloseTabID != nil {
                workspace.cancelPendingClose()
                return nil
            }
            if workspace.findVisible {
                workspace.hideFind()
            } else {
                panel.hide()
            }
            return nil
        }

        guard panel.isKey else { return event }

        // Unsaved-close bar takes over navigation while visible
        if workspace.pendingCloseTabID != nil {
            return handlePendingCloseKeys(event)
        }

        // Library browser keyboard mode
        if workspace.libraryVisible {
            return handleLibraryKeys(event)
        }

        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        let cmd = flags.contains(.command)
        let shift = flags.contains(.shift)
        let opt = flags.contains(.option)
        let ctrl = flags.contains(.control)
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""

        // ⌃Tab / ⌃⇧Tab — next / previous tab
        if ctrl && !cmd && !opt && event.keyCode == UInt16(kVK_Tab) {
            if shift {
                workspace.selectPreviousTab()
            } else {
                workspace.selectNextTab()
            }
            return nil
        }

        guard cmd else { return event }

        // ⌘⌥⇧N is owned by HotKeyManager (global)
        if opt && shift && key == "n" {
            return event
        }

        // ⌘/ — pin / unpin shortcuts sheet
        if !shift && !opt && !ctrl && (key == "/" || event.keyCode == UInt16(kVK_ANSI_Slash)) {
            workspace.toggleShortcutsPinned()
            return nil
        }

        // ⌘, — appearance settings
        if !shift && !opt && !ctrl && (key == "," || event.keyCode == UInt16(kVK_ANSI_Comma)) {
            if workspace.settingsVisible {
                workspace.hideSettings()
            } else {
                workspace.showSettings()
            }
            return nil
        }

        switch (key, shift, opt, ctrl) {
        case ("n", false, false, false), ("t", false, false, false):
            workspace.newTab()
            return nil
        case ("o", false, false, false):
            workspace.showLibrary()
            return nil
        case ("s", false, false, false):
            _ = workspace.saveToLibrary()
            return nil
        case ("i", true, false, false):
            workspace.importFromFilesystem()
            return nil
        case ("e", true, false, false):
            workspace.exportToFilesystem()
            return nil
        case ("w", false, false, false):
            workspace.closeSelectedTab()
            return nil
        case ("f", false, false, false):
            workspace.showFind(replace: false)
            return nil
        case ("h", false, false, false):
            workspace.showFind(replace: true)
            return nil
        case ("m", false, false, false):
            workspace.togglePreview()
            NotificationCenter.default.post(name: .quivFocusEditor, object: nil)
            return nil
        case ("l", false, false, false):
            workspace.toggleLineNumbers()
            return nil
        case ("]", true, false, false):
            workspace.selectNextTab()
            return nil
        case ("[", true, false, false):
            workspace.selectPreviousTab()
            return nil
        default:
            return event
        }
    }

    private func handlePendingCloseKeys(_ event: NSEvent) -> NSEvent? {
        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""

        // ← / → or ⇥ / ⇧⇥
        if event.keyCode == UInt16(kVK_LeftArrow) || (event.keyCode == UInt16(kVK_Tab) && flags.contains(.shift)) {
            workspace.movePendingCloseFocus(forward: false)
            return nil
        }
        if event.keyCode == UInt16(kVK_RightArrow) || (event.keyCode == UInt16(kVK_Tab) && !flags.contains(.command)) {
            workspace.movePendingCloseFocus(forward: true)
            return nil
        }

        // Return / Enter — activate focused action
        if event.keyCode == UInt16(kVK_Return) || event.keyCode == UInt16(kVK_ANSI_KeypadEnter) {
            workspace.activatePendingCloseFocus()
            return nil
        }

        // Shortcuts without needing focus
        if key == "s" && (flags == .command || flags.isEmpty) {
            workspace.confirmPendingCloseSave()
            return nil
        }
        if key == "d" && (flags == .command || flags.isEmpty) {
            workspace.confirmPendingCloseDiscard()
            return nil
        }
        if key == "c" && flags.isEmpty {
            workspace.cancelPendingClose()
            return nil
        }

        // Block editor typing while the prompt is up
        return nil
    }

    private func handleLibraryKeys(_ event: NSEvent) -> NSEvent? {
        // While renaming, only Esc is intercepted above; Return commits via TextField.
        // Also handle Return here if rename field didn't.
        if workspace.isLibraryRenaming {
            if event.keyCode == UInt16(kVK_Return) || event.keyCode == UInt16(kVK_ANSI_KeypadEnter) {
                workspace.commitLibraryRename()
                return nil
            }
            return event
        }

        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        let key = event.charactersIgnoringModifiers ?? ""
        let lower = key.lowercased()

        if event.keyCode == UInt16(kVK_UpArrow) {
            workspace.moveLibraryFocus(forward: false)
            return nil
        }
        if event.keyCode == UInt16(kVK_DownArrow) {
            workspace.moveLibraryFocus(forward: true)
            return nil
        }
        if event.keyCode == UInt16(kVK_Return) || event.keyCode == UInt16(kVK_ANSI_KeypadEnter) {
            workspace.openFocusedLibraryNote()
            return nil
        }
        if event.keyCode == UInt16(kVK_Delete) || event.keyCode == UInt16(kVK_ForwardDelete) {
            if flags.contains(.command) || event.keyCode == UInt16(kVK_ForwardDelete) {
                workspace.deleteFocusedLibraryNote()
                return nil
            }
            // Backspace edits the search query
            if !workspace.libraryQuery.isEmpty {
                workspace.deleteLibrarySearchCharacter()
                return nil
            }
            return nil
        }

        if flags == .command && lower == "r" {
            workspace.beginRenameFocusedLibraryNote()
            return nil
        }

        // Type-to-search
        if flags.isEmpty || flags == .shift {
            if key.count == 1,
               let scalar = key.unicodeScalars.first,
               CharacterSet.alphanumerics
                .union(.punctuationCharacters)
                .union(.symbols)
                .union(.whitespaces)
                .contains(scalar) {
                workspace.appendLibrarySearch(key)
                return nil
            }
        }

        return nil
    }
}
