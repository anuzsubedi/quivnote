//
//  NotePanelController.swift
//  quivnote
//

import AppKit
import SwiftUI

private final class NotePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@Observable
final class PanelFocus {
    private(set) var generation = 0

    @MainActor
    func request() {
        generation += 1
    }
}

@MainActor
final class NotePanelController {
    private var panel: NSPanel?
    private let workspace: Workspace
    private let focus = PanelFocus()
    private var appearanceObserver: NSObjectProtocol?
    private var outsideClickLocalMonitor: Any?
    private var outsideClickGlobalMonitor: Any?

    init(workspace: Workspace) {
        self.workspace = workspace
        observeAppearanceChanges()
    }

    var focusBus: PanelFocus { focus }

    var isVisible: Bool {
        panel?.isVisible == true
    }

    var isKey: Bool {
        guard let panel else { return false }
        return panel.isVisible && (panel.isKeyWindow || NSApp.keyWindow === panel)
    }

    @discardableResult
    func performEditingAction(_ action: Selector) -> Bool {
        guard let responder = panel?.firstResponder else { return false }
        if NSApp.sendAction(action, to: responder, from: nil) { return true }
        return NSApp.sendAction(action, to: nil, from: nil)
    }

    func toggle() {
        if let panel, panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        let panel = panel ?? makePanel()
        self.panel = panel

        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            let size = panel.frame.size
            let origin = NSPoint(
                x: frame.midX - size.width / 2,
                y: frame.midY - size.height / 2 + 20
            )
            panel.setFrameOrigin(origin)
        }

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        focus.request()

        for delay in [0.0, 0.05, 0.12] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak panel] in
                guard let panel else { return }
                NSApp.activate(ignoringOtherApps: true)
                panel.makeKeyAndOrderFront(nil)
                self.focus.request()
                NotificationCenter.default.post(name: .quivFocusEditor, object: nil)
            }
        }
    }

    func hide() {
        workspace.persist()
        panel?.orderOut(nil)
    }

    func tearDown() {
        if let outsideClickLocalMonitor {
            NSEvent.removeMonitor(outsideClickLocalMonitor)
            self.outsideClickLocalMonitor = nil
        }
        if let outsideClickGlobalMonitor {
            NSEvent.removeMonitor(outsideClickGlobalMonitor)
            self.outsideClickGlobalMonitor = nil
        }
        if let appearanceObserver {
            NotificationCenter.default.removeObserver(appearanceObserver)
            self.appearanceObserver = nil
        }
    }

    func syncAppearance() {
        panel?.appearance = AppearanceSettings.shared.mode.nsAppearance
    }

    private func observeAppearanceChanges() {
        appearanceObserver = NotificationCenter.default.addObserver(
            forName: .quivAppearanceChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.syncAppearance()
            }
        }
    }

    private func makePanel() -> NSPanel {
        let panel = NotePanel(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 580),
            styleMask: [.borderless, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.minSize = NSSize(width: 520, height: 360)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.appearance = AppearanceSettings.shared.mode.nsAppearance

        let root = NoteEditorView(
            workspace: workspace,
            focus: focus
        )
        let hosting = NSHostingView(rootView: root)
        hosting.frame = NSRect(origin: .zero, size: panel.frame.size)
        hosting.autoresizingMask = [.width, .height]
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = hosting
        installOutsideClickMonitors(for: panel)

        return panel
    }

    private func installOutsideClickMonitors(for panel: NSPanel) {
        let mouseEvents: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]

        outsideClickLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: mouseEvents) { [weak self, weak panel] event in
            guard let self,
                  let panel,
                  panel.isVisible,
                  GeneralSettings.shared.hideWhenClickingOutside,
                  event.window !== panel
            else { return event }

            self.hide()
            return event
        }

        outsideClickGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mouseEvents) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self,
                      self.isVisible,
                      GeneralSettings.shared.hideWhenClickingOutside
                else { return }
                self.hide()
            }
        }
    }
}
