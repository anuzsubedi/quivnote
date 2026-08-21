//
//  NoteTab.swift
//  quivnote
//

import Foundation
import Observation

@Observable
@MainActor
final class NoteTab: Identifiable {
    let id: UUID
    var libraryID: UUID?
    var title: String
    var text: String {
        didSet {
            if text != oldValue {
                isDirty = true
                if libraryID == nil || title == "Untitled" || title.isEmpty {
                    title = NoteLibrary.title(from: text)
                }
            }
        }
    }
    var isDirty: Bool
    var showPreview: Bool
    var showLineNumbers: Bool

    var displayTitle: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? "Untitled" : trimmedTitle
    }

    init(
        id: UUID = UUID(),
        libraryID: UUID? = nil,
        title: String = "Untitled",
        text: String = "",
        isDirty: Bool = false,
        showPreview: Bool = false,
        showLineNumbers: Bool = false
    ) {
        self.id = id
        self.libraryID = libraryID
        self.title = title
        self.text = text
        self.isDirty = isDirty
        self.showPreview = showPreview
        self.showLineNumbers = showLineNumbers
    }
}

