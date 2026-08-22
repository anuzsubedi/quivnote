//
//  Workspace.swift
//  quivnote
//

import AppKit
import Foundation
import UniformTypeIdentifiers

import Observation

@Observable
@MainActor
final class Workspace {
    var tabs: [NoteTab] = []
    var selectedID: UUID?
    var findVisible = false
    var replaceVisible = false
    var findQuery = ""
    var replaceQuery = ""
    var findStatus = ""
    var shortcutsVisible = false
    var shortcutsPinned = false
    var libraryVisible = false
    var settingsVisible = false
    var libraryQuery = ""
    var libraryFocusID: UUID?
    var libraryRenamingID: UUID?
    var libraryRenameDraft = ""
    var saveFlash = false
    /// Non-nil when the most recent library or workspace write failed; drives
    /// the error banner in the editor status bar until the next successful op.
    var storageError: String?
    /// Inline “unsaved changes” prompt for a tab about to close.
    var pendingCloseTabID: UUID?
    var pendingCloseFocus: PendingCloseAction = .save

    enum PendingCloseAction: Int, CaseIterable {
        case cancel
        case discard
        case save
    }

    let library = NoteLibrary()

    var selectedTab: NoteTab? {
        guard let selectedID else { return nil }
        return tabs.first { $0.id == selectedID }
    }

    var filteredLibraryNotes: [LibraryNote] {
        let q = libraryQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return library.notes }
        return library.notes.filter {
            $0.title.lowercased().contains(q) || $0.body.lowercased().contains(q)
        }
    }

    var focusedLibraryNote: LibraryNote? {
        guard let libraryFocusID else { return nil }
        return filteredLibraryNotes.first { $0.id == libraryFocusID }
    }

    var isLibraryRenaming: Bool {
        libraryRenamingID != nil
    }

    private let stateURL: URL

    init() {
        try? FileManager.default.createDirectory(at: AppPaths.root, withIntermediateDirectories: true)
        stateURL = AppPaths.workspace
        loadState()
        migrateLegacyIfNeeded()
        if tabs.isEmpty {
            _ = newTab()
        }
    }

    @discardableResult
    func newTab(text: String = "", libraryID: UUID? = nil, title: String? = nil) -> NoteTab {
        let resolvedTitle = title ?? NoteLibrary.title(from: text)
        let settings = GeneralSettings.shared
        let tab = NoteTab(
            libraryID: libraryID,
            title: resolvedTitle,
            text: text,
            isDirty: libraryID == nil && !text.isEmpty,
            editorMode: settings.defaultEditorMode,
            showLineNumbers: settings.defaultLineNumbers
        )
        tabs.append(tab)
        selectedID = tab.id
        libraryVisible = false
        persist()
        return tab
    }

    func closeSelectedTab() {
        guard let id = selectedID else { return }
        closeTab(id: id)
    }

    func closeTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        let tab = tabs[index]

        if tab.isDirty {
            selectedID = id
            pendingCloseFocus = .save
            pendingCloseTabID = id
            persist()
            return
        }

        finishClose(at: index)
    }

    var pendingCloseTab: NoteTab? {
        guard let pendingCloseTabID else { return nil }
        return tabs.first { $0.id == pendingCloseTabID }
    }

    func cancelPendingClose() {
        pendingCloseTabID = nil
        pendingCloseFocus = .save
    }

    func movePendingCloseFocus(forward: Bool) {
        guard pendingCloseTabID != nil else { return }
        let all = PendingCloseAction.allCases
        guard let index = all.firstIndex(of: pendingCloseFocus) else { return }
        let next = forward
            ? (index + 1) % all.count
            : (index - 1 + all.count) % all.count
        pendingCloseFocus = all[next]
    }

    func activatePendingCloseFocus() {
        switch pendingCloseFocus {
        case .cancel:
            cancelPendingClose()
        case .discard:
            confirmPendingCloseDiscard()
        case .save:
            confirmPendingCloseSave()
        }
    }

    func confirmPendingCloseSave() {
        guard let id = pendingCloseTabID else { return }
        selectedID = id
        guard saveToLibrary() else { return }
        pendingCloseTabID = nil
        pendingCloseFocus = .save
        closeTab(id: id)
    }

    func confirmPendingCloseDiscard() {
        guard let id = pendingCloseTabID,
              let index = tabs.firstIndex(where: { $0.id == id })
        else {
            pendingCloseTabID = nil
            return
        }
        tabs[index].isDirty = false
        pendingCloseTabID = nil
        pendingCloseFocus = .save
        finishClose(at: index)
    }

    private func finishClose(at index: Int) {
        let wasSelected = selectedID == tabs[index].id
        if pendingCloseTabID == tabs[index].id {
            pendingCloseTabID = nil
        }
        tabs.remove(at: index)
        if tabs.isEmpty {
            _ = newTab()
        } else if wasSelected {
            let next = min(index, tabs.count - 1)
            selectedID = tabs[next].id
        }
        persist()
    }

    func selectNextTab() {
        guard let id = selectedID, let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        selectedID = tabs[(index + 1) % tabs.count].id
        persist()
    }

    func selectPreviousTab() {
        guard let id = selectedID, let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        selectedID = tabs[(index - 1 + tabs.count) % tabs.count].id
        persist()
    }

    func selectTab(id: UUID) {
        selectedID = id
        persist()
    }

    func setEditorMode(_ mode: NoteEditorMode) {
        selectedTab?.editorMode = mode
        persist()
    }

    func cycleEditorMode() {
        guard let tab = selectedTab,
              let index = NoteEditorMode.allCases.firstIndex(of: tab.editorMode)
        else { return }
        tab.editorMode = NoteEditorMode.allCases[(index + 1) % NoteEditorMode.allCases.count]
        persist()
    }

    func toggleLineNumbers() {
        selectedTab?.showLineNumbers.toggle()
        persist()
    }

    func showFind(replace: Bool) {
        libraryVisible = false
        findVisible = true
        replaceVisible = replace
    }

    func hideFind() {
        findVisible = false
        replaceVisible = false
        findStatus = ""
    }

    func showShortcutsOverlay() {
        libraryVisible = false
        shortcutsVisible = true
    }

    func hideShortcutsOverlay(force: Bool = false) {
        guard force || !shortcutsPinned else { return }
        shortcutsVisible = false
    }

    func toggleShortcutsPinned() {
        if shortcutsPinned {
            shortcutsPinned = false
            shortcutsVisible = false
        } else {
            libraryVisible = false
            shortcutsPinned = true
            shortcutsVisible = true
        }
    }

    // MARK: - Library (⌘S / ⌘O)

    func showLibrary() {
        shortcutsVisible = false
        shortcutsPinned = false
        settingsVisible = false
        findVisible = false
        library.reload()
        libraryQuery = ""
        libraryRenamingID = nil
        libraryVisible = true
        syncLibraryFocus(reset: true)
    }

    // MARK: - Settings (⌘,)

    func showSettings() {
        shortcutsVisible = false
        shortcutsPinned = false
        libraryVisible = false
        findVisible = false
        settingsVisible = true
    }

    func hideSettings() {
        settingsVisible = false
    }

    func hideLibrary() {
        libraryVisible = false
        libraryQuery = ""
        libraryFocusID = nil
        libraryRenamingID = nil
        libraryRenameDraft = ""
    }

    func syncLibraryFocus(reset: Bool = false) {
        let notes = filteredLibraryNotes
        guard !notes.isEmpty else {
            libraryFocusID = nil
            return
        }
        if reset || libraryFocusID == nil || !notes.contains(where: { $0.id == libraryFocusID }) {
            libraryFocusID = notes[0].id
            return
        }
    }

    func moveLibraryFocus(forward: Bool) {
        let notes = filteredLibraryNotes
        guard !notes.isEmpty else {
            libraryFocusID = nil
            return
        }
        guard let current = libraryFocusID,
              let index = notes.firstIndex(where: { $0.id == current })
        else {
            libraryFocusID = notes[0].id
            return
        }
        let next = forward
            ? min(index + 1, notes.count - 1)
            : max(index - 1, 0)
        libraryFocusID = notes[next].id
    }

    func openFocusedLibraryNote() {
        guard let note = focusedLibraryNote else { return }
        openLibraryNote(note)
    }

    func beginRenameFocusedLibraryNote() {
        guard let note = focusedLibraryNote else { return }
        libraryRenamingID = note.id
        libraryRenameDraft = note.title
    }

    func commitLibraryRename() {
        guard let id = libraryRenamingID,
              let note = library.note(id: id)
        else {
            libraryRenamingID = nil
            return
        }
        renameLibraryNote(note, to: libraryRenameDraft)
        libraryRenamingID = nil
        libraryRenameDraft = ""
    }

    func cancelLibraryRename() {
        libraryRenamingID = nil
        libraryRenameDraft = ""
    }

    func deleteFocusedLibraryNote() {
        guard let note = focusedLibraryNote else { return }
        let notesBefore = filteredLibraryNotes
        let index = notesBefore.firstIndex(where: { $0.id == note.id }) ?? 0
        deleteLibraryNote(note)
        let notes = filteredLibraryNotes
        if notes.isEmpty {
            libraryFocusID = nil
        } else {
            libraryFocusID = notes[min(index, notes.count - 1)].id
        }
    }

    func appendLibrarySearch(_ character: String) {
        libraryQuery += character
        syncLibraryFocus(reset: true)
    }

    func deleteLibrarySearchCharacter() {
        guard !libraryQuery.isEmpty else { return }
        libraryQuery.removeLast()
        syncLibraryFocus(reset: true)
    }

    @discardableResult
    func saveToLibrary() -> Bool {
        guard let tab = selectedTab else { return false }
        let saved: LibraryNote
        do {
            saved = try library.save(id: tab.libraryID, title: tab.title, body: tab.text)
        } catch {
            storageError = library.lastError ?? "Couldn't save note."
            return false
        }
        tab.libraryID = saved.id
        tab.title = saved.title
        tab.isDirty = false
        storageError = nil
        persist()
        flashSaved()
        return true
    }

    func openLibraryNote(_ note: LibraryNote) {
        if let existing = tabs.first(where: { $0.libraryID == note.id }) {
            selectedID = existing.id
            hideLibrary()
            persist()
            return
        }

        if let blank = selectedTab, blank.libraryID == nil, blank.text.isEmpty, !blank.isDirty {
            blank.libraryID = note.id
            blank.title = note.title
            blank.text = note.body
            blank.isDirty = false
            hideLibrary()
            persist()
            NotificationCenter.default.post(name: .quivReloadText, object: blank.id.uuidString)
            return
        }

        _ = newTab(text: note.body, libraryID: note.id, title: note.title)
        if let tab = selectedTab {
            tab.isDirty = false
        }
        hideLibrary()
        persist()
    }

    @discardableResult
    private func deleteLibraryNote(_ note: LibraryNote) -> Bool {
        do {
            try library.delete(id: note.id)
        } catch {
            presentAlert(title: "Couldn't delete", message: library.lastError ?? "Unknown error.")
            return false
        }
        for tab in tabs where tab.libraryID == note.id {
            tab.libraryID = nil
            tab.isDirty = true
        }
        persist()
        return true
    }

    func renameLibraryNote(_ note: LibraryNote, to title: String) {
        do {
            try library.rename(id: note.id, title: title)
        } catch {
            presentAlert(title: "Couldn't rename", message: library.lastError ?? "Unknown error.")
            return
        }
        for tab in tabs where tab.libraryID == note.id {
            tab.title = library.note(id: note.id)?.title ?? title
        }
        persist()
    }

    // MARK: - Import / Export (filesystem)

    func importFromFilesystem() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText, UTType(filenameExtension: "md")].compactMap { $0 }
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.message = "Import markdown or text into your library"
        guard panel.runModal() == .OK else { return }

        for url in panel.urls {
            importURL(url)
        }
    }

    func exportToFilesystem() {
        guard let tab = selectedTab else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.nameFieldStringValue = "\(tab.displayTitle).md"
        panel.canCreateDirectories = true
        panel.message = "Export a copy to your Mac"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try tab.text.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            presentAlert(title: "Couldn’t export", message: error.localizedDescription)
        }
    }

    private func importURL(_ url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
        else {
            presentAlert(title: "Couldn't import", message: url.lastPathComponent)
            return
        }

        let title = url.deletingPathExtension().lastPathComponent
        let saved: LibraryNote
        do {
            saved = try library.save(id: nil, title: title, body: text)
        } catch {
            presentAlert(title: "Couldn't import", message: library.lastError ?? "Unknown error.")
            return
        }
        openLibraryNote(saved)
    }

    // MARK: - Data management

    func revealLibraryInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([AppPaths.notes])
    }

    func exportAllNotes() {
        guard !library.notes.isEmpty else {
            presentAlert(title: "Nothing to export", message: "Your library is empty.")
            return
        }

        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.message = "Choose a folder to export all \(library.notes.count) notes"
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        let accessed = folder.startAccessingSecurityScopedResource()
        defer { if accessed { folder.stopAccessingSecurityScopedResource() } }

        do {
            var usedNames = Set<String>()
            for note in library.notes {
                var base = note.title.replacingOccurrences(of: "/", with: "-")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if base.isEmpty { base = "Untitled" }
                var name = base
                var counter = 2
                while usedNames.contains(name.lowercased()) {
                    name = "\(base) \(counter)"
                    counter += 1
                }
                usedNames.insert(name.lowercased())
                try note.body.write(
                    to: folder.appendingPathComponent("\(name).md"),
                    atomically: true,
                    encoding: .utf8
                )
            }
            presentAlert(title: "Exported", message: "\(library.notes.count) notes written to \(folder.lastPathComponent).")
        } catch {
            presentAlert(title: "Couldn’t export", message: error.localizedDescription)
        }
    }

    func importFolderOfNotes() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.message = "Import every markdown file in a folder"
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        let accessed = folder.startAccessingSecurityScopedResource()
        defer { if accessed { folder.stopAccessingSecurityScopedResource() } }

        let urls = ((try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [])
            .filter {
                ["md", "markdown", "txt"].contains($0.pathExtension.lowercased())
            }
        guard !urls.isEmpty else {
            presentAlert(title: "Nothing to import", message: "No markdown files found in that folder.")
            return
        }

        var imported = 0
        for url in urls {
            let innerAccessed = url.startAccessingSecurityScopedResource()
            defer { if innerAccessed { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url),
                  let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
            else { continue }
            do {
                _ = try library.save(id: nil, title: url.deletingPathExtension().lastPathComponent, body: text)
            } catch {
                presentAlert(title: "Couldn't import", message: library.lastError ?? "Unknown error.")
                return
            }
            imported += 1
        }

        if imported > 0 {
            presentAlert(title: "Imported", message: "\(imported) notes added to your library.")
        } else {
            presentAlert(title: "Couldn’t import", message: "None of the files could be read.")
        }
    }

    func resetWorkspaceState() {
        let alert = NSAlert()
        alert.messageText = "Reset workspace?"
        alert.informativeText = "Closes all tabs and clears workspace state. Notes saved in your library are kept."
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        tabs.removeAll()
        selectedID = nil
        pendingCloseTabID = nil
        pendingCloseFocus = .save
        findVisible = false
        replaceVisible = false
        try? FileManager.default.removeItem(at: stateURL)
        _ = newTab()
    }

    // MARK: - Find / Replace

    func findNext(forward: Bool = true) {
        guard let tab = selectedTab, !findQuery.isEmpty else {
            findStatus = ""
            return
        }
        NotificationCenter.default.post(
            name: .quivFind,
            object: nil,
            userInfo: [
                "query": findQuery,
                "forward": forward,
                "tabID": tab.id.uuidString,
            ]
        )
    }

    func replaceOne() {
        guard let tab = selectedTab, !findQuery.isEmpty else { return }
        NotificationCenter.default.post(
            name: .quivReplaceOne,
            object: nil,
            userInfo: [
                "query": findQuery,
                "replacement": replaceQuery,
                "tabID": tab.id.uuidString,
            ]
        )
    }

    func replaceAll() {
        guard let tab = selectedTab, !findQuery.isEmpty else { return }
        let count = tab.text.components(separatedBy: findQuery).count - 1
        guard count > 0 else {
            findStatus = "No matches"
            return
        }
        tab.text = tab.text.replacingOccurrences(of: findQuery, with: replaceQuery)
        findStatus = "Replaced \(count)"
        NotificationCenter.default.post(name: .quivReloadText, object: tab.id.uuidString)
    }

    func setFindStatus(_ status: String) {
        findStatus = status
    }

    // MARK: - Persistence

    func persist() {
        let payload = PersistedWorkspace(
            selectedID: selectedID?.uuidString,
            tabs: tabs.map {
                PersistedTab(
                    id: $0.id.uuidString,
                    libraryID: $0.libraryID?.uuidString,
                    title: $0.title,
                    text: $0.text,
                    isDirty: $0.isDirty,
                    editorMode: $0.editorMode,
                    showPreview: nil,
                    showLineNumbers: $0.showLineNumbers
                )
            }
        )
        do {
            let data = try JSONEncoder().encode(payload)
            try data.write(to: stateURL, options: .atomic)
        } catch {
            storageError = "Workspace state not saved: \(error.localizedDescription)"
        }
    }

    private func loadState() {
        guard let data = try? Data(contentsOf: stateURL),
              let payload = try? JSONDecoder().decode(PersistedWorkspace.self, from: data)
        else { return }

        // Skip legacy schema that used filePath / untitledCounter without libraryID field shape
        if payload.tabs.isEmpty { return }

        tabs = payload.tabs.map { item in
            NoteTab(
                id: UUID(uuidString: item.id) ?? UUID(),
                libraryID: item.libraryID.flatMap(UUID.init(uuidString:)),
                title: NoteLibrary.normalizedTitle(item.title ?? "", body: item.text ?? ""),
                text: item.text ?? "",
                isDirty: item.isDirty,
                editorMode: item.editorMode
                    ?? (item.showPreview == true ? .preview : GeneralSettings.shared.defaultEditorMode),
                showLineNumbers: item.showLineNumbers
            )
        }

        if let sid = payload.selectedID, let uuid = UUID(uuidString: sid), tabs.contains(where: { $0.id == uuid }) {
            selectedID = uuid
        } else {
            selectedID = tabs.first?.id
        }
    }

    private func migrateLegacyIfNeeded() {
        // Pull any leftover single note.md into the library once
        let legacy = AppPaths.legacyNote
        let flag = AppPaths.libraryMigrationFlag
        guard !FileManager.default.fileExists(atPath: flag.path),
              let text = try? String(contentsOf: legacy, encoding: .utf8),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return }

        let saved: LibraryNote
        do {
            saved = try library.save(id: nil, title: NoteLibrary.title(from: text), body: text)
        } catch {
            // Migration failure is non-fatal; leave the legacy file in place.
            return
        }
        if tabs.isEmpty || (tabs.count == 1 && tabs[0].text.isEmpty) {
            tabs = [NoteTab(libraryID: saved.id, title: saved.title, text: saved.body, isDirty: false)]
            selectedID = tabs[0].id
        }
        try? "1".write(to: flag, atomically: true, encoding: .utf8)
        persist()
    }

    private func flashSaved() {
        saveFlash = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1200))
            saveFlash = false
        }
    }

    private func presentAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}

private struct PersistedWorkspace: Codable {
    var selectedID: String?
    var tabs: [PersistedTab]
}

private struct PersistedTab: Codable {
    var id: String
    var libraryID: String?
    var title: String?
    var text: String?
    var isDirty: Bool
    var editorMode: NoteEditorMode?
    /// Kept optional so workspace files from the two-mode editor still decode.
    var showPreview: Bool?
    var showLineNumbers: Bool
}

extension Notification.Name {
    static let quivFind = Notification.Name("quivnote.find")
    static let quivReplaceOne = Notification.Name("quivnote.replaceOne")
    static let quivReloadText = Notification.Name("quivnote.reloadText")
    static let quivFocusEditor = Notification.Name("quivnote.focusEditor")
    static let quivAppearanceChanged = Notification.Name("quivnote.appearanceChanged")
    static let quivGeneralSettingsChanged = Notification.Name("quivnote.generalSettingsChanged")
    static let quivHotKeyChanged = Notification.Name("quivnote.hotKeyChanged")
}
