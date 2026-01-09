import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var theme: ThemeManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("Background") {
                    ColorPicker("Background Color", selection: $theme.backgroundColor)
                }
                
                Section("Text Colors") {
                    ColorPicker("Primary Text", selection: $theme.textColor)
                    ColorPicker("Secondary Text", selection: $theme.secondaryTextColor)
                }
                
                Section("Accent Colors") {
                    ColorPicker("Accent Color", selection: $theme.accentColor)
                    ColorPicker("Tint Color", selection: $theme.tint)
                }
                
                Section("Gonio Colors") {
                    ColorPicker("Gonio Sides", selection: $theme.gonioSidesColor)
                    ColorPicker("Gonio Mids", selection: $theme.gonioMidsColor)
                }
                
                Section {
                    Button("Reset to Default") {
                        resetToDefaults()
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(theme.accentColor)
                }
            }
        }
    }
    
    private func resetToDefaults() {
        theme.backgroundColor = Color(red: 0.35, green: 0.15, blue: 0.15)
        theme.textColor = Color.purple
        theme.accentColor = Color.blue
        theme.secondaryTextColor = Color.pink
        theme.tint = Color.blue
        theme.gonioSidesColor = Color.red
        theme.gonioMidsColor = Color.purple
    }
}
