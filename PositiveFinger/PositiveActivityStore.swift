import Foundation
import CryptoKit
import Darwin

/// Shared aggregates and preferences. Entered text never leaves transient memory.
final class PositiveActivityStore {
    static let appGroupID = "group.com.positivefinger.PositiveFinger"
    static let shared = PositiveActivityStore()

    struct Settings: Codable, Equatable {
        var feedbackEnabled = true
        var feedbackInterval: TimeInterval = 30
    }

    struct Snapshot: Codable {
        var detectionCount = 0
        var dailyCounts: [String: Int] = [:]
        var settings = Settings()
        // Existing prototype balance migrates into the local reward wallet.
        var lastFeedbackDate: Date?
        var legacyPoints = 0
        var salt = UUID().uuidString
        var recent: [String: Date] = [:]
        var rewardDay = ""
        var rewardHashes: Set<String> = []
        var dailyEarned = 0
        var collection: [String: Int] = [:]
        var equipped = "momo"
        var balance: Int { legacyPoints }
        var lastRewardDate: Date?
        var exchanges: Set<String> = []
        var questJoined = false
        var questStartCount = 0
        var questProgress = 0
        var questClaimed = false

        init() {}
        enum CodingKeys: String, CodingKey {
            case detectionCount, dailyCounts, settings, salt, recent, rewardedCount, lastFeedbackDate
            case lastRewardDate
            case rewardDay, rewardHashes, dailyEarned, collection, equipped, exchanges, questJoined, questStartCount, questProgress, questClaimed
            case legacyPoints = "totalPoints"
        }
        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            detectionCount = try values.decodeIfPresent(Int.self, forKey: .detectionCount)
                ?? values.decodeIfPresent(Int.self, forKey: .rewardedCount) ?? 0
            dailyCounts = try values.decodeIfPresent([String: Int].self, forKey: .dailyCounts) ?? [:]
            settings = try values.decodeIfPresent(Settings.self, forKey: .settings) ?? Settings()
            lastFeedbackDate = try values.decodeIfPresent(Date.self, forKey: .lastFeedbackDate)
            legacyPoints = try values.decodeIfPresent(Int.self, forKey: .legacyPoints) ?? 0
            salt = try values.decodeIfPresent(String.self, forKey: .salt) ?? UUID().uuidString
            recent = try values.decodeIfPresent([String: Date].self, forKey: .recent) ?? [:]
            lastRewardDate = try values.decodeIfPresent(Date.self, forKey: .lastRewardDate)
            rewardDay = try values.decodeIfPresent(String.self, forKey: .rewardDay) ?? ""
            rewardHashes = try values.decodeIfPresent(Set<String>.self, forKey: .rewardHashes) ?? []
            dailyEarned = try values.decodeIfPresent(Int.self, forKey: .dailyEarned) ?? 0
            collection = try values.decodeIfPresent([String: Int].self, forKey: .collection) ?? [:]
            equipped = try values.decodeIfPresent(String.self, forKey: .equipped) ?? "momo"
            exchanges = try values.decodeIfPresent(Set<String>.self, forKey: .exchanges) ?? []
            questJoined = try values.decodeIfPresent(Bool.self, forKey: .questJoined) ?? false
            questStartCount = try values.decodeIfPresent(Int.self, forKey: .questStartCount) ?? 0
            questProgress = try values.decodeIfPresent(Int.self, forKey: .questProgress) ?? 0
            questClaimed = try values.decodeIfPresent(Bool.self, forKey: .questClaimed) ?? false
        }
        func encode(to encoder: Encoder) throws {
            var values = encoder.container(keyedBy: CodingKeys.self)
            try values.encode(detectionCount, forKey: .detectionCount)
            try values.encode(dailyCounts, forKey: .dailyCounts)
            try values.encode(settings, forKey: .settings)
            try values.encodeIfPresent(lastFeedbackDate, forKey: .lastFeedbackDate)
            try values.encode(legacyPoints, forKey: .legacyPoints)
            try values.encode(salt, forKey: .salt)
            try values.encode(recent, forKey: .recent)
            try values.encodeIfPresent(lastRewardDate, forKey: .lastRewardDate)
            try values.encode(rewardDay, forKey: .rewardDay)
            try values.encode(rewardHashes, forKey: .rewardHashes)
            try values.encode(dailyEarned, forKey: .dailyEarned)
            try values.encode(collection, forKey: .collection)
            try values.encode(equipped, forKey: .equipped)
            try values.encode(exchanges, forKey: .exchanges)
            try values.encode(questJoined, forKey: .questJoined)
            try values.encode(questStartCount, forKey: .questStartCount)
            try values.encode(questProgress, forKey: .questProgress)
            try values.encode(questClaimed, forKey: .questClaimed)
        }
    }
    enum StoreError: Error { case unavailable, lockFailed, insufficientPoints, lockedCharacter, invalidReward, alreadyOwned, questNotReady }
    static let drawCost = 25
    static let characters = ["momo", "soda", "lemon", "mint", "lilac", "peach"]

    #if DEBUG
    /// Prototype-only helpers are absent from Release builds.
    func debugAddPoints(_ amount: Int) throws {
        guard [100, 1000, 10000].contains(amount) else { throw StoreError.invalidReward }
        try transaction { state in
            state.legacyPoints = min(1_000_000, state.balance + amount)
        }
    }

    func debugResetProgress() throws {
        try transaction { state in
            let settings = state.settings
            state = Snapshot()
            state.settings = settings
        }
    }
    #endif

    static let exchangeCosts = ["sky": 100, "wordfriend": 50]

    func exchange(_ id: String) throws {
        try transaction { state in
            guard let cost = Self.exchangeCosts[id] else { throw StoreError.invalidReward }
            guard !state.exchanges.contains(id) else { throw StoreError.alreadyOwned }
            guard state.balance >= cost else { throw StoreError.insufficientPoints }
            state.legacyPoints -= cost
            state.exchanges.insert(id)
        }
    }

    func joinPracticeQuest() throws {
        try transaction { state in
            guard !state.questJoined else { return }
            state.questJoined = true
            state.questStartCount = state.detectionCount
        }
    }

    func claimPracticeQuest() throws {
        try transaction { state in
            guard state.questJoined, state.questProgress >= 5, !state.questClaimed else { throw StoreError.questNotReady }
            state.legacyPoints += 25
            state.questClaimed = true
        }
    }

    /// Equal probability, no purchases; spend and grant under the same file lock.
    func draw() throws -> String {
        try transaction { state in
            guard state.legacyPoints >= Self.drawCost else { return nil as String? }
            let character = Self.characters.randomElement()!
            state.legacyPoints -= Self.drawCost
            state.collection[character, default: 0] += 1
            return character
        }.unwrapDraw()
    }

    func equip(_ character: String) throws {
        let valid = try transaction { state in
            guard character == "momo" || state.collection[character, default: 0] > 0 else { return false }
            state.equipped = character
            return true
        }
        if !valid { throw StoreError.lockedCharacter }
    }
    private let directoryProvider: () -> URL?
    private let mutex = NSLock()

    init() {
        // Resolve after Full Access changes, rather than caching an unavailable container forever.
        self.directoryProvider = {
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID)?
                .appendingPathComponent("PositivePoints", isDirectory: true)
        }
    }

    init(directory: URL?) {
        self.directoryProvider = { directory?.appendingPathComponent("PositivePoints", isDirectory: true) }
    }

    func snapshot(now: Date = Date()) throws -> Snapshot {
        try transaction(now: now) { $0 }
    }

    func updateSettings(_ settings: Settings) throws {
        try transaction { state in
            state.settings.feedbackEnabled = settings.feedbackEnabled
            state.settings.feedbackInterval = 30
        }
    }

    /// One committed expression is one detection; repeated text is ignored for 30 seconds.
    func recordDetection(text: String, now: Date = Date()) throws -> Bool {
        let normalized = Self.normalize(text)
        guard !normalized.isEmpty else { return false }
        return try transaction(now: now) { state in
            let digest = Self.fingerprint(normalized, salt: state.salt)
            guard state.recent[digest] == nil else { return false }
            state.detectionCount += 1
            state.dailyCounts[Self.dayKey(now), default: 0] += 1
            state.recent[digest] = now
            if state.dailyEarned < 100, state.lastRewardDate.map({ now.timeIntervalSince($0) >= 30 }) ?? true {
                state.lastRewardDate = now
                state.legacyPoints += 5
                state.dailyEarned += 5
                if state.questJoined, !state.questClaimed { state.questProgress = min(5, state.questProgress + 1) }
            }
            return true
        }
    }

    /// Reserve the feedback slot atomically, including across keyboard restarts.
    func claimFeedback(now: Date = Date()) throws -> Bool {
        try transaction(now: now) { state in
            guard state.settings.feedbackEnabled else { return false }
            if let previous = state.lastFeedbackDate,
               now.timeIntervalSince(previous) < 30 { return false }
            state.lastFeedbackDate = now
            return true
        }
    }

    static func normalize(_ text: String) -> String {
        text.precomposedStringWithCompatibilityMapping
            .components(separatedBy: .whitespacesAndNewlines).joined()
    }

    static func fingerprint(_ text: String, salt: String) -> String {
        SHA256.hash(data: Data((salt + text).utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func dayKey(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private func transaction<T>(now: Date = Date(), _ body: (inout Snapshot) throws -> T) throws -> T {
        mutex.lock()
        defer { mutex.unlock() }
        guard let directory = directoryProvider() else { throw StoreError.unavailable }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let descriptor = open(directory.appendingPathComponent("points.lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw StoreError.lockFailed }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { throw StoreError.lockFailed }
        defer { flock(descriptor, LOCK_UN) }
        let url = directory.appendingPathComponent("points.json")
        var state: Snapshot
        if FileManager.default.fileExists(atPath: url.path) {
            state = try JSONDecoder().decode(Snapshot.self, from: Data(contentsOf: url))
        } else {
            state = Snapshot()
        }
        if state.rewardDay != Self.dayKey(now) {
            state.rewardDay = Self.dayKey(now)
            state.rewardHashes = []
            state.dailyEarned = 0
        }
        state.settings.feedbackInterval = 30
        state.rewardHashes = []
        state.recent = state.recent.filter { (0..<30).contains(now.timeIntervalSince($0.value)) }
        let oldest = Calendar.current.date(byAdding: .day, value: -29, to: now) ?? now
        let firstDay = Self.dayKey(oldest)
        let lastDay = Self.dayKey(now)
        state.dailyCounts = state.dailyCounts.filter { $0.key >= firstDay && $0.key <= lastDay }
        let result = try body(&state)
        try JSONEncoder().encode(state).write(to: url, options: .atomic)
        return result
    }
}

private extension Optional where Wrapped == String {
    func unwrapDraw() throws -> String {
        guard let value = self else { throw PositiveActivityStore.StoreError.insufficientPoints }
        return value
    }
}
