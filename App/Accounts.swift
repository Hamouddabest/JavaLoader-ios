import Foundation
import CryptoKit

struct Account: Codable, Identifiable, Equatable {
    enum Kind: String, Codable { case offline, microsoft }
    var id = UUID()
    var kind: Kind
    /// Stored name. Demo accounts carry a "demo." prefix, e.g. "demo.Steve" is saved as demo.Steve.json.
    var name: String
    var uuid: String
    var accessToken: String?
    var refreshToken: String?
    var expires: Date?

    var isDemo: Bool { name.hasPrefix("demo.") }
    var displayName: String { isDemo ? String(name.dropFirst(5)) : name }
    var fileName: String {
        let safe = name.map { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "." ? String($0) : "_" }.joined()
        return safe + ".json"
    }
}

@MainActor
final class AccountStore: ObservableObject {
    static let shared = AccountStore()
    @Published var accounts: [Account] = []
    @Published var activeID: UUID? {
        didSet { UserDefaults.standard.set(activeID?.uuidString, forKey: "activeAccount") }
    }

    var active: Account? { accounts.first { $0.id == activeID } ?? accounts.first }

    private var base: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private var dir: URL {
        let d = base.appendingPathComponent("accounts", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    init() {
        migrateOldFile()
        load()
        activeID = UserDefaults.standard.string(forKey: "activeAccount").flatMap(UUID.init(uuidString:))
    }

    private func load() {
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        accounts = files.filter { $0.pathExtension == "json" }
            .compactMap { try? JSONDecoder().decode(Account.self, from: Data(contentsOf: $0)) }
            .sorted { $0.displayName.localizedCompare($1.displayName) == .orderedAscending }
    }

    private func write(_ a: Account) {
        if let d = try? JSONEncoder().encode(a) {
            try? d.write(to: dir.appendingPathComponent(a.fileName), options: [.atomic, .completeFileProtection])
        }
    }

    private func erase(_ a: Account) {
        try? FileManager.default.removeItem(at: dir.appendingPathComponent(a.fileName))
    }

    /// Earlier builds kept every account in one accounts.json.
    private func migrateOldFile() {
        struct Old: Codable { var accounts: [Account]; var active: UUID? }
        let old = base.appendingPathComponent("accounts.json")
        guard let d = try? Data(contentsOf: old), let o = try? JSONDecoder().decode(Old.self, from: d) else { return }
        o.accounts.forEach(write)
        if let act = o.active { UserDefaults.standard.set(act.uuidString, forKey: "activeAccount") }
        try? FileManager.default.removeItem(at: old)
    }

    func add(_ a: Account) {
        var item = a
        if let i = accounts.firstIndex(where: { $0.uuid == a.uuid && $0.kind == a.kind }) {
            item.id = accounts[i].id
            if accounts[i].fileName != item.fileName { erase(accounts[i]) }
            accounts[i] = item
        } else {
            accounts.append(item)
        }
        write(item)
        activeID = item.id
    }

    func addOffline(_ name: String) {
        let n = name.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return }
        add(Account(kind: .offline, name: n, uuid: Self.offlineUUID(n)))
    }

    /// Switches an account between demo and full game by renaming it and its file:
    /// demo.Steve (demo.Steve.json) <-> Steve (Steve.json).
    func setDemo(_ a: Account, _ demo: Bool) {
        guard a.isDemo != demo, let i = accounts.firstIndex(where: { $0.id == a.id }) else { return }
        var n = a
        n.name = demo ? "demo." + a.displayName : a.displayName
        erase(a)
        accounts[i] = n
        write(n)
        LogStore.shared.add("\(a.fileName) -> \(n.fileName)")
    }

    func remove(_ a: Account) {
        erase(a)
        accounts.removeAll { $0.id == a.id }
        if activeID == a.id { activeID = accounts.first?.id }
    }

    static func offlineUUID(_ name: String) -> String {
        var d = Array(Insecure.MD5.hash(data: Data(("OfflinePlayer:" + name).utf8)))
        d[6] = (d[6] & 0x0f) | 0x30
        d[8] = (d[8] & 0x3f) | 0x80
        return d.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Microsoft sign-in (device code flow)

enum MSAuth {
    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }
    struct Code {
        let deviceCode: String
        let userCode: String
        let uri: String
        let interval: Int
        let expires: Int
    }

    private static let scope = "XboxLive.signin offline_access"
    private static let tokenURL = "https://login.microsoftonline.com/consumers/oauth2/v2.0/token"

    private static func send(_ url: String, form: [String: String]? = nil, json: [String: Any]? = nil,
                             bearer: String? = nil) async throws -> (Int, [String: Any]) {
        var r = URLRequest(url: URL(string: url)!)
        r.timeoutInterval = 30
        if let form {
            r.httpMethod = "POST"
            r.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            var allowed = CharacterSet.alphanumerics; allowed.insert(charactersIn: "-._~")
            r.httpBody = form.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")" }
                .joined(separator: "&").data(using: .utf8)
        } else if let json {
            r.httpMethod = "POST"
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.setValue("application/json", forHTTPHeaderField: "Accept")
            r.httpBody = try JSONSerialization.data(withJSONObject: json)
        }
        if let bearer { r.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization") }
        let (data, resp) = try await URLSession.shared.data(for: r)
        let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        return ((resp as? HTTPURLResponse)?.statusCode ?? 0, obj)
    }

    static func start(clientID: String) async throws -> Code {
        let (st, o) = try await send("https://login.microsoftonline.com/consumers/oauth2/v2.0/devicecode",
                                     form: ["client_id": clientID, "scope": scope])
        guard st == 200, let dc = o["device_code"] as? String, let uc = o["user_code"] as? String,
              let uri = o["verification_uri"] as? String else {
            throw Failure(message: (o["error_description"] as? String) ?? "Could not start sign-in (status \(st)).")
        }
        return Code(deviceCode: dc, userCode: uc, uri: uri,
                    interval: o["interval"] as? Int ?? 5, expires: o["expires_in"] as? Int ?? 900)
    }

    static func finish(_ code: Code, clientID: String) async throws -> Account {
        var interval = code.interval
        let deadline = Date().addingTimeInterval(Double(code.expires))
        while Date() < deadline {
            try await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)
            let (_, o) = try await send(tokenURL, form: [
                "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
                "client_id": clientID, "device_code": code.deviceCode])
            if let at = o["access_token"] as? String {
                return try await minecraft(msToken: at, refresh: o["refresh_token"] as? String)
            }
            switch o["error"] as? String {
            case "authorization_pending": continue
            case "slow_down": interval += 5
            default: throw Failure(message: (o["error_description"] as? String) ?? "Sign-in failed.")
            }
        }
        throw Failure(message: "The code expired. Try again.")
    }

    static func minecraft(msToken: String, refresh: String?) async throws -> Account {
        let (s1, xbl) = try await send("https://user.auth.xboxlive.com/user/authenticate", json: [
            "Properties": ["AuthMethod": "RPS", "SiteName": "user.auth.xboxlive.com", "RpsTicket": "d=" + msToken],
            "RelyingParty": "http://auth.xboxlive.com", "TokenType": "JWT"])
        guard s1 == 200, let xblToken = xbl["Token"] as? String,
              let uhs = ((xbl["DisplayClaims"] as? [String: Any])?["xui"] as? [[String: Any]])?.first?["uhs"] as? String
        else { throw Failure(message: "Xbox Live sign-in failed (\(s1)).") }

        let (s2, xsts) = try await send("https://xsts.auth.xboxlive.com/xsts/authorize", json: [
            "Properties": ["SandboxId": "RETAIL", "UserTokens": [xblToken]],
            "RelyingParty": "rp://api.minecraftservices.com/", "TokenType": "JWT"])
        guard s2 == 200, let xstsToken = xsts["Token"] as? String else {
            let x = xsts["XErr"] as? Int ?? 0
            let why = x == 2148916233 ? "This Microsoft account has no Xbox profile."
                : x == 2148916238 ? "This is a child account and must be added to a family."
                : "Xbox authorization failed (\(x))."
            throw Failure(message: why)
        }

        let (s3, mc) = try await send("https://api.minecraftservices.com/authentication/login_with_xbox",
                                      json: ["identityToken": "XBL3.0 x=\(uhs);\(xstsToken)"])
        guard s3 == 200, let mcToken = mc["access_token"] as? String else {
            if s3 == 403 {
                throw Failure(message: "Mojang has not approved this app ID for the Minecraft API yet. Request approval at aka.ms/mce-reviewappid, then try again.")
            }
            throw Failure(message: "Minecraft sign-in failed (\(s3)).")
        }
        let (s4, prof) = try await send("https://api.minecraftservices.com/minecraft/profile", bearer: mcToken)
        guard s4 == 200, let id = prof["id"] as? String, let name = prof["name"] as? String else {
            throw Failure(message: s4 == 404 ? "This account does not own Minecraft: Java Edition." : "Could not read profile (\(s4)).")
        }
        return Account(kind: .microsoft, name: name, uuid: id, accessToken: mcToken, refreshToken: refresh,
                       expires: Date().addingTimeInterval(Double(mc["expires_in"] as? Int ?? 86400)))
    }
}
