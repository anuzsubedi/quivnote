//
//  LibraryBrowser.swift
//  quivnote
//

import SwiftUI

struct LibraryBrowser: View {
    @Bindable var workspace: Workspace

    @State private var hoveredNoteID: UUID?

    private let dateFormat: DateFormatter = {
        let f = DateFormatter()
        f.doesRelativeDateFormatting = true
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { workspace.hideLibrary() }

            VStack(spacing: 0) {
                header
                separator
                searchField
                separator
                noteList
                footerHints
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
            .shadow(color: .black.opacity(0.5), radius: 40, y: 16)
            .padding(28)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.97)))
        .onChange(of: workspace.libraryQuery) { _, _ in
            workspace.syncLibraryFocus()
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(QuivPalette.border)
            .frame(height: 0.5)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Image(systemName: "books.vertical")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(QuivPalette.accent.opacity(0.7))
                    Text("Library")
                        .font(.system(size: 17, weight: .bold, design: .default))
                        .foregroundStyle(QuivPalette.ink)
                }
                Text("\(workspace.library.notes.count) notes")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(QuivPalette.muted.opacity(0.7))
            }
            Spacer()
            Button {
                workspace.hideLibrary()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(QuivPalette.muted.opacity(0.6))
                    .frame(width: 24, height: 24)
                    .background(QuivPalette.ink.opacity(0.05), in: Circle())
                    .overlay(Circle().strokeBorder(QuivPalette.border, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(QuivPalette.muted.opacity(0.5))
            Text(workspace.libraryQuery.isEmpty ? "Type to search…" : workspace.libraryQuery)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(workspace.libraryQuery.isEmpty ? QuivPalette.muted.opacity(0.4) : QuivPalette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            if !workspace.libraryQuery.isEmpty {
                Text("⌫")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(QuivPalette.muted.opacity(0.5))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(QuivPalette.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 3))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(QuivPalette.surface.opacity(0.3))
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
                        .foregroundStyle(QuivPalette.muted.opacity(0.35))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(workspace.filteredLibraryNotes) { note in
                                noteRow(note)
                                    .id(note.id)
                            }
                        }
                        .padding(.horizontal, 10)
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
        HStack(spacing: 12) {
            hint("↑↓", "Move")
            hint("↩", "Open")
            hint("⌘R", "Rename")
            hint("⌘⌫", "Delete")
            Spacer(minLength: 0)
            hint("Esc", "Close")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(QuivPalette.surface.opacity(0.5))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(QuivPalette.border)
                .frame(height: 0.5)
        }
    }

    private func hint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(QuivPalette.muted.opacity(0.7))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(QuivPalette.ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(QuivPalette.ink.opacity(0.06), lineWidth: 0.5)
                )
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(QuivPalette.muted.opacity(0.55))
        }
    }

    private func noteRow(_ note: LibraryNote) -> some View {
        let isOpen = workspace.tabs.contains { $0.libraryID == note.id }
        let isFocused = workspace.libraryFocusID == note.id
        let isRenaming = workspace.libraryRenamingID == note.id
        let isHovered = hoveredNoteID == note.id

        return HStack(alignment: .top, spacing: 10) {
            Button {
                workspace.libraryFocusID = note.id
                workspace.openLibraryNote(note)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    if isRenaming {
                        TextField("Title", text: $workspace.libraryRenameDraft)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(QuivPalette.ink)
                            .onSubmit { workspace.commitLibraryRename() }
                    } else {
                        Text(note.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isFocused ? QuivPalette.ink : QuivPalette.ink.opacity(0.85))
                            .lineLimit(1)
                    }

                    Text(note.preview)
                        .font(.system(size: 11.5, weight: .regular))
                        .foregroundStyle(QuivPalette.muted.opacity(0.7))
                        .lineLimit(2)

                    Text(dateFormat.string(from: note.updatedAt))
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundStyle(QuivPalette.muted.opacity(0.4))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isOpen {
                HStack(spacing: 3) {
                    Circle()
                        .fill(QuivPalette.accent.opacity(0.6))
                        .frame(width: 4, height: 4)
                    Text("Open")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(QuivPalette.accent.opacity(0.7))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(QuivPalette.accent.opacity(0.08), in: Capsule())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    isFocused
                        ? QuivPalette.accent.opacity(0.10)
                        : (isHovered ? QuivPalette.ink.opacity(0.04) : QuivPalette.ink.opacity(0.02))
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    isFocused ? QuivPalette.accent.opacity(0.25) : .clear,
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
