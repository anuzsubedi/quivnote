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
        Settings {
            EmptyView()
        }
    }
}
