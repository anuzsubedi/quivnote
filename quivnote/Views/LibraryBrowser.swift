//
//  LibraryBrowser.swift
//  quivnote
//

import SwiftUI

struct LibraryBrowser: View {
    @Bindable var workspace: Workspace

    @State private var hoveredNoteID: UUID?
    @FocusState private var renamingNoteID: UUID?

    private let dateFormat: DateFormatter = {
        let f = DateFormatter()
        f.doesRelativeDateFormatting = true
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        ZStack {
            QuivPalette.scrim
                .ignoresSafeArea()
                .onTapGesture { workspace.hideLibrary() }

            VStack(spacing: 0) {
                header
                searchField
                separator
                noteList
                    .allowsHitTesting(workspace.pendingLibraryDeleteID == nil)
                if workspace.pendingLibraryDeleteID != nil {
                    deletePrompt
                } else {
                    footerHints
                }
            }
            .frame(maxWidth: 520, maxHeight: 460)
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
            .padding(28)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.97)))
        .onChange(of: workspace.libraryQuery) { _, _ in
            workspace.syncLibraryFocus()
        }
        .onChange(of: workspace.libraryRenamingID) { _, noteID in
            renamingNoteID = noteID
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(QuivPalette.border)
            .frame(height: 0.5)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Library")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(QuivPalette.ink)
                Text(workspace.library.notes.count == 1 ? "1 note" : "\(workspace.library.notes.count) notes")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(QuivPalette.muted.opacity(0.74))
            }

            Spacer()

            Button {
                workspace.hideLibrary()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(QuivPalette.muted.opacity(0.72))
                    .frame(width: 24, height: 24)
                    .background(QuivPalette.control, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Close Library")
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(QuivPalette.muted.opacity(0.58))
            Text(workspace.libraryQuery.isEmpty ? "Type to search…" : workspace.libraryQuery)
                .font(.system(size: 12.5))
                .foregroundStyle(workspace.libraryQuery.isEmpty ? QuivPalette.muted.opacity(0.62) : QuivPalette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            if !workspace.libraryQuery.isEmpty {
                Text("⌫")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(QuivPalette.muted.opacity(0.68))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(QuivPalette.ink.opacity(0.055), in: RoundedRectangle(cornerRadius: 3.5))
                    .overlay {
                        RoundedRectangle(cornerRadius: 3.5)
                            .strokeBorder(QuivPalette.ink.opacity(0.07), lineWidth: 0.5)
                    }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(QuivPalette.control, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(QuivPalette.ink.opacity(0.07), lineWidth: 0.5)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
    }

    private var noteList: some View {
        Group {
            if workspace.filteredLibraryNotes.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: workspace.library.notes.isEmpty ? "tray" : "magnifyingglass")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(QuivPalette.muted.opacity(0.25))
                    Text(workspace.library.notes.isEmpty ? "No saved notes yet" : "No matches")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(QuivPalette.muted.opacity(0.6))
                    Text(workspace.library.notes.isEmpty ? "Press ⌘S to save the current note" : "Try another search")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(QuivPalette.muted.opacity(0.68))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(workspace.filteredLibraryNotes) { note in
                                noteRow(note)
                                    .id(note.id)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                    }
                    .onChange(of: workspace.libraryFocusID) { _, newID in
                        if let newID {
                            withAnimation(.easeOut(duration: 0.12)) {
                                proxy.scrollTo(newID, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var footerHints: some View {
        HStack(spacing: 14) {
            hint(["↑", "↓"], "Move")
            hint(["↩"], "Open")
            hint(["⌘", "R"], "Rename")
            hint(["⌘", "⌫"], "Delete")
            Spacer(minLength: 0)
            hint(["esc"], "Close")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(QuivPalette.surface.opacity(0.42))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(QuivPalette.border)
                .frame(height: 0.5)
        }
    }

    private func hint(_ keys: [String], _ label: String) -> some View {
        HStack(spacing: 5) {
            HStack(spacing: 2) {
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(QuivPalette.muted.opacity(0.82))
                        .frame(minWidth: 14, minHeight: 14)
                        .padding(.horizontal, 2)
                        .background(
                            QuivPalette.ink.opacity(0.055),
                            in: RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                                .strokeBorder(QuivPalette.ink.opacity(0.08), lineWidth: 0.5)
                        }
                }
            }

            Text(label)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(QuivPalette.muted.opacity(0.70))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(keys.joined()) \(label)")
    }

    private var deletePrompt: some View {
        let noteTitle = workspace.pendingLibraryDeleteNote?.title ?? "note"
        let focus = workspace.pendingLibraryDeleteFocus

        return HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Delete “\(noteTitle)”?")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(QuivPalette.ink)
                    .lineLimit(1)
                Text("Open tabs keep their text until closed.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(QuivPalette.muted.opacity(0.78))
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            HStack(spacing: 7) {
                deletePromptButton(
                    title: "Cancel",
                    shortcut: "C",
                    focused: focus == .cancel,
                    destructive: false
                ) {
                    workspace.cancelPendingLibraryDelete()
                }
                deletePromptButton(
                    title: "Delete",
                    shortcut: "D",
                    focused: focus == .delete,
                    destructive: true
                ) {
                    workspace.confirmPendingLibraryDelete()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(QuivPalette.surface.opacity(0.72))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(QuivPalette.border)
                .frame(height: 0.5)
        }
    }

    private func deletePromptButton(
        title: String,
        shortcut: String,
        focused: Bool,
        destructive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                Text(shortcut)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(
                        destructive
                            ? Color(nsColor: .systemRed).opacity(0.78)
                            : QuivPalette.muted.opacity(0.78)
                    )
                    .frame(minWidth: 14, minHeight: 14)
                    .padding(.horizontal, 2)
                    .background(
                        (destructive ? Color(nsColor: .systemRed) : QuivPalette.ink).opacity(0.06),
                        in: RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                            .strokeBorder(
                                (destructive ? Color(nsColor: .systemRed) : QuivPalette.ink).opacity(0.10),
                                lineWidth: 0.5
                            )
                    }
            }
            .foregroundStyle(
                destructive
                    ? Color(nsColor: .systemRed).opacity(0.9)
                    : QuivPalette.ink.opacity(0.82)
            )
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                (destructive && focused
                    ? Color(nsColor: .systemRed).opacity(0.13)
                    : QuivPalette.control),
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(
                        focused
                            ? (destructive
                                ? Color(nsColor: .systemRed).opacity(0.45)
                                : QuivPalette.ink.opacity(0.22))
                            : QuivPalette.ink.opacity(0.07),
                        lineWidth: focused ? 1 : 0.5
                    )
            }
        }
        .buttonStyle(.plain)
        .help("\(title) (\(shortcut))")
        .accessibilityHint("Keyboard shortcut: \(shortcut)")
    }

    private func noteRow(_ note: LibraryNote) -> some View {
        let isOpen = workspace.tabs.contains { $0.libraryID == note.id }
        let isFocused = workspace.libraryFocusID == note.id
        let isRenaming = workspace.libraryRenamingID == note.id
        let isHovered = hoveredNoteID == note.id

        return HStack(alignment: .top, spacing: 10) {
            if isRenaming {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Title", text: $workspace.libraryRenameDraft)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(QuivPalette.ink)
                        .focused($renamingNoteID, equals: note.id)
                        .accessibilityLabel("Rename note")
                        .onSubmit { workspace.commitLibraryRename() }
                    Text(note.preview)
                        .font(.system(size: 11.5))
                        .foregroundStyle(QuivPalette.muted.opacity(0.76))
                        .lineLimit(2)

                    Text(dateFormat.string(from: note.updatedAt))
                        .font(.system(size: 10.5))
                        .foregroundStyle(QuivPalette.muted.opacity(0.66))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Button {
                    workspace.libraryFocusID = note.id
                    workspace.openLibraryNote(note)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(note.title)
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(isFocused ? QuivPalette.ink : QuivPalette.ink.opacity(0.85))
                            .lineLimit(1)
                        Text(note.preview)
                            .font(.system(size: 11.5))
                            .foregroundStyle(QuivPalette.muted.opacity(0.76))
                            .lineLimit(2)
                        Text(dateFormat.string(from: note.updatedAt))
                            .font(.system(size: 10.5))
                            .foregroundStyle(QuivPalette.muted.opacity(0.66))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(note.title), \(note.preview)")
                .accessibilityValue(isOpen ? "Open" : "")
                .accessibilityHint("Open note")
            }

            if isOpen {
                HStack(spacing: 3) {
                    Circle()
                        .fill(QuivPalette.accent.opacity(0.72))
                        .frame(width: 4, height: 4)
                    Text("Open")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(QuivPalette.accent.opacity(0.78))
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    isFocused
                        ? QuivPalette.accent.opacity(0.12)
                        : (isHovered ? QuivPalette.ink.opacity(0.045) : .clear)
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    isFocused ? QuivPalette.accent.opacity(0.20) : .clear,
                    lineWidth: 0.5
                )
        }
        .onTapGesture {
            workspace.libraryFocusID = note.id
        }
        .onHover { isHovering in
            hoveredNoteID = isHovering ? note.id : nil
        }
        .animation(.easeOut(duration: 0.12), value: workspace.libraryFocusID)
    }
}
