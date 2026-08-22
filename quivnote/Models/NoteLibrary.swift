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
        do {
            let data = try Data(contentsOf: indexURL)
            let decoded = try JSONDecoder().decode([LibraryNote].self, from: data)
            notes = decoded.map { item in
                var normalized = item
                normalized.title = Self.normalizedTitle(item.title, body: item.body)
                return normalized
            }
            .sorted { $0.updatedAt > $1.updatedAt }
        } catch CocoaError.fileNoSuchFile {
            // Missing index file on first launch is normal; start empty.
            notes = []
        } catch {
            notes = []
            lastError = "Couldn't read note library: \(error.localizedDescription)"
        }
    }

    func note(id: UUID) -> LibraryNote? {
        notes.first { $0.id == id }
    }

    @discardableResult
    func save(id: UUID?, title: String, body: String) throws -> LibraryNote {
        let now = Date()
        let trimmedTitle = Self.normalizedTitle(title, body: body)

        if let id, var existing = note(id: id) {
            existing.title = trimmedTitle
            existing.body = body
            existing.updatedAt = now
            upsert(existing)
            do {
                try writeBody(existing)
                try persistIndex()
                lastError = nil
            } catch let saveError {
                lastError = "Couldn't save \(existing.title): \(saveError.localizedDescription)"
                throw saveError
            }
            return existing
        }

        let created = LibraryNote(
            id: id ?? UUID(),
            title: trimmedTitle,
            body: body,
            createdAt: now,
            updatedAt: now
        )
        upsert(created)
        do {
            try writeBody(created)
            try persistIndex()
            lastError = nil
        } catch let saveError {
            lastError = "Couldn't save \(created.title): \(saveError.localizedDescription)"
            throw saveError
        }
        return created
    }

    func delete(id: UUID) throws {
        notes.removeAll { $0.id == id }
        let file = folder.appendingPathComponent("\(id.uuidString).md")
        do {
            if FileManager.default.fileExists(atPath: file.path) {
                try FileManager.default.removeItem(at: file)
            }
            try persistIndex()
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
        upsert(note)
        do {
            try persistIndex()
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

    private func upsert(_ note: LibraryNote) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = note
        } else {
            notes.insert(note, at: 0)
        }
        notes.sort { $0.updatedAt > $1.updatedAt }
    }

    private func writeBody(_ note: LibraryNote) throws {
        let file = folder.appendingPathComponent("\(note.id.uuidString).md")
        try note.body.write(to: file, atomically: true, encoding: .utf8)
    }

    private func persistIndex() throws {
        let data = try JSONEncoder().encode(notes)
        try data.write(to: indexURL, options: .atomic)
    }
}
