//
//  ShortcutsOverlay.swift
//  quivnote
//

import SwiftUI

struct ShortcutsOverlay: View {
    var pinned: Bool

    private let sections: [(title: String, rows: [(keys: [String], label: String)])] = [
        (
            "General",
            [
                (["⌘", "⌥", "⇧", "N"], "Show / hide note"),
                (["⌘", ","], "Appearance"),
                (["⌘", "/"], "Pin this sheet"),
                (["esc"], "Dismiss"),
                (["⌘", "Q"], "Quit"),
            ]
        ),
        (
            "Tabs & Library",
            [
                (["⌘", "T"], "New tab"),
                (["⌘", "W"], "Close tab"),
                (["⌘", "⇧", "]"], "Next tab"),
                (["⌘", "⇧", "["], "Previous tab"),
                (["⌃", "tab"], "Cycle tabs"),
                (["⌘", "O"], "Open library"),
                (["⌘", "S"], "Save to library"),
                (["⌘", "⇧", "I"], "Import file"),
                (["⌘", "⇧", "E"], "Export file"),
            ]
        ),
        (
            "Edit & View",
            [
                (["⌘", "F"], "Find"),
                (["⌘", "H"], "Find & replace"),
                (["⌘", "M"], "Markdown preview"),
                (["⌘", "L"], "Line numbers"),
            ]
        ),
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.42)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                separator
                columns
            }
            .frame(maxWidth: 580)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(QuivPalette.base.opacity(0.96))
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
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            }
            .shadow(color: .black.opacity(0.5), radius: 40, y: 16)
            .padding(28)
        }
        .transition(
            .opacity
                .combined(with: .scale(scale: 0.96, anchor: .center))
        )
    }

    private var separator: some View {
        Rectangle()
            .fill(QuivPalette.border)
            .frame(height: 0.5)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(QuivPalette.accent.opacity(0.7))
                    Text("Shortcuts")
                        .font(.system(size: 17, weight: .bold, design: .default))
                        .foregroundStyle(QuivPalette.ink)
                }
                Text(pinned ? "Pinned — press ⌘/ to close" : "Hold ⌘ · release to hide")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(QuivPalette.muted.opacity(0.6))
            }
            Spacer()
            HoldHint(pinned: pinned)
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    private var columns: some View {
        HStack(alignment: .top, spacing: 28) {
            ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                VStack(alignment: .leading, spacing: 10) {
                    Text(section.title.uppercased())
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(QuivPalette.accent.opacity(0.55))

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(section.rows.enumerated()), id: \.offset) { _, row in
                            ShortcutRow(keys: row.keys, label: row.label)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 16)
        .padding(.bottom, 20)
    }
}

private struct HoldHint: View {
    var pinned: Bool

    var body: some View {
        HStack(spacing: 5) {
            KeyCap(pinned ? "⌘/" : "⌘", compact: true)
            Text(pinned ? "unpin" : "hold")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(QuivPalette.muted.opacity(0.6))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(QuivPalette.accent.opacity(0.08), in: Capsule())
        .overlay(Capsule().strokeBorder(QuivPalette.accent.opacity(0.1), lineWidth: 0.5))
    }
}

private struct ShortcutRow: View {
    var keys: [String]
    var label: String

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 3) {
                ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                    KeyCap(key, compact: false)
                }
            }
            .frame(width: 96, alignment: .leading)

            Text(label)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(QuivPalette.ink.opacity(0.7))
                .lineLimit(1)
        }
    }
}

private struct KeyCap: View {
    var label: String
    var compact: Bool

    init(_ label: String, compact: Bool) {
        self.label = label
        self.compact = compact
    }

    var body: some View {
        Text(label)
            .font(.system(size: compact ? 10 : 11, weight: .medium, design: .monospaced))
            .foregroundStyle(QuivPalette.ink.opacity(0.8))
            .padding(.horizontal, compact ? 5 : 6)
            .padding(.vertical, compact ? 3 : 4)
            .background {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(QuivPalette.ink.opacity(0.06))
                    .overlay {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(QuivPalette.ink.opacity(0.08), lineWidth: 0.5)
                    }
            }
    }
}

#Preview {
    ZStack {
        QuivPalette.base
        ShortcutsOverlay(pinned: false)
    }
    .frame(width: 720, height: 520)
}
