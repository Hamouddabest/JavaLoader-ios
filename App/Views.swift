import SwiftUI

struct PlayView: View {
    @EnvironmentObject var log: LogStore
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Card(title: "Minecraft: Java Edition") {
                        Text("The launcher is not built yet. Game launching comes after the Java runtime and graphics layer.")
                            .font(.callout).foregroundStyle(.secondary)
                        Button {
                            log.add("Launch pressed, but the launcher is not implemented yet.")
                        } label: {
                            Text("Launch").frame(maxWidth: .infinity).padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent).disabled(true)
                    }
                    Card(title: "Checklist") {
                        StatusRow(label: "App", ok: true, detail: "ready")
                        StatusRow(label: "Java runtime", ok: !SystemInfo.installedRuntimes().isEmpty,
                                  detail: SystemInfo.installedRuntimes().first ?? "missing")
                        StatusRow(label: "JIT", ok: SystemInfo.jitEnabled,
                                  detail: SystemInfo.jitEnabled ? "on" : "off")
                        StatusRow(label: "Graphics layer", ok: false, detail: "not built")
                        StatusRow(label: "Microsoft login", ok: false, detail: "not built")
                    }
                }.padding()
            }
            .navigationTitle("JavaLoader")
        }
    }
}

struct RuntimeView: View {
    @State private var runtimes = SystemInfo.installedRuntimes()
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Card(title: "Installed runtimes") {
                        if runtimes.isEmpty {
                            Text("None. Runtimes will be downloaded here once our OpenJDK iOS build exists.")
                                .font(.callout).foregroundStyle(.secondary)
                        }
                        ForEach(runtimes, id: \.self) { Text($0) }
                        Button("Refresh") { runtimes = SystemInfo.installedRuntimes() }
                    }
                    Card(title: "Folders") {
                        Text("Runtimes: Files > JavaLoader > runtime").font(.callout)
                        Text("Game data: Files > JavaLoader > game").font(.callout)
                    }
                }.padding()
            }
            .navigationTitle("Java")
            .onAppear {
                try? FileManager.default.createDirectory(at: SystemInfo.runtimeDir, withIntermediateDirectories: true)
                try? FileManager.default.createDirectory(at: SystemInfo.gameDir, withIntermediateDirectories: true)
            }
        }
    }
}

struct JITView: View {
    @State private var jit = SystemInfo.jitEnabled
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Card(title: "Status") {
                        StatusRow(label: "JIT enabled", ok: jit, detail: jit ? "debugger attached" : "off")
                        StatusRow(label: "iOS \(SystemInfo.iosVersion)", ok: true,
                                  detail: SystemInfo.needsTXMWorkaround ? "needs TXM script" : "standard JIT")
                        Button("Re-check") { jit = SystemInfo.jitEnabled }
                    }
                    Card(title: "Pair this device") {
                        Text("Pairing with itself (no computer) will be added next, so the app can attach its own debugger and turn JIT on.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                }.padding()
            }
            .navigationTitle("JIT")
        }
    }
}

struct LogView: View {
    @EnvironmentObject var log: LogStore
    var body: some View {
        NavigationStack {
            ScrollView {
                Text(log.lines.isEmpty ? "No log yet." : log.lines.joined(separator: "\n"))
                    .font(.system(.footnote, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading).padding()
                    .textSelection(.enabled)
            }
            .navigationTitle("Log")
            .toolbar { Button("Clear") { log.clear() } }
        }
    }
}

struct SettingsView: View {
    @AppStorage("ramMB") private var ramMB = 1536
    @AppStorage("jvmArgs") private var jvmArgs = ""
    @AppStorage("renderScale") private var renderScale = 1.0
    var body: some View {
        NavigationStack {
            Form {
                Section("Memory (\(SystemInfo.physicalMemoryMB) MB on this device)") {
                    Stepper("Java heap: \(ramMB) MB", value: $ramMB, in: 512...6144, step: 256)
                }
                Section("Graphics") {
                    VStack(alignment: .leading) {
                        Text("Resolution scale: \(renderScale, specifier: "%.2f")x")
                        Slider(value: $renderScale, in: 0.5...1.5, step: 0.05)
                    }
                }
                Section("Advanced") {
                    TextField("Extra JVM arguments", text: $jvmArgs)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                Section("About") {
                    LabeledContent("Version", value: "0.1.0")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
