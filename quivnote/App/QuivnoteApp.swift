//
//  QuivnoteApp.swift
//  quivnote
//

import AppKit
import SwiftUI

@main
struct QuivnoteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Quivnote", systemImage: "square.and.pencil") {
            Button("Open Note") {
                appDelegate.showNote()
            }
            .keyboardShortcut("n", modifiers: [.command, .option, .shift])

            Divider()

            Button("New Tab") {
                appDelegate.showNote()
                appDelegate.workspace.newTab()
            }
            .keyboardShortcut("t", modifiers: .command)

            Button("Open Library…") {
                appDelegate.showNote()
                appDelegate.workspace.showLibrary()
            }
            .keyboardShortcut("o", modifiers: .command)

            Button("Settings…") {
                appDelegate.showNote()
                appDelegate.workspace.showSettings()
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button("Quit Quivnote") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
