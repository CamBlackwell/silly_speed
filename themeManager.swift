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
}
