import SwiftUI
import Security

struct PFCloudState: Decodable {
    struct Profile: Decodable { let id: String; let display_name: String }
    struct Wallet: Decodable { let balance: Int; let daily_earned: Int; let earned_day: String?; let streak: Int; let checkin_day: String? }
    struct Item: Decodable { let item_id: String; let quantity: Int }
    struct Announcement: Decodable, Identifiable { let id: String; let title: String; let body: String; let kind: String }
    struct Event: Decodable, Identifiable { let id: String; let title: String; let description: String; let goal: Int; let progress: Int; let reward: Int; let starts_at: String; let ends_at: String }
    struct Member: Decodable { let event_id: String; let contribution: Int; let claimed: Bool }
    let profile: Profile; let wallet: Wallet; let inventory: [Item]
    let announcements: [Announcement]; let events: [Event]; let memberships: [Member]; let missions: [String]
}

@MainActor final class PositiveCloud: ObservableObject {
    static let shared = PositiveCloud()
    @Published var state: PFCloudState?
    @Published var signedIn = false
    @Published var busy = false
    @Published var message: String?
    @Published var live = false
    private struct Session: Codable { let access_token: String; let refresh_token: String; let expires_at: Double?; let user: User; struct User: Codable { let id: String } }
    private var session: Session?
    private var refreshing = false
    private var socket: URLSessionWebSocketTask?
    private var listener: Task<Void, Never>?
    private var heartbeat: Task<Void, Never>?
    private var syncing = false
    private let base = "https://ctyzaihzltcncspujmnb.supabase.co"
    private let key = "sb_publishable_iMRH0X5OmCc3yy7BkNMAgg_HTKChfT1"
    private let keychainQuery: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "com.positivefinger.cloud", kSecAttrAccount as String: "session"]

    private init() {
        var query = keychainQuery; query[kSecReturnData as String] = true
        var found: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &found) == errSecSuccess,
           let data = found as? Data, let stored = try? JSONDecoder().decode(Session.self, from: data) {
            session = stored; signedIn = true
        }
    }
    private func saveSession(_ value: Session) throws {
        let data = try JSONEncoder().encode(value)
        let update = [kSecValueData as String: data]
        let status = SecItemUpdate(keychainQuery as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var query = keychainQuery; query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(query as CFDictionary, nil) == errSecSuccess else { throw CloudError.text("ログイン情報を保存できません") }
        } else if status != errSecSuccess { throw CloudError.text("ログイン情報を保存できません") }
        session = value; signedIn = true
    }
    enum CloudError: LocalizedError { case text(String); var errorDescription: String? { if case let .text(text) = self { return text }; return nil } }
    private func request(_ path: String, body: [String: Any] = [:], authorized: Bool = true) async throws -> Data {
        if authorized { try await refreshSessionIfNeeded() }
        var req = URLRequest(url: URL(string: base + path)!); req.httpMethod = "POST"; req.timeoutInterval = 20
        req.setValue(key, forHTTPHeaderField: "apikey")
        if authorized { guard let session else { throw CloudError.text("ログインしてください") }; req.setValue("Bearer " + session.access_token, forHTTPHeaderField: "Authorization") }
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let raw = object?["msg"] as? String ?? object?["message"] as? String ?? "通信に失敗しました。もう一度お試しください。"
            throw CloudError.text(raw)
        }
        return data
    }
    private func refreshSessionIfNeeded() async throws {
        if refreshing {
            while refreshing { try await Task.sleep(nanoseconds:50_000_000) }
        }
        guard let session else { throw CloudError.text("ログインしてください") }
        guard (session.expires_at ?? 0) < Date().timeIntervalSince1970 + 90 else { return }
        refreshing = true
        defer { refreshing = false }
        let data = try await request("/auth/v1/token?grant_type=refresh_token", body: ["refresh_token":session.refresh_token], authorized: false)
        try saveSession(JSONDecoder().decode(Session.self, from: data))
    }
    func authenticate(email: String, password: String, signUp: Bool) async {
        guard !busy else { return }; busy = true; defer { busy = false }
        do {
            let data = try await request(signUp ? "/auth/v1/signup" : "/auth/v1/token?grant_type=password", body: ["email":email.trimmingCharacters(in:.whitespacesAndNewlines),"password":password], authorized:false)
            guard let session = try? JSONDecoder().decode(Session.self, from:data) else { message = "確認メールを送りました。メールを確認してからログインしてください。"; return }
            try saveSession(session); message = nil; await sync(); startLive()
        } catch { message = error.localizedDescription }
    }
    func signOut() {
        stopLive(); SecItemDelete(keychainQuery as CFDictionary); session = nil; signedIn = false; state = nil
        try? PositiveActivityStore.shared.setCloudAccount(nil)
    }
    func sync() async {
        guard signedIn, !syncing else { return }; syncing = true; defer { syncing = false }
        do {
            try await refreshSessionIfNeeded()
            guard let session else { return }
            try PositiveActivityStore.shared.setCloudAccount(session.user.id)
            let queued = try PositiveActivityStore.shared.snapshot().cloudEvents
            for id in queued.prefix(30) {
                let reply = try await request("/rest/v1/rpc/pf_action", body:["p_action":"expression","p_request":id])
                let object = (try JSONSerialization.jsonObject(with:reply)) as? [String:Any]
                if object?["awarded"] as? Bool == false, object?["capped"] as? Bool != true { break }
                try PositiveActivityStore.shared.acknowledgeCloudEvent(id)
            }
            let data = try await request("/rest/v1/rpc/pf_bootstrap")
            let value = try JSONDecoder().decode(PFCloudState.self, from:data)
            state = value
            try PositiveActivityStore.shared.applyCloudState(balance:value.wallet.balance, inventory:Dictionary(uniqueKeysWithValues:value.inventory.map { ($0.item_id,$0.quantity) }))
            message = nil
        } catch { message = error.localizedDescription }
    }
    /// Reuse the same request UUID on an ambiguous network failure so a retry cannot spend twice.
    func perform(_ action: String, item: String? = nil) async throws -> String? {
        guard !busy else { throw CloudError.text("処理中です") }; busy = true; defer { busy = false }
        guard let session else { throw CloudError.text("ログインしてください") }
        let storageKey = "pf.pendingCloudAction." + session.user.id
        let intent = action + ":" + (item ?? "")
        var pending = UserDefaults.standard.dictionary(forKey: storageKey) as? [String:String]
        if let pending, pending["intent"] != intent { throw CloudError.text("前の操作の結果を確認できていません。同じ操作をもう一度押してください。") }
        if pending == nil { pending = ["id":UUID().uuidString,"intent":intent]; UserDefaults.standard.set(pending, forKey:storageKey) }
        var body: [String:Any] = ["p_action":action,"p_request":pending!["id"]!]
        if let item { body["p_item"] = item }
        do {
            let data = try await request("/rest/v1/rpc/pf_action",body:body)
            UserDefaults.standard.removeObject(forKey:storageKey)
            await sync()
            let result = (try JSONSerialization.jsonObject(with:data)) as? [String:Any]
            return result?["item"] as? String
        } catch let error as CloudError {
            // Server rejected it before committing; an intentional future action may use a new request.
            UserDefaults.standard.removeObject(forKey:storageKey); throw error
        }
    }
    func stopLive() { listener?.cancel(); heartbeat?.cancel(); socket?.cancel(with:.goingAway,reason:nil); socket=nil; live=false }
    func startLive() {
        guard signedIn, listener == nil || listener?.isCancelled == true else { return }
        listener = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                do {
                    try await self.refreshSessionIfNeeded()
                    guard let token=self.session?.access_token else { return }
                    let url=URL(string:self.base.replacingOccurrences(of:"https:",with:"wss:")+"/realtime/v1/websocket?apikey="+self.key+"&vsn=1.0.0")!
                    let socket=URLSession.shared.webSocketTask(with:url); self.socket=socket; socket.resume()
                    let payload:[String:Any] = ["topic":"realtime:pf-app","event":"phx_join","ref":"1","payload":["access_token":token,"config":["postgres_changes":[["event":"*","schema":"public","table":"pf_announcements"],["event":"*","schema":"public","table":"pf_events"],["event":"UPDATE","schema":"public","table":"pf_wallets"]]]]]
                    let join = String(data:try JSONSerialization.data(withJSONObject:payload),encoding:.utf8)!
                    try await socket.send(.string(join))
                    self.heartbeat?.cancel()
                    self.heartbeat = Task {
                        while !Task.isCancelled {
                            do { try await Task.sleep(nanoseconds:25_000_000_000); try await socket.send(.string("{\"topic\":\"phoenix\",\"event\":\"heartbeat\",\"payload\":{},\"ref\":\"heartbeat\"}")) }
                            catch { return }
                        }
                    }
                    while !Task.isCancelled {
                        let incoming=try await socket.receive()
                        let bytes:Data
                        switch incoming { case .data(let d): bytes=d; case .string(let s): bytes=Data(s.utf8); @unknown default: continue }
                        let obj=(try? JSONSerialization.jsonObject(with:bytes)) as? [String:Any]
                        if obj?["event"] as? String == "phx_reply", let p=obj?["payload"] as? [String:Any] { self.live=p["status"] as? String == "ok" }
                        if obj?["event"] as? String == "postgres_changes" { await self.sync() }
                    }
                } catch { self.live=false; self.heartbeat?.cancel(); self.socket?.cancel(with:.goingAway,reason:nil) }
                do { try await Task.sleep(nanoseconds:5_000_000_000) } catch { return }
            }
        }
    }
}
