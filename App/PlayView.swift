import SwiftUI

struct PlayView: View {
    @EnvironmentObject var versions: VersionStore
    @EnvironmentObject var accounts: AccountStore
    @EnvironmentObject var log: LogStore
    @State private var pickVersion = false
    @State private var pickAccount = false

    private var entry: VersionEntry? { versions.entry(versions.selected) }
    private var isInstalled: Bool { versions.installed.contains(versions.selected) }
    private var hasJava: Bool { !SystemInfo.installedRuntimes().isEmpty }

    private var blocker: String? {
        if accounts.active == nil { return "Add an account first" }
        if !isInstalled { return "Install this version first" }
        if !hasJava { return "Java runtime is not available yet" }
        return "The game launcher is not built yet"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Card {
                        Button { pickAccount = true } label: {
                            HStack(spacing: 12) {
                                Avatar(account: accounts.active)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(accounts.active?.displayName ?? "No account").font(.headline)
                                    Text(accounts.active.map { $0.isDemo ? "Microsoft, demo" : ($0.kind == .microsoft ? "Microsoft" : "Offline") } ?? "Tap to add")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down").foregroundStyle(.secondary)
                            }
                        }.buttonStyle(.plain)

                        Divider().overlay(Theme.stroke)

                        Button { pickVersion = true } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "cube.fill").font(.title2).foregroundStyle(Theme.accent)
                                    .frame(width: 48, height: 48)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(versions.selected.isEmpty ? "Choose a version" : versions.selected).font(.headline)
                                    HStack(spacing: 6) {
                                        if let e = entry { Badge(text: e.kind.short, color: e.kind.color) }
                                        if isInstalled { Badge(text: "Installed", color: Theme.accent) }
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down").foregroundStyle(.secondary)
                            }
                        }.buttonStyle(.plain)

                        if let id = versions.installing {
                            VStack(alignment: .leading, spacing: 6) {
                                ProgressView(value: versions.progress).tint(Theme.accent)
                                Text("Installing \(id): \(versions.status)").font(.caption).foregroundStyle(.secondary)
                            }
                        } else if !isInstalled, let e = entry {
                            Button { Task { await versions.install(e) } } label: {
                                Label("Install \(e.id)", systemImage: "arrow.down.circle.fill")
                                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                            }.buttonStyle(.borderedProminent)
                        } else {
                            Button { log.add("Launch pressed: \(blocker ?? "")") } label: {
                                Label(accounts.active?.isDemo == true ? "Launch demo" : "Launch", systemImage: "play.fill")
                                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                            }.buttonStyle(.borderedProminent).disabled(true)
                            if let b = blocker { Text(b).font(.caption).foregroundStyle(.secondary) }
                        }
                        if let e = versions.error { Text(e).font(.caption).foregroundStyle(.red) }
                    }

                    Card(title: "Checklist") {
                        StatusRow(label: "Version list", ok: versions.manifest != nil,
                                  detail: versions.manifest.map { "\($0.versions.count) versions" } ?? "offline")
                        StatusRow(label: "Account", ok: accounts.active != nil, detail: accounts.active?.displayName ?? "none")
                        StatusRow(label: "Game files", ok: isInstalled, detail: isInstalled ? versions.selected : "not installed")
                        StatusRow(label: "Java runtime", ok: hasJava, detail: SystemInfo.installedRuntimes().first ?? "missing")
                        StatusRow(label: "JIT", ok: SystemInfo.jitEnabled, detail: SystemInfo.jitEnabled ? "on" : "off")
                        StatusRow(label: "Graphics layer", ok: false, detail: "not built")
                    }
                }.padding()
            }
            .background(Backdrop())
            .navigationTitle("JavaLoader")
            .sheet(isPresented: $pickVersion) { NavigationStack { VersionsView(picker: true) } }
            .sheet(isPresented: $pickAccount) { NavigationStack { AccountsView(picker: true) } }
        }
    }
}
