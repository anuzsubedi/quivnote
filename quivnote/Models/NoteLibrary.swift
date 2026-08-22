//
//  NoteLibrary.swift
//  quivnote
//

import Foundation
import MarkdownUI
import Observation

@Observable
@MainActor
final class NoteLibrary {
    private(set) var notes: [LibraryNote] = []

    /// Set when the most recent load, save, delete, or index write failed.
    private(set) var lastError: String?

    private let folder: URL
    private let indexURL: URL

    init() {
        folder = AppPaths.notes
        indexURL = folder.appendingPathComponent("index.json")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            reload()
        } catch {
            lastError = "Couldn't create notes folder: \(error.localizedDescription)"
        }
    }

    func reload() {
        let decoded: [LibraryNote]
        do {
            let data = try Data(contentsOf: indexURL)
            decoded = try JSONDecoder().decode([LibraryNote].self, from: data)
        } catch CocoaError.fileNoSuchFile {
            // Missing index file on first launch is normal; start empty.
            notes = []
            return
        } catch {
            let backupMessage: String
            do {
                let backup = try quarantineCorruptFile(at: indexURL)
                backupMessage = " A copy was saved as \(backup.lastPathComponent)."
            } catch let backupError {
                backupMessage = " The corrupt index could not be backed up: \(backupError.localizedDescription)."
            }
            notes = []
            lastError = "Couldn't decode note library index: \(error.localizedDescription).\(backupMessage)"
            return
        }

        do {
            notes = try decoded.map { item in
                var normalized = item
                let bodyURL = bodyURL(for: item.id)
                if FileManager.default.fileExists(atPath: bodyURL.path) {
                    normalized.body = try String(contentsOf: bodyURL, encoding: .utf8)
                }
                normalized.title = Self.normalizedTitle(normalized.title, body: normalized.body)
                return normalized
            }
            .sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            notes = []
            lastError = "Couldn't read note library bodies: \(error.localizedDescription)"
            return
        }
    }

    func note(id: UUID) -> LibraryNote? {
        notes.first { $0.id == id }
    }

    @discardableResult
    func save(id: UUID?, title: String, body: String) throws -> LibraryNote {
        let now = Date()
        let trimmedTitle = Self.normalizedTitle(title, body: body)

        let saved: LibraryNote
        let updatedNotes: [LibraryNote]
        if let id, var existing = note(id: id) {
            existing.title = trimmedTitle
            existing.body = body
            existing.updatedAt = now
            saved = existing
            updatedNotes = replacing(existing)
        } else {
            saved = LibraryNote(
                id: id ?? UUID(),
                title: trimmedTitle,
                body: body,
                createdAt: now,
                updatedAt: now
            )
            updatedNotes = replacing(saved)
        }

        do {
            try persist(notes: updatedNotes, bodyToWrite: saved)
            notes = updatedNotes
            lastError = nil
        } catch let saveError {
            lastError = "Couldn't save \(saved.title): \(saveError.localizedDescription)"
            throw saveError
        }
        return saved
    }

    func delete(id: UUID) throws {
        let updatedNotes = notes.filter { $0.id != id }
        do {
            try persist(notes: updatedNotes, bodyToRemove: id)
            notes = updatedNotes
            lastError = nil
        } catch let deleteError {
            lastError = "Couldn't delete note: \(deleteError.localizedDescription)"
            throw deleteError
        }
    }

    func rename(id: UUID, title: String) throws {
        guard var note = note(id: id) else { return }
        note.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Untitled"
            : title.trimmingCharacters(in: .whitespacesAndNewlines)
        note.updatedAt = Date()
        let updatedNotes = replacing(note)
        do {
            try persist(notes: updatedNotes)
            notes = updatedNotes
            lastError = nil
        } catch let renameError {
            lastError = "Couldn't rename \(note.title): \(renameError.localizedDescription)"
            throw renameError
        }
    }

    static func title(from body: String) -> String {
        normalizedTitle("", body: body)
    }

    static func normalizedTitle(_ title: String, body: String) -> String {
        let explicit = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !explicit.isEmpty, explicit != "Untitled" {
            let normalized = plainText(from: explicit)
            if !normalized.isEmpty { return String(normalized.prefix(80)) }
        }
        for line in body.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let normalized = plainText(from: trimmed)
            if !normalized.isEmpty { return String(normalized.prefix(80)) }
        }
        return "Untitled"
    }

    private static func plainText(from markdown: String) -> String {
        var plain = MarkdownContent(markdown).renderPlainText()
        plain = plain.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
        plain = plain.replacingOccurrences(of: #"^\s*(?:[-+*]|\d+[.)]|>)+\s*"#, with: "", options: .regularExpression)
        plain = plain.replacingOccurrences(of: #"^\s*\[[ xX]\]\s*"#, with: "", options: .regularExpression)
        let markerCharacters = CharacterSet(charactersIn: "*_~`#<>/ \t")
        return plain
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: markerCharacters)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func replacing(_ note: LibraryNote) -> [LibraryNote] {
        var updatedNotes = notes
        if let index = updatedNotes.firstIndex(where: { $0.id == note.id }) {
            updatedNotes[index] = note
        } else {
            updatedNotes.insert(note, at: 0)
        }
        return updatedNotes.sorted { $0.updatedAt > $1.updatedAt }
    }

    private func bodyURL(for id: UUID) -> URL {
        folder.appendingPathComponent("\(id.uuidString).md")
    }

    private func persist(
        notes candidateNotes: [LibraryNote],
        bodyToWrite: LibraryNote? = nil,
        bodyToRemove: UUID? = nil
    ) throws {
        let fileManager = FileManager.default
        let indexTemporaryURL = temporaryURL(for: indexURL)
        var bodyTemporaryURL: URL?
        var indexBackupURL: URL?
        var bodyBackupURL: URL?
        var bodyCommitStarted = false
        var indexCommitStarted = false
        let bodyDestinationURL = bodyToWrite.map { bodyURL(for: $0.id) }
            ?? bodyToRemove.map(bodyURL(for:))
        let indexOriginallyExisted = fileManager.fileExists(atPath: indexURL.path)
        let bodyOriginallyExisted = bodyDestinationURL.map {
            fileManager.fileExists(atPath: $0.path)
        } ?? false

        do {
            let data = try JSONEncoder().encode(candidateNotes)
            try data.write(to: indexTemporaryURL)

            if let bodyToWrite, let bodyDestinationURL {
                let temporaryURL = temporaryURL(for: bodyDestinationURL)
                try bodyToWrite.body.write(to: temporaryURL, atomically: false, encoding: .utf8)
                bodyTemporaryURL = temporaryURL
            }

            if indexOriginallyExisted {
                let backupURL = temporaryURL(for: indexURL)
                try fileManager.copyItem(at: indexURL, to: backupURL)
                indexBackupURL = backupURL
            }
            if let bodyDestinationURL, bodyOriginallyExisted {
                let backupURL = temporaryURL(for: bodyDestinationURL)
                try fileManager.copyItem(at: bodyDestinationURL, to: backupURL)
                bodyBackupURL = backupURL
            }

            if let bodyToWrite, let bodyDestinationURL, let bodyTemporaryURL {
                bodyCommitStarted = true
                try atomicallyReplace(bodyTemporaryURL, at: bodyDestinationURL)
                removeIfExists(bodyTemporaryURL)
            } else if bodyToRemove != nil, let bodyDestinationURL {
                bodyCommitStarted = true
                if fileManager.fileExists(atPath: bodyDestinationURL.path) {
                    try fileManager.removeItem(at: bodyDestinationURL)
                }
            }

            indexCommitStarted = true
            try atomicallyReplace(indexTemporaryURL, at: indexURL)
            cleanup(backups: [indexBackupURL, bodyBackupURL])
        } catch {
            var rollbackError: Error?
            do {
                if bodyCommitStarted, let bodyDestinationURL {
                    try restore(
                        destination: bodyDestinationURL,
                        backup: bodyBackupURL,
                        originallyExisted: bodyOriginallyExisted
                    )
                }
                if indexCommitStarted {
                    try restore(
                        destination: indexURL,
                        backup: indexBackupURL,
                        originallyExisted: indexOriginallyExisted
                    )
                }
            } catch let error {
                rollbackError = error
            }
            cleanup(backups: rollbackError == nil ? [indexBackupURL, bodyBackupURL] : [])
            removeIfExists(indexTemporaryURL)
            if let bodyTemporaryURL {
                removeIfExists(bodyTemporaryURL)
            }
            if let rollbackError {
                throw TransactionRollbackError(writeError: error, rollbackError: rollbackError)
            }
            throw error
        }

        removeIfExists(indexTemporaryURL)
        if let bodyTemporaryURL {
            removeIfExists(bodyTemporaryURL)
        }
    }

    private func temporaryURL(for url: URL) -> URL {
        url.deletingLastPathComponent()
            .appendingPathComponent(".\(url.lastPathComponent).tmp-\(UUID().uuidString)")
    }

    private func atomicallyReplace(_ temporaryURL: URL, at destinationURL: URL) throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destinationURL.path) {
            _ = try fileManager.replaceItemAt(
                destinationURL,
                withItemAt: temporaryURL,
                backupItemName: nil,
                options: []
            )
        } else {
            try fileManager.moveItem(at: temporaryURL, to: destinationURL)
        }
    }

    private func restore(destination: URL, backup: URL?, originallyExisted: Bool) throws {
        let fileManager = FileManager.default
        if originallyExisted {
            guard let backup, fileManager.fileExists(atPath: backup.path) else { return }
            try atomicallyReplace(backup, at: destination)
        } else if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
    }

    private func cleanup(backups: [URL?]) {
        for backup in backups.compactMap({ $0 }) {
            removeIfExists(backup)
        }
    }

    private func removeIfExists(_ url: URL) {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else { return }
        try? fileManager.removeItem(at: url)
    }

    private func quarantineCorruptFile(at url: URL) throws -> URL {
        let fileManager = FileManager.default
        let directory = url.deletingLastPathComponent()
        let timestamp = Int(Date().timeIntervalSince1970)
        var destination = directory.appendingPathComponent(
            "\(url.lastPathComponent).corrupt-\(timestamp)"
        )
        var suffix = 1
        while fileManager.fileExists(atPath: destination.path) {
            destination = directory.appendingPathComponent(
                "\(url.lastPathComponent).corrupt-\(timestamp)-\(suffix)"
            )
            suffix += 1
        }
        try fileManager.copyItem(at: url, to: destination)
        return destination
    }
}

private struct TransactionRollbackError: LocalizedError {
    let writeError: Error
    let rollbackError: Error

    var errorDescription: String? {
        "\(writeError.localizedDescription); rollback also failed: \(rollbackError.localizedDescription)"
    }
}
