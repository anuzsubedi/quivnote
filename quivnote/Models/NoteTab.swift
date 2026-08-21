//
//  NoteTab.swift
//  quivnote
//

import Foundation
import Observation

enum NoteEditorMode: String, Codable, CaseIterable, Identifiable {
    case wysiwyg
    case preview
    case editor

    var id: Self { self }

    var label: String {
        switch self {
        case .wysiwyg: "WYSIWYG"
        case .preview: "Preview"
        case .editor: "Editor"
        }
    }

    var icon: String {
        switch self {
        case .wysiwyg: "textformat"
        case .preview: "doc.richtext"
        case .editor: "chevron.left.forwardslash.chevron.right"
        }
    }

}

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
    var editorMode: NoteEditorMode
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
        editorMode: NoteEditorMode = .wysiwyg,
        showLineNumbers: Bool = false
    ) {
        self.id = id
        self.libraryID = libraryID
        self.title = title
        self.text = text
        self.isDirty = isDirty
        self.editorMode = editorMode
        self.showLineNumbers = showLineNumbers
    }
}
