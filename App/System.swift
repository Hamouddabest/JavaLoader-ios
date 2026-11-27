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
