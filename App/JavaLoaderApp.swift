import SwiftUI

@main
struct JavaLoaderApp: App {
    @StateObject private var log = LogStore.shared
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(log).preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            PlayView().tabItem { Label("Play", systemImage: "play.fill") }
            RuntimeView().tabItem { Label("Java", systemImage: "cup.and.saucer.fill") }
            JITView().tabItem { Label("JIT", systemImage: "bolt.fill") }
            LogView().tabItem { Label("Log", systemImage: "text.alignleft") }
            SettingsView().tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(Theme.accent)
    }
}
