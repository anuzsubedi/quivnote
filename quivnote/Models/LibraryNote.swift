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

extension LibraryNote {
    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case body
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        // Older index files stored the body here. Keep decoding it so those
        // files remain readable, but NoteLibrary will prefer the .md file.
        body = try container.decodeIfPresent(String.self, forKey: .body) ?? ""
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}
