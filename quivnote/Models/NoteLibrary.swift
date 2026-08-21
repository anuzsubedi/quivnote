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

    private let folder: URL
    private let indexURL: URL

    init() {
        folder = AppPaths.notes
        indexURL = folder.appendingPathComponent("index.json")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        reload()
    }

    func reload() {
        guard let data = try? Data(contentsOf: indexURL),
              let decoded = try? JSONDecoder().decode([LibraryNote].self, from: data)
        else {
            notes = []
            return
        }
        notes = decoded.map { item in
            var normalized = item
            normalized.title = Self.normalizedTitle(item.title, body: item.body)
            return normalized
        }
        .sorted { $0.updatedAt > $1.updatedAt }
    }

    func note(id: UUID) -> LibraryNote? {
        notes.first { $0.id == id }
    }

    @discardableResult
    func save(id: UUID?, title: String, body: String) -> LibraryNote {
        let now = Date()
        let trimmedTitle = Self.normalizedTitle(title, body: body)

        if let id, var existing = note(id: id) {
            existing.title = trimmedTitle
            existing.body = body
            existing.updatedAt = now
            upsert(existing)
            writeBody(existing)
            persistIndex()
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
        writeBody(created)
        persistIndex()
        return created
    }

    func delete(id: UUID) {
        notes.removeAll { $0.id == id }
        let file = folder.appendingPathComponent("\(id.uuidString).md")
        try? FileManager.default.removeItem(at: file)
        persistIndex()
    }

    func rename(id: UUID, title: String) {
        guard var note = note(id: id) else { return }
        note.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Untitled"
            : title.trimmingCharacters(in: .whitespacesAndNewlines)
        note.updatedAt = Date()
        upsert(note)
        persistIndex()
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

    private func writeBody(_ note: LibraryNote) {
        let file = folder.appendingPathComponent("\(note.id.uuidString).md")
        try? note.body.write(to: file, atomically: true, encoding: .utf8)
    }

    private func persistIndex() {
        guard let data = try? JSONEncoder().encode(notes) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }
}
