import Foundation
import CryptoKit
import Darwin

/// Only numeric totals, dates, and salted duplicate fingerprints are persisted.
final class PositivePointManager {
    static let appGroupID = "group.com.positivefinger.PositiveFinger"
    static let shared = PositivePointManager()

    struct Snapshot: Codable {
        var totalPoints = 0
        var rewardedCount = 0
        var todayPoints = 0
        var day = ""
        var salt = UUID().uuidString
        var recent: [String: Date] = [:]
    }
    enum StoreError: Error { case unavailable, lockFailed }
    private let directory: URL?
    private let mutex = NSLock()

    init(directory: URL? = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: PositivePointManager.appGroupID
    )) {
        self.directory = directory?.appendingPathComponent("PositivePoints", isDirectory: true)
    }

    func snapshot() throws -> Snapshot {
        try transaction { state in state }
    }

    /// Returns zero for a duplicate. Atomic across the app and keyboard processes.
    func reward(text: String, score: Int, now: Date = Date()) throws -> Int {
        guard score > 0 else { return 0 }
        let normalized = text.precomposedStringWithCompatibilityMapping
            .components(separatedBy: .whitespacesAndNewlines).joined()
        guard !normalized.isEmpty else { return 0 }
        return try transaction { state in
            state.recent = state.recent.filter { now.timeIntervalSince($0.value) < 30 }
            let digest = SHA256.hash(data: Data((state.salt + normalized).utf8))
                .map { String(format: "%02x", $0) }.joined()
            guard state.recent[digest] == nil else { return 0 }
            let day = Self.dayKey(now)
            if state.day != day { state.day = day; state.todayPoints = 0 }
            state.totalPoints += score
            state.todayPoints += score
            state.rewardedCount += 1
            state.recent[digest] = now
            return score
        }
    }

    private static func dayKey(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }

    func pointsToday(_ snapshot: Snapshot, now: Date = Date()) -> Int {
        snapshot.day == Self.dayKey(now) ? snapshot.todayPoints : 0
    }

    private func transaction<T>(_ body: (inout Snapshot) -> T) throws -> T {
        mutex.lock()
        defer { mutex.unlock() }
        guard let directory else { throw StoreError.unavailable }
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
        let result = body(&state)
        try JSONEncoder().encode(state).write(to: url, options: .atomic)
        return result
    }
}
