import Foundation
import UIKit

@_silgen_name("csops")
private func csops(_ pid: pid_t, _ ops: UInt32, _ useraddr: UnsafeMutableRawPointer?, _ usersize: Int) -> Int32

enum SystemInfo {
    /// True when a debugger has been attached, which is what grants JIT on iOS.
    static var jitEnabled: Bool {
        var flags: UInt32 = 0
        _ = csops(getpid(), 0, &flags, MemoryLayout<UInt32>.size)
        return flags & 0x1000_0000 != 0 // CS_DEBUGGED
    }

    static var iosVersion: String { UIDevice.current.systemVersion }

    /// iOS 26+ on A15+/M devices uses TXM, which needs a debugger-driven JIT script.
    static var needsTXMWorkaround: Bool {
        (Int(iosVersion.split(separator: ".").first ?? "0") ?? 0) >= 26
    }

    static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    static var runtimeDir: URL { documents.appendingPathComponent("runtime", isDirectory: true) }
    static var gameDir: URL { documents.appendingPathComponent("game", isDirectory: true) }

    static func installedRuntimes() -> [String] {
        let items = (try? FileManager.default.contentsOfDirectory(atPath: runtimeDir.path)) ?? []
        return items.filter {
            FileManager.default.fileExists(atPath: runtimeDir.appendingPathComponent($0).appendingPathComponent("release").path)
        }.sorted()
    }

    static var physicalMemoryMB: Int { Int(ProcessInfo.processInfo.physicalMemory / 1_048_576) }
}

enum Pairing {
    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static var dir: URL { SystemInfo.documents.appendingPathComponent("pairing", isDirectory: true) }
    static var file: URL { dir.appendingPathComponent("pairing_file.plist") }
    static var exists: Bool { FileManager.default.fileExists(atPath: file.path) }

    /// Copies a pairing file into the app after checking that it is a property list.
    static func importFile(from url: URL) throws {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        guard (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) is [String: Any] else {
            throw Failure(message: "That file is not a pairing file (it is not a property list).")
        }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: file)
        try data.write(to: file, options: .atomic)
    }

    static func remove() { try? FileManager.default.removeItem(at: file) }

    static var summary: String? {
        guard let data = try? Data(contentsOf: file) else { return nil }
        let keys = ((try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: Any])?.count ?? 0
        return "\(data.count) bytes, \(keys) entries"
    }
}
