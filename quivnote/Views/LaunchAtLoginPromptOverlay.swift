//
//  LaunchAtLoginPromptOverlay.swift
//  quivnote
//

import SwiftUI

struct LaunchAtLoginPromptOverlay: View {
    var onYes: () -> Void
    var onLater: () -> Void
    var onNever: () -> Void

    @State private var hoveredButton: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            QuivPalette.scrim
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Text("Launch quivnote at login?")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(QuivPalette.ink)

                Text("Keep the quick-note panel one keystroke away by starting quivnote automatically when you log in. You can change this later in Settings.")
                    .font(.system(size: 12))
                    .foregroundStyle(QuivPalette.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)

                HStack(spacing: 10) {
                    promptButton("Never", key: "never") { onNever() }
                    promptButton("Not Now", key: "later") { onLater() }
                    promptButton("Enable", key: "yes", isPrimary: true) { onYes() }
                }
                .padding(.top, 20)
            }
            .padding(24)
            .frame(width: 340)
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
        }
        .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.97)))
    }

    private func promptButton(
        _ title: String,
        key: String,
        isPrimary: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        let isHovered = hoveredButton == key

        return Button {
            action()
        } label: {
            Text(title)
                .font(.system(size: 12, weight: isPrimary ? .semibold : .medium))
                .foregroundStyle(isPrimary ? Color.white : QuivPalette.ink)
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(
                            isPrimary
                                ? AnyShapeStyle(QuivPalette.accent.opacity(isHovered ? 0.9 : 1))
                                : AnyShapeStyle(QuivPalette.ink.opacity(isHovered ? 0.12 : 0.07))
                        )
                }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredButton = hovering ? key : (hoveredButton == key ? nil : hoveredButton)
        }
    }
}
