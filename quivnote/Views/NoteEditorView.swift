//
//  ContentView.swift
//  quivnote
//

import MarkdownUI
import SwiftUI

struct NoteEditorView: View {
    private enum SearchField: Hashable { case find, replace }

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

            if let tab = workspace.selectedTab {
                editorModeControl(tab)
            }

            toolbarButton("gearshape", id: "settings", label: "Open Appearance Settings", active: workspace.settingsVisible) {
                workspace.showSettings()
            }
            .help("Appearance (⌘,)")
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

            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(QuivPalette.accent.opacity(0.8))
                        Text("Unsaved changes")
                            .font(.system(size: 12, weight: .semibold, design: .default))
                            .foregroundStyle(QuivPalette.ink)
                    }
                    Text("Close \"\(title)\"?")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(QuivPalette.muted)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                HStack(spacing: 6) {
                    closeChip(
                        title: "Cancel",
                        hint: "C",
                        focused: focus == .cancel
                    ) {
                        workspace.cancelPendingClose()
                    }
                    closeChip(
                        title: "Don't Save",
                        hint: "D",
                        focused: focus == .discard
                    ) {
                        workspace.confirmPendingCloseDiscard()
                    }
                    closeChip(
                        title: "Save",
                        hint: "↩",
                        focused: focus == .save,
                        prominent: true
                    ) {
                        workspace.confirmPendingCloseSave()
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(QuivPalette.surface.opacity(0.95))
        }
    }

    private func closeChip(
        title: String,
        hint: String,
        focused: Bool,
        prominent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 11, weight: prominent ? .semibold : .medium))
                Text(hint)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(
                        prominent
                            ? QuivPalette.onAccent.opacity(focused ? 0.9 : 0.72)
                            : QuivPalette.muted.opacity(focused ? 0.9 : 0.5)
                    )
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        (prominent ? QuivPalette.base : QuivPalette.ink)
                            .opacity(prominent ? (focused ? 0.2 : 0.12) : (focused ? 0.1 : 0.05)),
                        in: RoundedRectangle(cornerRadius: 3, style: .continuous)
                    )
            }
            .foregroundStyle(prominent ? QuivPalette.onAccent : QuivPalette.ink.opacity(0.85))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                if prominent {
                    Capsule().fill(QuivPalette.accent.opacity(focused ? 1 : 0.85))
                } else if focused {
                    Capsule().fill(QuivPalette.ink.opacity(0.10))
                } else {
                    Capsule().fill(QuivPalette.ink.opacity(0.04))
                }
            }
            .overlay {
                Capsule()
                    .strokeBorder(
                        focused && !prominent ? QuivPalette.ink.opacity(0.15) : .clear,
                        lineWidth: 0.5
                    )
            }
            .scaleEffect(focused ? 1.02 : 1)
            .shadow(
                color: focused && prominent ? QuivPalette.accent.opacity(0.3) : .clear,
                radius: 8,
                y: 2
            )
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.12), value: workspace.pendingCloseFocus)
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
                        onStatus: { workspace.setFindStatus($0) }
                    )
                    .padding(.horizontal, 2)

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
                        .padding(.leading, tab.showLineNumbers ? 66 : 26)
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
