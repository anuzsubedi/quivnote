//
//  SettingsOverlay.swift
//  quivnote
//

import SwiftUI

struct SettingsOverlay: View {
    @Bindable var workspace: Workspace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var settings: AppearanceSettings { AppearanceSettings.shared }

    var body: some View {
        ZStack {
            QuivPalette.scrim
                .ignoresSafeArea()
                .onTapGesture { workspace.hideSettings() }

            VStack(spacing: 0) {
                header
                separator
                settingsContent
                footerHint
            }
            .frame(maxWidth: 380)
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
            HStack(spacing: 6) {
                Image(systemName: "paintbrush.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(QuivPalette.accent.opacity(0.7))
                Text("Appearance")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(QuivPalette.ink)
            }
            Spacer()
            Button {
                workspace.hideSettings()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(QuivPalette.muted.opacity(0.6))
                    .frame(width: 24, height: 24)
                    .background(QuivPalette.ink.opacity(0.05), in: Circle())
                    .overlay(Circle().strokeBorder(QuivPalette.border, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .help("Close Appearance")
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Content

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Mode picker
            VStack(alignment: .leading, spacing: 8) {
                Text("MODE")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(QuivPalette.muted.opacity(0.6))

                HStack(spacing: 2) {
                    ForEach(AppearanceSettings.Mode.allCases, id: \.self) { mode in
                        modeButton(mode)
                    }
                }
                .padding(2)
                .background(QuivPalette.ink.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(QuivPalette.border, lineWidth: 0.5)
                )
            }

            // Accent picker
            VStack(alignment: .leading, spacing: 8) {
                Text("ACCENT")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(QuivPalette.muted.opacity(0.6))

                HStack(spacing: 10) {
                    ForEach(AppearanceSettings.AccentChoice.allCases, id: \.self) { choice in
                        accentSwatch(choice)
                    }
                }

                Text(settings.accentChoice.label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(QuivPalette.muted.opacity(0.5))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
    }

    // MARK: - Footer

    private var footerHint: some View {
        HStack(spacing: 4) {
            Spacer()
            Text("Esc")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(QuivPalette.muted.opacity(0.7))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(QuivPalette.ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(QuivPalette.ink.opacity(0.06), lineWidth: 0.5)
                )
            Text("Close")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(QuivPalette.muted.opacity(0.55))
            Spacer()
        }
        .padding(.vertical, 9)
        .background(QuivPalette.surface.opacity(0.5))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(QuivPalette.border)
                .frame(height: 0.5)
        }
    }

    // MARK: - Mode Button

    private func modeButton(_ mode: AppearanceSettings.Mode) -> some View {
        let selected = settings.mode == mode
        return Button {
            settings.mode = mode
        } label: {
            HStack(spacing: 5) {
                Image(systemName: mode.icon)
                    .font(.system(size: 11, weight: .medium))
                Text(mode.label)
                    .font(.system(size: 12, weight: selected ? .semibold : .medium))
            }
            .foregroundStyle(selected ? QuivPalette.ink : QuivPalette.muted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(selected ? QuivPalette.accent.opacity(0.15) : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(selected ? QuivPalette.accent.opacity(0.25) : .clear, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(mode.label) appearance")
        .accessibilityValue(selected ? "Selected" : "")
    }

    // MARK: - Accent Swatch

    private func accentSwatch(_ choice: AppearanceSettings.AccentChoice) -> some View {
        let selected = settings.accentChoice == choice
        return Button {
            settings.accentChoice = choice
        } label: {
            ZStack {
                Circle()
                    .fill(choice.swatchColor)
                    .frame(width: 28, height: 28)
                    .shadow(color: choice.swatchColor.opacity(selected ? 0.3 : 0), radius: 6, y: 2)

                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.black.opacity(0.72))
                }
            }
            .frame(width: 38, height: 38)
            .overlay(
                Circle()
                    .strokeBorder(.white.opacity(selected ? 0.3 : 0.1), lineWidth: selected ? 1.5 : 0.5)
            )
            .scaleEffect(selected ? 1.1 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: settings.accentChoice)
        }
        .buttonStyle(.plain)
        .help(choice.label)
        .accessibilityLabel("\(choice.label) accent")
        .accessibilityValue(selected ? "Selected" : "")
    }
}

#Preview {
    ZStack {
        QuivPalette.base
        SettingsOverlay(workspace: Workspace())
    }
    .frame(width: 500, height: 400)
}
