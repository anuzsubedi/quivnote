//
//  ContentView.swift
//  quivnote
//

import MarkdownUI
import SwiftUI

struct NoteEditorView: View {
    private enum SearchField: Hashable { case find, replace }
    private enum CloseActionStyle: Equatable { case neutral, destructive, primary }

    @Bindable var workspace: Workspace
    var focus: PanelFocus

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focusedSearchField: SearchField?
    @State private var hoveredTabID: UUID?
    @State private var hoveredToolbarItem: String?

    var body: some View {
        let currentAccent = AppearanceSettings.shared.accentChoice
        ZStack {
            background

            VStack(spacing: 0) {
                chromeHeader
                separator
                tabBar
                if workspace.findVisible {
                    findBar
                    separator
                }
                editorArea

                if workspace.pendingCloseTabID != nil {
                    unsavedCloseBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            if workspace.libraryVisible {
                LibraryBrowser(workspace: workspace)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }

            if workspace.shortcutsVisible {
                ShortcutsOverlay(pinned: workspace.shortcutsPinned) {
                    workspace.shortcutsPinned = false
                    workspace.hideShortcutsOverlay(force: true)
                }
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }

            if workspace.settingsVisible {
                SettingsOverlay(workspace: workspace)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .tint(currentAccent.color)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: workspace.shortcutsVisible)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: workspace.libraryVisible)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: workspace.settingsVisible)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: workspace.pendingCloseTabID)
        .frame(minWidth: 520, minHeight: 360)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            QuivPalette.ink.opacity(0.10),
                            QuivPalette.accent.opacity(0.08),
                            QuivPalette.ink.opacity(0.05),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        }
        .onChange(of: focus.generation) { _, _ in
            NotificationCenter.default.post(name: .quivFocusEditor, object: nil)
        }
        .onChange(of: workspace.findVisible) { _, visible in
            focusedSearchField = visible ? .find : nil
        }
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(QuivPalette.base.opacity(0.94))
            if #available(macOS 26, *) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.clear)
                    .glassEffect(
                        .regular.tint(QuivPalette.base.opacity(0.5)),
                        in: .rect(cornerRadius: 14)
                    )
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
        }
    }

    // MARK: - Separator

    private var separator: some View {
        Rectangle()
            .fill(QuivPalette.border)
            .frame(height: 0.5)
    }

    // MARK: - Chrome Header

    private var chromeHeader: some View {
        HStack(spacing: 8) {
            // App wordmark
            HStack(spacing: 5) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(QuivPalette.accent.opacity(0.14))
                    Image(systemName: "pencil.line")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(QuivPalette.accent)
                }
                .frame(width: 22, height: 22)
                Text("quivnote")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .tracking(0.15)
                    .foregroundStyle(QuivPalette.ink.opacity(0.78))
            }

            Spacer()

            if let tab = workspace.selectedTab, tab.isDirty || workspace.saveFlash {
                statusBadge(tab)
            }

            if let storageError = workspace.storageError {
                storageErrorBadge(storageError)
            }

            if let tab = workspace.selectedTab {
                editorModeControl(tab)
            }

            toolbarButton("gearshape", id: "settings", label: "Open Settings", active: workspace.settingsVisible) {
                if workspace.settingsVisible {
                    workspace.hideSettings()
                } else {
                    workspace.showSettings()
                }
            }
            .help("Settings (⌘,)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(QuivPalette.chrome.opacity(0.45))
    }

    private func editorModeControl(_ tab: NoteTab) -> some View {
        Menu {
            ForEach(NoteEditorMode.allCases) { mode in
                Button {
                    workspace.setEditorMode(mode)
                    if mode != .preview {
                        NotificationCenter.default.post(name: .quivFocusEditor, object: nil)
                    }
                } label: {
                    Label(mode.label, systemImage: tab.editorMode == mode ? "checkmark" : mode.icon)
                }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: tab.editorMode.icon)
                    .font(.system(size: 10.5, weight: .semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 6.5, weight: .bold))
            }
            .foregroundStyle(QuivPalette.accent)
            .frame(width: 32, height: 26)
            .background(QuivPalette.control, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(QuivPalette.accent.opacity(0.16), lineWidth: 0.5)
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Editor mode: \(tab.editorMode.label)")
        .accessibilityLabel("Editor mode")
        .accessibilityValue(tab.editorMode.label)
    }

    private func toolbarButton(
        _ icon: String,
        id: String,
        label: String,
        active: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: active ? .semibold : .medium))
                .foregroundStyle(active ? QuivPalette.accent : QuivPalette.muted.opacity(0.78))
                .frame(width: 26, height: 26)
                .background(
                    active
                        ? QuivPalette.selection
                        : (hoveredToolbarItem == id ? QuivPalette.controlHover : QuivPalette.control),
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(active ? QuivPalette.accent.opacity(0.22) : .clear, lineWidth: 0.5)
                }
        }
        .buttonStyle(.plain)
        .onHover { hovering in hoveredToolbarItem = hovering ? id : nil }
        .accessibilityLabel(label)
        .accessibilityValue(active ? "On" : "Off")
    }

    private func statusBadge(_ tab: NoteTab) -> some View {
        let label = workspace.saveFlash
            ? "Saved"
            : "Edited"

        return HStack(spacing: 4) {
            Circle()
                .fill(
                    workspace.saveFlash ? QuivPalette.success :
                    tab.isDirty ? QuivPalette.accent.opacity(0.8) :
                    QuivPalette.muted.opacity(0.4)
                )
                .frame(width: 5, height: 5)
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(
                    workspace.saveFlash ? QuivPalette.success :
                    tab.isDirty ? QuivPalette.accent.opacity(0.8) :
                    QuivPalette.muted.opacity(0.6)
                )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(QuivPalette.control, in: Capsule())
        .accessibilityElement(children: .combine)
    }

    private func storageErrorBadge(_ message: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 9, weight: .semibold))
            Text("Not saved")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
        }
        .foregroundStyle(.red.opacity(0.9))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(QuivPalette.control, in: Capsule())
        .help(message)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Storage error")
        .accessibilityValue(message)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(workspace.tabs) { tab in
                    tabChip(tab)
                }
                Button {
                    workspace.newTab()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(QuivPalette.muted.opacity(0.6))
                        .frame(width: 26, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(QuivPalette.ink.opacity(0.03))
                        )
                }
                .buttonStyle(.plain)
                .help("New Tab (⌘T)")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .background(QuivPalette.chrome.opacity(0.32))
    }

    private func tabChip(_ tab: NoteTab) -> some View {
        let selected = workspace.selectedID == tab.id
        let hovered = hoveredTabID == tab.id
        return HStack(spacing: 4) {
            Button {
                workspace.selectTab(id: tab.id)
            } label: {
                HStack(spacing: 5) {
                    if tab.isDirty {
                        Circle()
                            .fill(QuivPalette.accent)
                            .frame(width: 5, height: 5)
                    }
                    Text(tab.displayTitle)
                        .font(.system(size: 11.5, weight: selected ? .semibold : .regular, design: .default))
                        .lineLimit(1)
                }
                .foregroundStyle(selected ? QuivPalette.ink : QuivPalette.muted)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            if workspace.tabs.count > 1 {
                Button {
                    workspace.closeTab(id: tab.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(QuivPalette.muted.opacity(hovered || selected ? 0.7 : 0.3))
                }
                .buttonStyle(.plain)
                .help("Close \(tab.displayTitle)")
                .accessibilityLabel("Close \(tab.displayTitle)")
                .frame(width: 24, height: 24)
                .padding(.trailing, 3)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(
                    selected
                        ? QuivPalette.ink.opacity(0.08)
                        : (hovered ? QuivPalette.ink.opacity(0.04) : .clear)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(
                    selected ? QuivPalette.accent.opacity(0.15) : .clear,
                    lineWidth: 0.5
                )
        )
        .onHover { isHovered in
            hoveredTabID = isHovered ? tab.id : nil
        }
        .help(tab.displayTitle)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Find / Replace Bar

    private var findBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(QuivPalette.muted.opacity(0.6))
                    TextField("Find…", text: $workspace.findQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(QuivPalette.base.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(QuivPalette.border, lineWidth: 0.5)
                    )
                    .foregroundStyle(QuivPalette.ink)
                    .focused($focusedSearchField, equals: .find)
                    .accessibilityLabel("Find in note")
                    .onSubmit { workspace.findNext(forward: true) }

                findButton("Next", icon: "chevron.down") { workspace.findNext(forward: true) }
                findButton("Prev", icon: "chevron.up") { workspace.findNext(forward: false) }

                if !workspace.findStatus.isEmpty {
                    Text(workspace.findStatus)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(QuivPalette.muted.opacity(0.7))
                }

                Spacer()

                Button {
                    workspace.hideFind()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(QuivPalette.muted.opacity(0.5))
                        .frame(width: 20, height: 20)
                        .background(QuivPalette.ink.opacity(0.04), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close Find")
            }

            if workspace.replaceVisible {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.swap")
                        .font(.system(size: 11))
                        .foregroundStyle(QuivPalette.muted.opacity(0.6))
                    TextField("Replace…", text: $workspace.replaceQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(QuivPalette.base.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(QuivPalette.border, lineWidth: 0.5)
                        )
                        .foregroundStyle(QuivPalette.ink)
                        .focused($focusedSearchField, equals: .replace)
                        .accessibilityLabel("Replace with")

                    findButton("Replace", icon: "arrow.uturn.right") { workspace.replaceOne() }
                    findButton("All", icon: "arrow.triangle.2.circlepath") { workspace.replaceAll() }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(QuivPalette.surface.opacity(0.5))
    }

    private func findButton(_ label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                Text(label)
                    .font(.system(size: 10.5, weight: .medium))
            }
            .foregroundStyle(QuivPalette.ink.opacity(0.7))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(QuivPalette.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Unsaved Close Bar

    private var unsavedCloseBar: some View {
        let title = workspace.pendingCloseTab?.displayTitle ?? "note"
        let focus = workspace.pendingCloseFocus

        return VStack(spacing: 0) {
            separator

            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Save changes to “\(title)”?")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(QuivPalette.ink)
                        .lineLimit(1)
                    Text("Your changes will be lost if you don’t save them.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(QuivPalette.muted.opacity(0.86))
                        .lineLimit(1)
                }

                Spacer(minLength: 16)

                HStack(spacing: 7) {
                    closeChip(
                        title: "Cancel",
                        shortcut: "C",
                        focused: focus == .cancel,
                        style: .neutral
                    ) {
                        workspace.cancelPendingClose()
                    }
                    closeChip(
                        title: "Don't Save",
                        shortcut: "D",
                        focused: focus == .discard,
                        style: .destructive
                    ) {
                        workspace.confirmPendingCloseDiscard()
                    }
                    closeChip(
                        title: "Save",
                        shortcut: "↩",
                        focused: focus == .save,
                        style: .primary
                    ) {
                        workspace.confirmPendingCloseSave()
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(QuivPalette.surface.opacity(0.88))
        }
    }

    private func closeChip(
        title: String,
        shortcut: String,
        focused: Bool,
        style: CloseActionStyle,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 11, weight: style == .primary ? .semibold : .medium))

                Text(shortcut)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(closeShortcutForeground(style))
                    .frame(minWidth: 14, minHeight: 14)
                    .padding(.horizontal, 2)
                    .background(
                        closeShortcutBackground(style),
                        in: RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                            .strokeBorder(closeShortcutBorder(style), lineWidth: 0.5)
                    }
            }
                .foregroundStyle(closeActionForeground(style))
                .frame(minWidth: style == .primary ? 48 : 64)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(closeActionBackground(style, focused: focused))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(
                            focused ? closeActionFocusBorder(style) : QuivPalette.ink.opacity(0.07),
                            lineWidth: focused ? 1 : 0.5
                        )
                }
        }
        .buttonStyle(.plain)
        .help("\(title) (\(shortcut))")
        .accessibilityHint("Keyboard shortcut: \(shortcut == "↩" ? "Return" : shortcut)")
        .animation(.easeOut(duration: 0.12), value: workspace.pendingCloseFocus)
    }

    private func closeShortcutForeground(_ style: CloseActionStyle) -> Color {
        style == .primary
            ? QuivPalette.onAccent.opacity(0.82)
            : QuivPalette.muted.opacity(0.82)
    }

    private func closeShortcutBackground(_ style: CloseActionStyle) -> Color {
        style == .primary
            ? QuivPalette.base.opacity(0.16)
            : QuivPalette.ink.opacity(0.055)
    }

    private func closeShortcutBorder(_ style: CloseActionStyle) -> Color {
        style == .primary
            ? QuivPalette.onAccent.opacity(0.12)
            : QuivPalette.ink.opacity(0.08)
    }

    private func closeActionForeground(_ style: CloseActionStyle) -> Color {
        switch style {
        case .neutral: QuivPalette.ink.opacity(0.82)
        case .destructive: Color(nsColor: .systemRed).opacity(0.88)
        case .primary: QuivPalette.onAccent
        }
    }

    private func closeActionBackground(_ style: CloseActionStyle, focused: Bool) -> Color {
        switch style {
        case .neutral:
            focused ? QuivPalette.ink.opacity(0.10) : QuivPalette.control
        case .destructive:
            focused ? Color(nsColor: .systemRed).opacity(0.13) : QuivPalette.control
        case .primary:
            QuivPalette.accent.opacity(focused ? 1 : 0.88)
        }
    }

    private func closeActionFocusBorder(_ style: CloseActionStyle) -> Color {
        switch style {
        case .neutral: QuivPalette.ink.opacity(0.22)
        case .destructive: Color(nsColor: .systemRed).opacity(0.45)
        case .primary: QuivPalette.onAccent.opacity(0.28)
        }
    }

    // MARK: - Editor Area

    @ViewBuilder
    private var editorArea: some View {
        if let tab = workspace.selectedTab {
            if tab.editorMode == .preview {
                ScrollView {
                    if tab.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        VStack(spacing: 10) {
                            ZStack {
                                Circle().fill(QuivPalette.accent.opacity(0.10))
                                Image(systemName: "text.page")
                                    .font(.system(size: 22, weight: .light))
                                    .foregroundStyle(QuivPalette.accent.opacity(0.7))
                            }
                            .frame(width: 52, height: 52)
                            Text("Nothing to preview yet")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(QuivPalette.ink.opacity(0.75))
                            Text("Return to the editor and start writing in Markdown.")
                                .font(.system(size: 11.5))
                                .foregroundStyle(QuivPalette.muted.opacity(0.75))
                            Button("Return to WYSIWYG") { workspace.setEditorMode(.wysiwyg) }
                                .buttonStyle(.plain)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(QuivPalette.accent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(QuivPalette.selection, in: RoundedRectangle(cornerRadius: 6))
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 72)
                    } else {
                        Markdown(markdownForPreview(tab.text))
                            .markdownTheme(.quivPreview)
                            .textSelection(.enabled)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 28)
                            .frame(maxWidth: 760, alignment: .leading)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            } else {
                ZStack(alignment: .topLeading) {
                    NoteTextView(
                        text: Binding(
                            get: { tab.text },
                            set: {
                                tab.text = $0
                                workspace.persist()
                            }
                        ),
                        showLineNumbers: tab.showLineNumbers,
                        mode: tab.editorMode,
                        tabID: tab.id,
                        onStatus: { workspace.setFindStatus($0) },
                        interactionDisabled: workspace.settingsVisible
                            || workspace.libraryVisible
                            || workspace.shortcutsVisible
                    )
                    .padding(.horizontal, 2)
                    // Keep AppKit ruler drawing inside the editor area rather
                    // than allowing it to bleed into the title and tab chrome.
                    .clipped()

                    if tab.text.isEmpty {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Start writing…")
                                .font(.system(size: 15.5))
                                .foregroundStyle(QuivPalette.muted.opacity(0.52))
                            Text(tab.editorMode == .wysiwyg
                                 ? "Formatting appears as you complete Markdown  ·  Hold ⌘ for shortcuts"
                                 : "Markdown source  ·  Hold ⌘ for shortcuts")
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(QuivPalette.muted.opacity(0.46))
                        }
                        .padding(.leading, tab.showLineNumbers ? 46 : 26)
                        .padding(.top, 22)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                    }
                }
            }
        }
    }

    private func markdownForPreview(_ source: String) -> String {
        // MarkdownUI currently renders arbitrary inline HTML literally. Keep the
        // portable <u> source while avoiding visible tags in read-only preview.
        source.replacingOccurrences(
            of: #"(?i)</?u>"#,
            with: "",
            options: .regularExpression
        )
    }
}

// MARK: - Markdown Preview Theme

private extension Theme {
    static let quivPreview = Theme()
        .text {
            FontSize(14.5)
            ForegroundColor(QuivPalette.ink)
        }
        .strong {
            FontWeight(.bold)
        }
        .emphasis {
            FontStyle(.italic)
        }
        .code {
            FontSize(13.5)
            ForegroundColor(QuivPalette.accent)
            BackgroundColor(QuivPalette.accent.opacity(0.08))
        }
        .link {
            ForegroundColor(QuivPalette.accent)
        }
        .heading1 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.bold)
                    FontSize(22)
                    ForegroundColor(QuivPalette.ink)
                }
                .markdownMargin(top: .em(0.8), bottom: .em(0.4))
        }
        .heading2 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.bold)
                    FontSize(18)
                    ForegroundColor(QuivPalette.ink)
                }
                .markdownMargin(top: .em(0.7), bottom: .em(0.35))
        }
        .heading3 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(15.5)
                    ForegroundColor(QuivPalette.ink.opacity(0.9))
                }
                .markdownMargin(top: .em(0.6), bottom: .em(0.3))
        }
        .paragraph { configuration in
            configuration.label
                .markdownMargin(top: .zero, bottom: .em(0.5))
        }
        .codeBlock { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(13)
                    ForegroundColor(QuivPalette.ink.opacity(0.9))
                }
                .padding(14)
                .background(QuivPalette.surface.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(QuivPalette.border, lineWidth: 0.5)
                )
                .markdownMargin(top: .em(0.3), bottom: .em(0.5))
        }
        .blockquote { configuration in
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(QuivPalette.accent.opacity(0.4))
                    .frame(width: 3)
                configuration.label
                    .markdownTextStyle {
                        FontSize(14)
                        ForegroundColor(QuivPalette.muted)
                        FontStyle(.italic)
                    }
                    .padding(.leading, 14)
            }
            .padding(.vertical, 4)
        }
}

#Preview {
    NoteEditorView(workspace: Workspace(), focus: PanelFocus())
        .frame(width: 720, height: 520)
}
