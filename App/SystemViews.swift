import SwiftUI

struct SystemView: View {
    @State private var jit = SystemInfo.jitEnabled
    @State private var runtimes = SystemInfo.installedRuntimes()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    NavigationLink { JITView() } label: {
                        Card(title: "JIT") {
                            HStack {
                                StatusRow(label: jit ? "JIT is on" : "JIT is off", ok: jit,
                                          detail: "iOS \(SystemInfo.iosVersion)")
                                Image(systemName: "chevron.right").foregroundStyle(.secondary)
                            }
                            Text("Enable it with StikDebug, SideStore or a pairing file.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }.buttonStyle(.plain)
                    Card(title: "Java runtimes") {
                        if runtimes.isEmpty {
                            Text("None yet. Runtimes will be downloaded here once our OpenJDK iOS build exists.")
                                .font(.callout).foregroundStyle(.secondary)
                        }
                        ForEach(runtimes, id: \.self) { Text($0) }
                        Button("Refresh") { runtimes = SystemInfo.installedRuntimes() }
                    }
                    Card(title: "Device") {
                        StatusRow(label: "Memory", ok: true, detail: "\(SystemInfo.physicalMemoryMB) MB")
                        Text("Files app > JavaLoader holds runtimes and game data.").font(.caption).foregroundStyle(.secondary)
                    }
                    NavigationLink { LogView() } label: {
                        Card { HStack { Label("Log", systemImage: "text.alignleft"); Spacer(); Image(systemName: "chevron.right").foregroundStyle(.secondary) } }
                    }.buttonStyle(.plain)
                }.padding()
            }
            .background(Backdrop())
            .navigationTitle("System")
            .onAppear {
                jit = SystemInfo.jitEnabled
                try? FileManager.default.createDirectory(at: SystemInfo.runtimeDir, withIntermediateDirectories: true)
                try? FileManager.default.createDirectory(at: SystemInfo.gameDir, withIntermediateDirectories: true)
            }
        }
    }
}

struct LogView: View {
    @EnvironmentObject var log: LogStore
    var body: some View {
        ScrollView {
            Text(log.lines.isEmpty ? "No log yet." : log.lines.joined(separator: "\n"))
                .font(.system(.footnote, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading).padding()
                .textSelection(.enabled)
        }
        .background(Backdrop())
        .navigationTitle("Log")
        .toolbar { Button("Clear") { log.clear() } }
    }
}

struct SettingsView: View {
    @AppStorage("ramMB") private var ramMB = 1536
    @AppStorage("jvmArgs") private var jvmArgs = ""
    @AppStorage("renderScale") private var renderScale = 1.0
    @AppStorage("msClientID") private var clientID = ""
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
                Section(header: Text("Microsoft sign-in (advanced)"),
                        footer: Text("Optional. Overrides the app ID built into this version.")) {
                    TextField("Client ID", text: $clientID)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                Section("About") { LabeledContent("Version", value: "0.5.1") }
            }
            .scrollContentBackground(.hidden)
            .background(Backdrop())
            .navigationTitle("Settings")
        }
    }
}
