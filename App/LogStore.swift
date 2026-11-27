import Foundation

final class LogStore: ObservableObject {
    static let shared = LogStore()
    @Published private(set) var lines: [String] = []
    private let fmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; return f
    }()

    func add(_ s: String) {
        let line = "\(fmt.string(from: Date()))  \(s)"
        DispatchQueue.main.async { self.lines.append(line) }
    }
    func clear() { DispatchQueue.main.async { self.lines.removeAll() } }
}
