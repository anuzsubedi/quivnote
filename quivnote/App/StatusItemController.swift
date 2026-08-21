//
//  StatusItemController.swift
//  quivnote
//

import AppKit

@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let optionsMenu = NSMenu()
    private let openNote: () -> Void
    private let newTab: () -> Void
    private let openLibrary: () -> Void
    private let openSettings: () -> Void

    init(
        openNote: @escaping () -> Void,
        newTab: @escaping () -> Void,
        openLibrary: @escaping () -> Void,
        openSettings: @escaping () -> Void
    ) {
        self.openNote = openNote
        self.newTab = newTab
        self.openLibrary = openLibrary
        self.openSettings = openSettings
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        configureButton()
        configureMenu()
    }

    func tearDown() {
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(
            systemSymbolName: "square.and.pencil",
            accessibilityDescription: "Quivnote"
        )
        button.imagePosition = .imageOnly
        button.toolTip = "Open Quivnote"
        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func configureMenu() {
        optionsMenu.autoenablesItems = false
        optionsMenu.addItem(menuItem("New Tab", action: #selector(createNewTab), keyEquivalent: "t"))
        optionsMenu.addItem(menuItem("Open Library…", action: #selector(showLibrary), keyEquivalent: "o"))
        optionsMenu.addItem(menuItem("Settings…", action: #selector(showSettings), keyEquivalent: ","))
        optionsMenu.addItem(.separator())
        optionsMenu.addItem(menuItem("Quit Quivnote", action: #selector(quit), keyEquivalent: "q"))
    }

    private func menuItem(_ title: String, action: Selector, keyEquivalent: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            // Let NSStatusItem position and track its menu. Manually popping the
            // menu from button coordinates can place its first rows above the
            // visible screen, which produces a clipped scrolling menu.
            statusItem.menu = optionsMenu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            openNote()
        }
    }

    @objc private func createNewTab() {
        newTab()
    }

    @objc private func showLibrary() {
        openLibrary()
    }

    @objc private func showSettings() {
        openSettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
