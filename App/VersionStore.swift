import Foundation

@MainActor
final class VersionStore: ObservableObject {
    static let shared = VersionStore()

    @Published var manifest: VersionManifest?
    @Published var loading = false
    @Published var error: String?
    @Published var selected: String { didSet { UserDefaults.standard.set(selected, forKey: "selectedVersion") } }
    @Published var installed: Set<String> = []
    @Published var installing: String?
    @Published var progress: Double = 0
    @Published var status = ""

    private let log = LogStore.shared

    private var cacheURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("version_manifest.json")
    }
    private var versionsDir: URL { SystemInfo.gameDir.appendingPathComponent("versions", isDirectory: true) }

    init() {
        selected = UserDefaults.standard.string(forKey: "selectedVersion") ?? ""
        if let d = try? Data(contentsOf: cacheURL),
           let m = try? JSONDecoder().decode(VersionManifest.self, from: d) {
            manifest = m
            if selected.isEmpty { selected = m.latest.release }
        }
        refreshInstalled()
    }

    func entry(_ id: String) -> VersionEntry? { manifest?.versions.first { $0.id == id } }

    func refresh() async {
        loading = true; error = nil
        defer { loading = false }
        do {
            let url = URL(string: "https://piston-meta.mojang.com/mc/game/version_manifest_v2.json")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let m = try JSONDecoder().decode(VersionManifest.self, from: data)
            try? data.write(to: cacheURL)
            manifest = m
            if selected.isEmpty { selected = m.latest.release }
            log.add("Loaded \(m.versions.count) versions (latest \(m.latest.release), snapshot \(m.latest.snapshot))")
        } catch {
            self.error = "Could not load versions: \(error.localizedDescription)"
            log.add(self.error ?? "")
        }
    }

    func refreshInstalled() {
        let fm = FileManager.default
        let ids = (try? fm.contentsOfDirectory(atPath: versionsDir.path)) ?? []
        installed = Set(ids.filter { fm.fileExists(atPath: versionsDir.appendingPathComponent("\($0)/\($0).json").path) })
    }

    func delete(_ id: String) {
        try? FileManager.default.removeItem(at: versionsDir.appendingPathComponent(id))
        refreshInstalled()
        log.add("Deleted \(id)")
    }

    // MARK: install

    func install(_ v: VersionEntry) async {
        guard installing == nil else { return }
        installing = v.id; progress = 0; status = "Reading version info"
        defer { installing = nil; status = "" }
        do {
            let (vdata, _) = try await URLSession.shared.data(from: URL(string: v.url)!)
            let detail = try JSONDecoder().decode(VersionDetail.self, from: vdata)
            let vdir = versionsDir.appendingPathComponent(v.id, isDirectory: true)
            try FileManager.default.createDirectory(at: vdir, withIntermediateDirectories: true)

            var jobs: [DownloadJob] = []
            if let c = detail.downloads?.client, let u = URL(string: c.url) {
                jobs.append(DownloadJob(url: u, dest: vdir.appendingPathComponent("\(v.id).jar"), size: c.size ?? 0))
            }
            let libRoot = SystemInfo.gameDir.appendingPathComponent("libraries", isDirectory: true)
            for lib in detail.libraries ?? [] where Self.allowed(lib.rules) {
                if let a = lib.downloads?.artifact, let p = a.path, let u = URL(string: a.url) {
                    jobs.append(DownloadJob(url: u, dest: libRoot.appendingPathComponent(p), size: a.size ?? 0))
                }
            }
            if let ai = detail.assetIndex, let aurl = URL(string: ai.url) {
                status = "Reading asset index"
                let (adata, _) = try await URLSession.shared.data(from: aurl)
                let idxDir = SystemInfo.gameDir.appendingPathComponent("assets/indexes", isDirectory: true)
                try FileManager.default.createDirectory(at: idxDir, withIntermediateDirectories: true)
                try adata.write(to: idxDir.appendingPathComponent("\(ai.id).json"))
                let index = try JSONDecoder().decode(AssetIndexFile.self, from: adata)
                let objRoot = SystemInfo.gameDir.appendingPathComponent("assets/objects", isDirectory: true)
                var seen = Set<String>()
                for (_, o) in index.objects where seen.insert(o.hash).inserted {
                    let pre = String(o.hash.prefix(2))
                    if let u = URL(string: "https://resources.download.minecraft.net/\(pre)/\(o.hash)") {
                        jobs.append(DownloadJob(url: u, dest: objRoot.appendingPathComponent("\(pre)/\(o.hash)"), size: o.size))
                    }
                }
            }
            log.add("Installing \(v.id): \(jobs.count) files")
            try await run(jobs)
            try vdata.write(to: vdir.appendingPathComponent("\(v.id).json"))
            refreshInstalled()
            log.add("Installed \(v.id)")
        } catch {
            self.error = "Install failed: \(error.localizedDescription)"
            log.add(self.error ?? "")
        }
    }

    private func run(_ jobs: [DownloadJob]) async throws {
        let total = max(jobs.count, 1)
        var done = 0, idx = 0
        while idx < jobs.count {
            let batch = Array(jobs[idx..<min(idx + 16, jobs.count)])
            idx += batch.count
            try await withThrowingTaskGroup(of: Void.self) { group in
                for j in batch { group.addTask { try await VersionStore.fetch(j) } }
                for try await _ in group {
                    done += 1
                    progress = Double(done) / Double(total)
                    status = "\(done) of \(jobs.count) files"
                }
            }
        }
    }

    nonisolated static func fetch(_ job: DownloadJob) async throws {
        let fm = FileManager.default
        if job.size > 0, let a = try? fm.attributesOfItem(atPath: job.dest.path), (a[.size] as? Int) == job.size { return }
        let (tmp, resp) = try await URLSession.shared.download(from: job.url)
        if let h = resp as? HTTPURLResponse, h.statusCode != 200 { throw URLError(.badServerResponse) }
        try fm.createDirectory(at: job.dest.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? fm.removeItem(at: job.dest)
        try fm.moveItem(at: tmp, to: job.dest)
    }

    /// Library rules: with no rules a library applies everywhere; otherwise the last matching rule wins.
    nonisolated static func allowed(_ rules: [VersionDetail.Rule]?) -> Bool {
        guard let rules, !rules.isEmpty else { return true }
        var ok = false
        for r in rules {
            let matches = r.os == nil || r.os?.name == "osx"
            if matches { ok = (r.action == "allow") }
        }
        return ok
    }
}
