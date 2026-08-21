//
//  AppMenus.swift
//  quivnote
//

import AppKit

/// Menus for discoverability. Shortcuts are handled by `ShortcutMonitor`
/// because accessory apps don't reliably receive menu key-equivalents.
@MainActor
enum AppMenus {
    private static var handlers: [MenuAction] = []

    static func install(workspace: Workspace, panel: NotePanelController) {
        handlers.removeAll()
        let main = NSMenu()

        let appMenu = NSMenu()
        let appItem = NSMenuItem()
        appItem.submenu = appMenu
        main.addItem(appItem)
        appMenu.addItem(withTitle: "About Quivnote", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(retain(MenuAction(title: "Settings…         ⌘,") {
            panel.show(); workspace.showSettings()
        }))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit Quivnote", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let fileMenu = NSMenu(title: "File")
        let fileItem = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
        fileItem.submenu = fileMenu
        main.addItem(fileItem)

        fileMenu.addItem(retain(MenuAction(title: "New Tab           ⌘T") {
            panel.show(); workspace.newTab()
        }))
        fileMenu.addItem(retain(MenuAction(title: "Open Library…     ⌘O") {
            panel.show(); workspace.showLibrary()
        }))
        fileMenu.addItem(retain(MenuAction(title: "Save to Library   ⌘S") {
            panel.show(); _ = workspace.saveToLibrary()
        }))
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(retain(MenuAction(title: "Import…         ⌘⇧I") {
            panel.show(); workspace.importFromFilesystem()
        }))
        fileMenu.addItem(retain(MenuAction(title: "Export…         ⌘⇧E") {
            panel.show(); workspace.exportToFilesystem()
        }))
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(retain(MenuAction(title: "Close Tab         ⌘W") {
            workspace.closeSelectedTab()
        }))

        let editMenu = NSMenu(title: "Edit")
        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        editItem.submenu = editMenu
        main.addItem(editItem)

        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenu.addItem(NSMenuItem.separator())
        let formatMenu = NSMenu(title: "Format")
        let formatItem = NSMenuItem(title: "Format", action: nil, keyEquivalent: "")
        formatItem.submenu = formatMenu
        editMenu.addItem(formatItem)
        formatMenu.addItem(withTitle: "Bold", action: Selector(("quivToggleBold:")), keyEquivalent: "b")
        formatMenu.addItem(withTitle: "Italic", action: Selector(("quivToggleItalic:")), keyEquivalent: "i")
        formatMenu.addItem(withTitle: "Underline", action: Selector(("quivToggleUnderline:")), keyEquivalent: "u")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(retain(MenuAction(title: "Find…             ⌘F") {
            panel.show(); workspace.showFind(replace: false)
        }))
        editMenu.addItem(retain(MenuAction(title: "Find & Replace…   ⌘H") {
            panel.show(); workspace.showFind(replace: true)
        }))

        let viewMenu = NSMenu(title: "View")
        let viewItem = NSMenuItem(title: "View", action: nil, keyEquivalent: "")
        viewItem.submenu = viewMenu
        main.addItem(viewItem)

        viewMenu.addItem(retain(MenuAction(title: "Shortcuts         ⌘/") {
            panel.show(); workspace.toggleShortcutsPinned()
        }))
        viewMenu.addItem(retain(MenuAction(title: "Cycle Editor Mode  ⌘M") {
            panel.show()
            workspace.cycleEditorMode()
            NotificationCenter.default.post(name: .quivFocusEditor, object: nil)
        }))
        viewMenu.addItem(retain(MenuAction(title: "Line Numbers      ⌘L") {
            panel.show(); workspace.toggleLineNumbers()
        }))
        viewMenu.addItem(NSMenuItem.separator())
        viewMenu.addItem(retain(MenuAction(title: "Next Tab        ⌘⇧]") {
            workspace.selectNextTab()
        }))
        viewMenu.addItem(retain(MenuAction(title: "Previous Tab    ⌘⇧[") {
            workspace.selectPreviousTab()
        }))

        let windowMenu = NSMenu(title: "Window")
        let windowItem = NSMenuItem(title: "Window", action: nil, keyEquivalent: "")
        windowItem.submenu = windowMenu
        main.addItem(windowItem)
        windowMenu.addItem(retain(MenuAction(title: "Show Note     ⌘⌥⇧N") {
            panel.show()
        }))

        NSApp.mainMenu = main
    }

    @discardableResult
    private static func retain(_ item: MenuAction) -> MenuAction {
        handlers.append(item)
        return item
    }
}

@MainActor
private final class MenuAction: NSMenuItem {
    private let handler: () -> Void

    init(title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func run() {
        handler()
    }
}
