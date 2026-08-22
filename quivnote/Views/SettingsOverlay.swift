//
//  SettingsOverlay.swift
//  quivnote
//

import AppKit
import Carbon.HIToolbox
import SwiftUI

struct SettingsOverlay: View {
    @Bindable var workspace: Workspace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Section: String, CaseIterable, Identifiable {
        case appearance, editor, general, data

        var id: Self { self }

        var label: String {
            switch self {
            case .appearance: "Appearance"
            case .editor: "Editor"
            case .general: "General"
            case .data: "Data"
            }
        }
    }

    @State private var section: Section = .appearance

    var body: some View {
        ZStack {
            QuivPalette.scrim
                .ignoresSafeArea()
                .onTapGesture { workspace.hideSettings() }

            VStack(spacing: 0) {
                header
                separator
                HStack(spacing: 0) {
                    sidebar
                    content
                }
            }
            .frame(width: 620, height: 464)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(QuivPalette.base.opacity(0.97))
                if #available(macOS 26, *) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.clear)
                        .glassEffect(
                            .regular.tint(QuivPalette.base.opacity(0.4)),
                            in: .rect(cornerRadius: 14)
                        )
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                QuivPalette.ink.opacity(0.08),
                                QuivPalette.accent.opacity(0.06),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            }
            .shadow(color: .black.opacity(0.38), radius: 34, y: 18)
            .padding(40)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.97)))
    }

    private var separator: some View {
        Rectangle()
            .fill(QuivPalette.border)
            .frame(height: 0.5)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Settings")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(QuivPalette.ink)
            Spacer()
            HStack(spacing: 4) {
                Text("esc")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(QuivPalette.muted.opacity(0.65))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(QuivPalette.ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                Text("to close")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(QuivPalette.muted.opacity(0.55))
            }
            Spacer(minLength: 10)
            Button {
                workspace.hideSettings()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(QuivPalette.muted.opacity(0.75))
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Close Settings")
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Section.allCases) { item in
                sidebarItem(item)
            }
            Spacer()
        }
        .frame(width: 136)
        .padding(.horizontal, 10)
        .padding(.top, 14)
        .padding(.bottom, 14)
        .background(QuivPalette.surface.opacity(0.45))
    }

    private func sidebarItem(_ item: Section) -> some View {
        let selected = section == item
        return Button {
            section = item
        } label: {
            HStack(spacing: 0) {
                Text(item.label)
                    .font(.system(size: 12.5, weight: selected ? .semibold : .medium))
                    .foregroundStyle(selected ? QuivPalette.ink : QuivPalette.muted)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selected ? QuivPalette.control : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.label) settings")
        .accessibilityValue(selected ? "Selected" : "")
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            Group {
                switch section {
                case .appearance: appearanceSection
                case .editor: editorSection
                case .general: generalSection
                case .data: dataSection
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    // MARK: - Appearance

    private var appearanceSettings: AppearanceSettings { AppearanceSettings.shared }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("THEME")
            group {
                row(title: "Mode") {
                    HStack(spacing: 2) {
                        ForEach(AppearanceSettings.Mode.allCases, id: \.self) { mode in
                            segmentedButton(
                                label: mode.label,
                                selected: appearanceSettings.mode == mode
                            ) {
                                appearanceSettings.mode = mode
                            }
                            .accessibilityLabel("\(mode.label) appearance")
                        }
                    }
                    .segmentedBackground()
                    .frame(width: 210)
                }
                row(title: "Accent color", showsDivider: false) {
                    HStack(spacing: 8) {
                        ForEach(AppearanceSettings.AccentChoice.allCases, id: \.self) { choice in
                            accentSwatch(choice)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Editor

    private var editorSettings: GeneralSettings { GeneralSettings.shared }

    private var editorSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("DEFAULTS FOR NEW NOTES")
            group {
                row(title: "Default mode") {
                    HStack(spacing: 2) {
                        ForEach(NoteEditorMode.allCases) { mode in
                            segmentedButton(
                                label: mode.label,
                                selected: editorSettings.defaultEditorMode == mode
                            ) {
                                editorSettings.defaultEditorMode = mode
                            }
                            .accessibilityLabel("Default \(mode.label) mode")
                        }
                    }
                    .segmentedBackground()
                    .frame(width: 220)
                }

                row(title: "Line numbers", subtitle: "Applies to all open and new notes") {
                    quivToggle(editorSettings.defaultLineNumbers) {
                        editorSettings.defaultLineNumbers.toggle()
                        let newValue = editorSettings.defaultLineNumbers
                        for tab in workspace.tabs {
                            tab.showLineNumbers = newValue
                        }
                    }
                }

                row(title: "Font size", subtitle: "Applies to the editor text", showsDivider: false) {
                    HStack(spacing: 8) {
                        Slider(
                            value: Binding(
                                get: { editorSettings.editorFontSize },
                                set: { editorSettings.editorFontSize = $0 }
                            ),
                            in: 12...21,
                            step: 0.5
                        )
                        .tint(QuivPalette.accent)
                        .controlSize(.small)
                        .frame(width: 130)
                        Text("\(Int(editorSettings.editorFontSize))pt")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(QuivPalette.muted)
                            .frame(width: 34, alignment: .trailing)
                    }
                }
            }
        }
    }

    // MARK: - General

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("WINDOW")
            group {
                row(
                    title: "Hide when clicking outside",
                    subtitle: "Dismiss quivnote when you click another window",
                    showsDivider: false
                ) {
                    quivToggle(editorSettings.hideWhenClickingOutside) {
                        editorSettings.hideWhenClickingOutside.toggle()
                    }
                }
            }

            sectionLabel("GLOBAL SHORTCUT")
            group {
                row(title: "Enable hotkey", subtitle: "Show or hide quivnote from anywhere") {
                    quivToggle(editorSettings.hotKeyEnabled) {
                        editorSettings.hotKeyEnabled.toggle()
                    }
                }

                if editorSettings.hotKeyEnabled {
                    row(title: "Shortcut", subtitle: "Click to record", showsDivider: false) {
                        HotKeyRecorder(
                            keyCode: editorSettings.hotKeyCode,
                            modifiers: editorSettings.hotKeyModifiers,
                            onChange: { code, modifiers in
                                editorSettings.hotKeyCode = code
                                editorSettings.hotKeyModifiers = modifiers
                            }
                        )
                        .frame(width: 190)
                    }
                }
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: editorSettings.hotKeyEnabled)
    }

    // MARK: - Data

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("LIBRARY")
            group {
                row(title: "Library folder", subtitle: "~/Library/Application Support/quivnote/notes") {
                    actionButton("Reveal") { workspace.revealLibraryInFinder() }
                }

                row(title: "Export all notes", subtitle: "\(workspace.library.notes.count) notes as markdown files") {
                    actionButton("Export…") { workspace.exportAllNotes() }
                }

                row(title: "Import folder", subtitle: "Add every markdown file in a folder", showsDivider: false) {
                    actionButton("Import…") { workspace.importFolderOfNotes() }
                }
            }
            sectionLabel("MAINTENANCE")
            group {
                row(title: "Reset workspace", subtitle: "Close all tabs and clear state. Library notes are kept.", showsDivider: false) {
                    actionButton("Reset", destructive: true) { workspace.resetWorkspaceState() }
                }
            }
        }
    }

    // MARK: - Shared pieces

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold))
            .tracking(0.3)
            .foregroundStyle(QuivPalette.muted.opacity(0.75))
    }

    /// Inset grouped container with hairline dividers between rows.
    private func group<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(QuivPalette.surface.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(QuivPalette.borderSubtle, lineWidth: 0.5)
        )
    }

    private func row<Trailing: View>(
        title: String,
        subtitle: String? = nil,
        showsDivider: Bool = true,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(QuivPalette.ink)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(QuivPalette.muted.opacity(0.6))
                            .lineLimit(1)
                    }
                }
                Spacer()
                trailing()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

            if showsDivider {
                Rectangle()
                    .fill(QuivPalette.borderSubtle)
                    .frame(height: 0.5)
                    .padding(.leading, 14)
            }
        }
    }

    private func segmentedButton(
        label: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .foregroundStyle(selected ? QuivPalette.ink : QuivPalette.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(selected ? QuivPalette.accent.opacity(0.15) : .clear)
                )
        }
        .buttonStyle(.plain)
        .accessibilityValue(selected ? "Selected" : "")
    }

    private func actionButton(_ label: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(destructive ? Color.red.opacity(0.85) : QuivPalette.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(destructive ? Color.red.opacity(0.08) : QuivPalette.control)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(
                            destructive ? Color.red.opacity(0.18) : QuivPalette.border,
                            lineWidth: 0.5
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private func quivToggle(_ isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? QuivPalette.accent.opacity(0.85) : QuivPalette.ink.opacity(0.14))
                    .frame(width: 34, height: 20)
                Circle()
                    .fill(Color.white)
                    .frame(width: 16, height: 16)
                    .shadow(color: .black.opacity(0.22), radius: 2, y: 1)
                    .padding(2)
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isOn)
        }
        .buttonStyle(.plain)
        .frame(minWidth: 44, minHeight: 26)
        .contentShape(Rectangle())
        .accessibilityLabel(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isButton)
    }

    private func accentSwatch(_ choice: AppearanceSettings.AccentChoice) -> some View {
        let selected = appearanceSettings.accentChoice == choice
        return Button {
            appearanceSettings.accentChoice = choice
        } label: {
            ZStack {
                Circle()
                    .fill(choice.swatchColor)
                    .frame(width: 22, height: 22)
                    .shadow(color: choice.swatchColor.opacity(selected ? 0.3 : 0), radius: 5, y: 2)

                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.black.opacity(0.72))
                }
            }
            .overlay(
                Circle()
                    .strokeBorder(.white.opacity(selected ? 0.3 : 0.1), lineWidth: selected ? 1.5 : 0.5)
            )
            .scaleEffect(selected ? 1.15 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: appearanceSettings.accentChoice)
        }
        .buttonStyle(.plain)
        .help(choice.label)
        .accessibilityLabel("\(choice.label) accent")
        .accessibilityValue(selected ? "Selected" : "")
    }

}

// MARK: - Segmented background helper

private extension View {
    func segmentedBackground() -> some View {
        self
            .padding(2)
            .background(QuivPalette.ink.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(QuivPalette.border, lineWidth: 0.5)
            )
    }
}

// MARK: - HotKey Recorder

struct HotKeyRecorder: View {
    let keyCode: UInt32
    let modifiers: UInt32
    let onChange: (_ keyCode: UInt32, _ modifiers: UInt32) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var recording = false
    @State private var monitor: Any?

    private var displayString: String {
        var symbols = ""
        if modifiers & UInt32(controlKey) != 0 { symbols += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { symbols += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { symbols += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { symbols += "⌘" }
        return symbols + GeneralSettings.keyGlyph(forCode: keyCode)
    }

    var body: some View {
        Button {
            recording ? stopRecording() : startRecording()
        } label: {
            HStack(spacing: 6) {
                Text(recording ? "Press keys…" : displayString)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(recording ? QuivPalette.accent : QuivPalette.ink.opacity(0.85))
                Image(systemName: recording ? "record.circle" : "pencil")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(recording ? Color.red.opacity(0.75) : QuivPalette.muted.opacity(0.55))
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(recording ? QuivPalette.accent.opacity(0.07) : QuivPalette.control)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(
                        recording ? QuivPalette.accent.opacity(0.45) : QuivPalette.border,
                        lineWidth: recording ? 1 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: recording)
        .accessibilityLabel("Global shortcut, currently \(displayString)")
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        guard monitor == nil else { return }
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleKeyDown(event)
            return nil
        }
    }

    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        recording = false
    }

    private func handleKeyDown(_ event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            stopRecording()
            return
        }

        let flags = event.modifierFlags.intersection([.command, .option, .shift, .control])
        guard flags.contains(.command) || flags.contains(.option) || flags.contains(.control),
              event.keyCode != UInt16(kVK_Tab)
        else { return }

        onChange(UInt32(event.keyCode), GeneralSettings.carbonModifiers(from: flags))
        stopRecording()
    }
}

#Preview {
    ZStack {
        QuivPalette.base
        SettingsOverlay(workspace: Workspace())
    }
    .frame(width: 680, height: 520)
}
