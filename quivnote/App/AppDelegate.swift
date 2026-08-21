//
//  AppDelegate.swift
//  quivnote
//

import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let workspace = Workspace()
    private var panelController: NotePanelController?
    private var hotKeyManager: HotKeyManager?
    private var shortcutMonitor: ShortcutMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let panel = NotePanelController(workspace: workspace)
        panelController = panel

        AppMenus.install(workspace: workspace, panel: panel)

        let shortcuts = ShortcutMonitor(workspace: workspace, panel: panel)
        shortcuts.start()
        shortcutMonitor = shortcuts

        hotKeyManager = HotKeyManager {
            panel.toggle()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        workspace.persist()
        shortcutMonitor?.stop()
        hotKeyManager?.tearDown()
    }

    func showNote() {
        panelController?.show()
    }
}
