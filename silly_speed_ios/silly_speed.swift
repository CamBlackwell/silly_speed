import SwiftUI

@main


struct SillySpeed: App {
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var audioManager = AudioManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(themeManager)
                .environmentObject(audioManager)
                .onOpenURL { url in
                    if url.scheme == "punches" && url.host == "openAndPlay" {
                        audioManager.processPendingImports(shouldAutoPlay: true)
                    }
                }
        }
    }
}
