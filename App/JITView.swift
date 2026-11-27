import SwiftUI
import UIKit

struct JITView: View {
    @Environment(\.scenePhase) private var phase
    @State private var jit = SystemInfo.jitEnabled
    @State private var importing = false
    @State private var hasPairing = Pairing.exists
    @State private var message: String?

    private let bundleID = Bundle.main.bundleIdentifier ?? "com.hamoud.javaloader"

    private struct Enabler: Identifiable {
        let name: String, scheme: String, icon: String
        var id: String { scheme }
    }
    private let enablers = [
        Enabler(name: "StikDebug", scheme: "stikdebug", icon: "bolt.horizontal.fill"),
        Enabler(name: "SideStore", scheme: "sidestore", icon: "externaldrive.fill.badge.wifi"),
        Enabler(name: "StikJIT (older)", scheme: "stikjit", icon: "bolt.fill"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Card(title: "Status") {
                    StatusRow(label: "JIT enabled", ok: jit, detail: jit ? "debugger attached" : "off")
                    StatusRow(label: "iOS \(SystemInfo.iosVersion)", ok: true,
                              detail: SystemInfo.needsTXMWorkaround ? "needs TXM script" : "standard JIT")
                    Button("Re-check") { jit = SystemInfo.jitEnabled }
                    if SystemInfo.needsTXMWorkaround {
                        Text("iOS 26 and later need a JIT script from the enabler app. StikDebug has one built in.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Card(title: "1. Use a JIT enabler app") {
                    Text("Opens the app and asks it to enable JIT for JavaLoader. Come back here afterwards.")
                        .font(.callout).foregroundStyle(.secondary)
                    ForEach(enablers) { e in
                        Button { open(e) } label: {
                            HStack {
                                Image(systemName: e.icon).frame(width: 28)
                                Text("Enable with \(e.name)")
                                Spacer()
                                Image(systemName: "arrow.up.forward.app").foregroundStyle(.secondary)
                            }
                        }
                    }
                    HStack {
                        Text("Other apps: use this bundle ID").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button(bundleID) { UIPasteboard.general.string = bundleID }.font(.caption.monospaced())
                    }
                }

                Card(title: "2. Pairing file") {
                    Text("Import the pairing file made by PairKit or another tool. You can pass it on to StikDebug, which needs one too.")
                        .font(.callout).foregroundStyle(.secondary)
                    if hasPairing {
                        StatusRow(label: "Pairing file saved", ok: true, detail: Pairing.summary ?? "")
                        HStack {
                            ShareLink(item: Pairing.file) { Label("Share / export", systemImage: "square.and.arrow.up") }
                            Spacer()
                            Button(role: .destructive) { Pairing.remove(); hasPairing = false } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }
                    Button { importing = true } label: {
                        Label(hasPairing ? "Replace pairing file" : "Import pairing file", systemImage: "square.and.arrow.down")
                    }
                }

                Card(title: "3. Pair this device here") {
                    Text("Pairing the phone with itself inside JavaLoader, with no other app, is not built yet. It will reuse PairKit's pairing code. Until then, make the file in PairKit and import it above.")
                        .font(.callout).foregroundStyle(.secondary)
                    Button { open(url: "pairkit://") } label: { Label("Open PairKit", systemImage: "link") }
                }

                if let m = message { Text(m).font(.callout).foregroundStyle(.orange).frame(maxWidth: .infinity, alignment: .leading) }
            }.padding()
        }
        .background(Backdrop())
        .navigationTitle("JIT")
        .onChange(of: phase) { p in if p == .active { jit = SystemInfo.jitEnabled } }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.item]) { result in
            switch result {
            case .success(let url):
                do {
                    try Pairing.importFile(from: url)
                    hasPairing = true; message = nil
                    LogStore.shared.add("Imported pairing file")
                } catch { message = error.localizedDescription }
            case .failure(let e): message = e.localizedDescription
            }
        }
    }

    private func open(_ e: Enabler) {
        open(url: "\(e.scheme)://enable-jit?bundle-id=\(bundleID)", name: e.name)
    }

    private func open(url: String, name: String = "That app") {
        guard let u = URL(string: url) else { return }
        LogStore.shared.add("Opening \(url)")
        UIApplication.shared.open(u) { ok in
            DispatchQueue.main.async { message = ok ? nil : "\(name) is not installed, or it does not support this link." }
        }
    }
}
