//
//  LibraryNote.swift
//  quivnote
//

import Foundation

struct LibraryNote: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var title: String
    var body: String
    var createdAt: Date
    var updatedAt: Date

    var preview: String {
        let lines = body
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
        return lines.first ?? "Empty note"
    }
}

