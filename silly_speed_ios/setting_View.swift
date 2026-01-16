import SwiftUI
import Combine


class ThemeManager: ObservableObject {
    @Published var backgroundColor = Color(red: 0.15, green: 0.15, blue: 0.25)
    @Published var textColor = Color.white
    @Published var accentColor = Color.blue
    @Published var secondaryTextColor = Color.gray
    @Published var tint = Color.blue
    @Published var gonioSidesColor = Color.red
    @Published var gonioMidsColor = Color.purple
    @Published var playButtonColor = Color.white
}


struct SettingsView: View {
    @EnvironmentObject var theme: ThemeManager

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                themePreview

                themePresetsSection

                VStack(spacing: 24) {
                    colorSection(
                        title: "Background",
                        controls: [
                            ColorControl(name: "Background Color", binding: $theme.backgroundColor)
                        ]
                    )

                    colorSection(
                        title: "Text Colors",
                        controls: [
                            ColorControl(name: "Primary Text", binding: $theme.textColor),
                            ColorControl(name: "Secondary Text", binding: $theme.secondaryTextColor)
                        ]
                    )

                    colorSection(
                        title: "Accent Colors",
                        controls: [
                            ColorControl(name: "Accent Color", binding: $theme.accentColor),
                            ColorControl(name: "Tint Color", binding: $theme.tint),
                            ColorControl(name: "Play Button", binding: $theme.playButtonColor)
                        ]
                    )

                    colorSection(
                        title: "Gonio Colors",
                        controls: [
                            ColorControl(name: "Gonio Sides", binding: $theme.gonioSidesColor),
                            ColorControl(name: "Gonio Mids", binding: $theme.gonioMidsColor)
                        ]
                    )

                    Button("Reset to Default") {
                        applyDefaultTheme()
                    }
                    .foregroundStyle(.red)
                    .padding(.top, 10)
                }
                .padding(.horizontal)
            }
            .padding(.top, 20)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .id(theme.backgroundColor)
    }

    private func previewRow(name: String, color: Color) -> some View {
        HStack {
            if name == "Background" {
                Text(name)
                    .foregroundStyle(theme.textColor)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(name)
                    .foregroundStyle(theme.textColor)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Circle()
                .fill(color)
                .frame(width: 22, height: 22)
                .overlay(
                    Circle().stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        }
    }


    private var themePreview: some View {
        VStack(spacing: 16) {
            Text("Theme Preview")
                .font(.headline)

            VStack(spacing: 14) {
                previewRow(name: "Background", color: theme.backgroundColor)
                previewRow(name: "Primary Text", color: theme.textColor)
                previewRow(name: "Secondary Text", color: theme.secondaryTextColor)
                previewRow(name: "Accent", color: theme.accentColor)
                previewRow(name: "Tint", color: theme.tint)
                previewRow(name: "Gonio Sides", color: theme.gonioSidesColor)
                previewRow(name: "Gonio Mids", color: theme.gonioMidsColor)
                previewRow(name: "Play Button", color: theme.playButtonColor)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(theme.backgroundColor)
            )
            .padding(.horizontal)
        }
    }

    private var themePresetsSection: some View {
        VStack(spacing: 12) {
            Text("Theme Presets")
                .font(.headline)
                .padding(.top, 10)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    presetButton("Default") { applyDefaultTheme() }
                    presetButton("Red") { applyRedTheme() }
                    presetButton("Blue") { applyBlueTheme() }
                    presetButton("Grey") { applyGreyTheme() }
                    presetButton("Brown") { applyBrownTheme() }
                    presetButton("Green") { applyGreenTheme() }
                    presetButton("Purple") { applyPurpleTheme() }
                    presetButton("Yellow") { applyYellowTheme() }
                    presetButton("Pink") { applyPinkTheme() }
                    presetButton("Orange") { applyOrangeTheme() }
                    presetButton("Teal") { applyTealTheme() }
                    presetButton("Midnight") { applyMidnightTheme() }
                    presetButton("Light") { applyLightTheme() }
                    presetButton("Neon") { applyNeonTheme() }
                }
                .padding(.horizontal)
            }
        }
    }

    private func presetButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(theme.tint.opacity(0.15))
                .foregroundStyle(theme.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func colorSection(title: String, controls: [ColorControl]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(theme.textColor)

            VStack(spacing: 16) {
                ForEach(controls) { control in
                    ThrottledColorPicker(name: control.name, color: control.binding)
                }
            }
        }
        .padding()
        .background(theme.backgroundColor.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private struct ThrottledColorPicker: View {
        let name: String
        @Binding var color: Color

        @State private var pendingColor: Color = .clear
        @State private var lastUpdate: Date = .now

        var body: some View {
            ColorPicker(name, selection: $pendingColor)
                .onAppear {
                    pendingColor = color
                }
                .onChange(of: color) { oldValue, newValue in
                    if newValue != pendingColor {
                        pendingColor = newValue
                    }
                }
                .onChange(of: pendingColor) { oldValue, newValue in
                    let now = Date()
                    if now.timeIntervalSince(lastUpdate) > 0.05 {
                        color = newValue
                        lastUpdate = now
                    }
                }
        }
    }




    private func applyDefaultTheme() {
        theme.backgroundColor = Color(red: 0.15, green: 0.15, blue: 0.25)
        theme.textColor = .white
        theme.secondaryTextColor = .gray
        theme.accentColor = .blue
        theme.tint = .blue
        theme.gonioSidesColor = .red
        theme.gonioMidsColor = .purple
        theme.playButtonColor = .white
    }

    private func applyRedTheme() {
        theme.backgroundColor = Color(red: 0.2, green: 0, blue: 0)
        theme.textColor = .white
        theme.secondaryTextColor = .gray
        theme.accentColor = .red
        theme.tint = .red
        theme.gonioSidesColor = .pink
        theme.gonioMidsColor = .red
        theme.playButtonColor = .white
    }

    private func applyBlueTheme() {
        theme.backgroundColor = Color(red: 0.05, green: 0.1, blue: 0.22)
        theme.textColor = .white
        theme.secondaryTextColor = .cyan.opacity(0.8)
        theme.accentColor = .blue
        theme.tint = .blue
        theme.gonioSidesColor = .cyan
        theme.gonioMidsColor = .blue
        theme.playButtonColor = .white
    }

    private func applyGreyTheme() {
        theme.backgroundColor = Color(.darkGray)
        theme.textColor = .white
        theme.secondaryTextColor = .gray
        theme.accentColor = .white
        theme.tint = .gray
        theme.gonioSidesColor = .gray
        theme.gonioMidsColor = .white
        theme.playButtonColor = .black
    }

    private func applyBrownTheme() {
        theme.backgroundColor = Color(red: 0.25, green: 0.15, blue: 0.1)
        theme.textColor = Color(red: 0.9, green: 0.85, blue: 0.8)
        theme.secondaryTextColor = .brown
        theme.accentColor = .orange
        theme.tint = .orange
        theme.gonioSidesColor = .brown
        theme.gonioMidsColor = .orange
        theme.playButtonColor = .white
    }

    private func applyGreenTheme() {
        theme.backgroundColor = Color(red: 0.05, green: 0.20, blue: 0.12)
        theme.textColor = .white
        theme.secondaryTextColor = .green.opacity(0.7)
        theme.accentColor = .green
        theme.tint = .green
        theme.gonioSidesColor = .mint
        theme.gonioMidsColor = .green
        theme.playButtonColor = .white
    }

    private func applyPurpleTheme() {
        theme.backgroundColor = Color(red: 0.12, green: 0.05, blue: 0.18)
        theme.textColor = .white
        theme.secondaryTextColor = .purple.opacity(0.7)
        theme.accentColor = .purple
        theme.tint = .purple
        theme.gonioSidesColor = .pink
        theme.gonioMidsColor = .purple
        theme.playButtonColor = .white
    }

    private func applyYellowTheme() {
        theme.backgroundColor = Color(red: 0.20, green: 0.20, blue: 0.05)
        theme.textColor = .white
        theme.secondaryTextColor = .yellow.opacity(0.7)
        theme.accentColor = .yellow
        theme.tint = .yellow
        theme.gonioSidesColor = .yellow.opacity(0.8)
        theme.gonioMidsColor = .orange
        theme.playButtonColor = .white
    }

    private func applyPinkTheme() {
        theme.backgroundColor = Color(red: 0.25, green: 0.05, blue: 0.15)
        theme.textColor = .white
        theme.secondaryTextColor = .pink.opacity(0.7)
        theme.accentColor = .pink
        theme.tint = .pink
        theme.gonioSidesColor = .pink
        theme.gonioMidsColor = .red
        theme.playButtonColor = .white
    }

    private func applyOrangeTheme() {
        theme.backgroundColor = Color(red: 0.20, green: 0.10, blue: 0)
        theme.textColor = .white
        theme.secondaryTextColor = .orange.opacity(0.7)
        theme.accentColor = .orange
        theme.tint = .orange
        theme.gonioSidesColor = .yellow
        theme.gonioMidsColor = .orange
        theme.playButtonColor = .white
    }

    private func applyTealTheme() {
        theme.backgroundColor = Color(red: 0.04, green: 0.18, blue: 0.20)
        theme.textColor = .white
        theme.secondaryTextColor = .teal.opacity(0.7)
        theme.accentColor = .teal
        theme.tint = .teal
        theme.gonioSidesColor = .cyan
        theme.gonioMidsColor = .teal
        theme.playButtonColor = .white
    }

    private func applyMidnightTheme() {
        theme.backgroundColor = .black
        theme.textColor = .white
        theme.secondaryTextColor = .gray
        theme.accentColor = .white
        theme.tint = .white
        theme.gonioSidesColor = .gray
        theme.gonioMidsColor = .white
        theme.playButtonColor = .black
    }

    private func applyLightTheme() {
        theme.backgroundColor = .white
        theme.textColor = .black
        theme.secondaryTextColor = .gray
        theme.accentColor = .blue
        theme.tint = .blue
        theme.gonioSidesColor = .gray
        theme.gonioMidsColor = .blue
        theme.playButtonColor = .white
    }

    private func applyNeonTheme() {
        theme.backgroundColor = .black
        theme.textColor = .green
        theme.secondaryTextColor = .yellow
        theme.accentColor = .pink
        theme.tint = .pink
        theme.gonioSidesColor = .yellow
        theme.gonioMidsColor = .green
        theme.playButtonColor = .white
    }
}

struct ColorControl: Identifiable {
    let id = UUID()
    let name: String
    let binding: Binding<Color>
}
