import SwiftUI

@main
struct JavaLoaderApp: App {
    @StateObject private var log = LogStore.shared
    @StateObject private var versions = VersionStore.shared
    @StateObject private var accounts = AccountStore.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(log)
                .environmentObject(versions)
                .environmentObject(accounts)
                .preferredColorScheme(.dark)
                .task { await versions.refresh() }
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            PlayView().tabItem { Label("Play", systemImage: "play.fill") }
            VersionsView().tabItem { Label("Versions", systemImage: "square.stack.3d.up.fill") }
            AccountsView().tabItem { Label("Accounts", systemImage: "person.2.fill") }
            SystemView().tabItem { Label("System", systemImage: "cpu") }
            SettingsView().tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(Theme.accent)
    }
}
