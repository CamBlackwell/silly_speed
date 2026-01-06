import SwiftUI
import Combine

class ThemeManager: ObservableObject {
    @Published var backgroundColor = Color(red: 0.35, green: 0.15, blue: 0.15)
    @Published var textColor = Color.purple
    @Published var accentColor = Color.blue
    @Published var secondaryTextColor = Color.pink
    @Published var tint = Color.blue
    @Published var gonioSidesColor = Color.red
    @Published var gonioMidsColor = Color.purple
}
