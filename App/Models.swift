import Foundation

enum VersionKind: String, CaseIterable, Identifiable {
    case release, snapshot, old_beta, old_alpha
    var id: String { rawValue }
    var title: String {
        switch self {
        case .release: return "Releases"
        case .snapshot: return "Snapshots"
        case .old_beta: return "Beta"
        case .old_alpha: return "Alpha"
        }
    }
    var short: String {
        switch self {
        case .release: return "Release"
        case .snapshot: return "Snapshot"
        case .old_beta: return "Beta"
        case .old_alpha: return "Alpha"
        }
    }
}

struct VersionManifest: Codable {
    struct Latest: Codable { let release: String; let snapshot: String }
    let latest: Latest
    let versions: [VersionEntry]
}

struct VersionEntry: Codable, Identifiable, Hashable {
    let id: String
    let type: String
    let url: String
    let releaseTime: String
    var kind: VersionKind { VersionKind(rawValue: type) ?? .release }
    var date: String { String(releaseTime.prefix(10)) }
}

struct VersionDetail: Codable {
    struct DL: Codable { let url: String; let sha1: String?; let size: Int?; let path: String? }
    struct Downloads: Codable { let client: DL? }
    struct AssetIndex: Codable { let id: String; let url: String; let totalSize: Int? }
    struct Rule: Codable {
        struct OS: Codable { let name: String? }
        let action: String
        let os: OS?
    }
    struct Library: Codable {
        struct Dl: Codable { let artifact: DL? }
        let name: String
        let downloads: Dl?
        let rules: [Rule]?
    }
    struct Java: Codable { let majorVersion: Int }
    let id: String
    let assetIndex: AssetIndex?
    let downloads: Downloads?
    let libraries: [Library]?
    let mainClass: String?
    let javaVersion: Java?
}

struct AssetIndexFile: Codable {
    struct Obj: Codable { let hash: String; let size: Int }
    let objects: [String: Obj]
}

struct DownloadJob: Sendable {
    let url: URL
    let dest: URL
    let size: Int
}
