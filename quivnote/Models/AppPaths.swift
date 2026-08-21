//
//  AppPaths.swift
//  quivnote
//

import Foundation

enum AppPaths {
    static let root: URL = {
        let supportDirectories = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )
        let support = supportDirectories.first ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)

        return support.appendingPathComponent("quivnote", isDirectory: true)
    }()

    static let notes = root.appendingPathComponent("notes", isDirectory: true)
    static let workspace = root.appendingPathComponent("workspace.json")
    static let legacyNote = root.appendingPathComponent("note.md")
    static let libraryMigrationFlag = root.appendingPathComponent(".migrated-library")
}
