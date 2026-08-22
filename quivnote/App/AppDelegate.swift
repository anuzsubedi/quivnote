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
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let panel = NotePanelController(workspace: workspace)
        panelController = panel

        AppMenus.install(workspace: workspace, panel: panel)

        let shortcuts = ShortcutMonitor(workspace: workspace, panel: panel)
        shortcuts.start()
        shortcutMonitor = shortcuts

        let workspaceModel = workspace
        statusItemController = StatusItemController(
            openNote: { panel.show() },
            newTab: {
                panel.show()
                workspaceModel.newTab()
            },
            openLibrary: {
                panel.show()
                workspaceModel.showLibrary()
            },
            openSettings: {
                panel.show()
                workspaceModel.showSettings()
            }
        )

        hotKeyManager = HotKeyManager {
            panel.toggle()
        }

        NotificationCenter.default.addObserver(
            forName: .quivHotKeyChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.hotKeyManager?.register()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        workspace.persist()
        shortcutMonitor?.stop()
        hotKeyManager?.tearDown()
        statusItemController?.tearDown()
        panelController?.tearDown()
    }

    func showNote() {
        panelController?.show()
    }
}
