import XCTest
@testable import PositiveFingerCore

final class PositiveFingerCoreTests: XCTestCase {
    func testRewardCapDuplicateAndAtomicDraw() throws {
        let dir = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = PositiveActivityStore(directory: dir)
        let now = Date()
        XCTAssertThrowsError(try store.draw())
        _ = try store.recordDetection(text: "ありがとう", now: now)
        _ = try store.recordDetection(text: "ありがとう", now: now.addingTimeInterval(31))
        XCTAssertEqual(try store.snapshot(now: now.addingTimeInterval(31)).balance, 10)
        for i in 0..<30 { _ = try store.recordDetection(text: "ありがとう\(i)", now: now.addingTimeInterval(62 + Double(i) * 31)) }
        XCTAssertEqual(try store.snapshot(now: now.addingTimeInterval(1000)).balance, 100)
        DispatchQueue.concurrentPerform(iterations: 10) { _ in _ = try? PositiveActivityStore(directory: dir).draw() }
        let state = try store.snapshot()
        XCTAssertEqual(state.balance, 0)
        XCTAssertEqual(state.collection.values.reduce(0, +), 4)
        XCTAssertThrowsError(try store.equip("unknown"))
        try store.equip("momo")
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        _ = try store.recordDetection(text: "ありがとう", now: tomorrow)
        XCTAssertEqual(try store.snapshot(now: tomorrow).dailyEarned, 5)
    }

    func testNegatedExpressionsAreNotRewardCandidates() {
        for text in ["楽しくない", "嬉しくない", "好きじゃない", "ありがとうと言えなかった", "大丈夫ではない"] {
            XCTAssertFalse(PositiveEngine.shared.analyze(text).isPositive, text)
        }
        XCTAssertTrue(PositiveEngine.shared.analyze("好きじゃない。でもありがとう").isPositive)
    }

    func testExchangeAndQuestSurviveReloadAndNeverDoubleSpend() throws {
        let dir = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = PositiveActivityStore(directory: dir)
        XCTAssertThrowsError(try store.exchange("sky"))
        XCTAssertThrowsError(try store.exchange("invalid"))
        XCTAssertThrowsError(try store.claimPracticeQuest())
        let now = Date()
        _ = try store.recordDetection(text: "before", now: now)
        try store.joinPracticeQuest()
        for i in 0..<5 { _ = try store.recordDetection(text: "expression\(i)", now: now.addingTimeInterval(Double(i + 1) * 31)) }
        try store.joinPracticeQuest()
        XCTAssertEqual(try store.snapshot().questProgress, 5)
        try store.claimPracticeQuest()
        XCTAssertThrowsError(try store.claimPracticeQuest())
        XCTAssertEqual(try store.snapshot().balance, 55)
        DispatchQueue.concurrentPerform(iterations: 10) { _ in _ = try? PositiveActivityStore(directory: dir).exchange("wordfriend") }
        let state = try PositiveActivityStore(directory: dir).snapshot()
        XCTAssertEqual(state.balance, 5)
        XCTAssertEqual(state.exchanges, ["wordfriend"])
        XCTAssertTrue(state.questClaimed)
        XCTAssertThrowsError(try store.exchange("wordfriend"))
    }

    func testSameExpressionEarnsAgainAfterInternalCooldownAcrossRestarts() throws {
        let dir = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let now = Date()
        let first = PositiveActivityStore(directory: dir)
        _ = try first.recordDetection(text: "ありがとう", now: now)
        let second = PositiveActivityStore(directory: dir)
        _ = try second.recordDetection(text: "最高", now: now.addingTimeInterval(29))
        XCTAssertEqual(try second.snapshot(now: now.addingTimeInterval(29)).balance, 5)
        _ = try second.recordDetection(text: "ありがとう", now: now.addingTimeInterval(30))
        XCTAssertEqual(try second.snapshot(now: now.addingTimeInterval(30)).balance, 10)
        try second.updateSettings(.init(feedbackEnabled: true, feedbackInterval: 180))
        XCTAssertEqual(try second.snapshot().settings.feedbackInterval, 30)
    }

    #if DEBUG
    func testDebugPointsAndResetPreservePreferencesAndRefreshTracker() throws {
        let dir = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = PositiveActivityStore(directory: dir)
        try store.updateSettings(.init(feedbackEnabled: false, feedbackInterval: 30))
        try store.debugAddPoints(100)
        XCTAssertEqual(try store.snapshot().balance, 100)
        XCTAssertEqual(try store.snapshot().dailyEarned, 0)
        XCTAssertThrowsError(try store.debugAddPoints(-100))
        try store.exchange("wordfriend")
        _ = try store.draw()
        try store.joinPracticeQuest()
        let tracker = PositiveKeyboardTracker(store: store)
        tracker.sensitiveInputCheck = { false }
        let now = Date()
        XCTAssertTrue(tracker.processCommittedText("ありがとう", now: now))
        try store.debugResetProgress()
        let state = try PositiveActivityStore(directory: dir).snapshot()
        XCTAssertEqual(state.balance, 0)
        XCTAssertEqual(state.detectionCount, 0)
        XCTAssertTrue(state.collection.isEmpty)
        XCTAssertTrue(state.exchanges.isEmpty)
        XCTAssertFalse(state.questJoined)
        XCTAssertEqual(state.equipped, "momo")
        XCTAssertFalse(state.settings.feedbackEnabled)
        XCTAssertTrue(tracker.processCommittedText("ありがとう", now: now.addingTimeInterval(1)))
        XCTAssertEqual(try store.snapshot().balance, 5)
    }
    #endif

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    func testLongestPhraseWinsAndRepeatedWordsCountOnce() {
        let result = PositiveEngine.shared.analyze("ありがとうございます。ありがとう！大好き、大好き")
        XCTAssertEqual(Set(result.matchedWords), Set(["ありがとうございます", "ありがとう", "大好き"]))
        XCTAssertEqual(PositiveEngine.shared.analyze("ありがとうありがとう").matchedWords, ["ありがとう"])
        XCTAssertFalse(PositiveEngine.shared.analyze("今日は雨です").isPositive)
        XCTAssertEqual(PositiveEngine.shared.analyze("好ありがとうき").matchedWords, ["ありがとう"])
    }

    func testDetectionPersistsAndDuplicateSurvivesRecreation() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = PositiveActivityStore(directory: directory)
        let now = Date()
        XCTAssertTrue(try first.recordDetection(text: "ありがとう", now: now))
        let second = PositiveActivityStore(directory: directory)
        XCTAssertFalse(try second.recordDetection(text: " ありがとう\n", now: now.addingTimeInterval(1)))
        XCTAssertTrue(try second.recordDetection(text: "すごい", now: now.addingTimeInterval(2)))
        XCTAssertFalse(try second.recordDetection(text: "ありがとう", now: now.addingTimeInterval(3)))
        XCTAssertTrue(try second.recordDetection(text: "ありがとう", now: now.addingTimeInterval(30)))
        let state = try first.snapshot(now: now.addingTimeInterval(30))
        XCTAssertEqual(state.detectionCount, 3)
        XCTAssertEqual(state.balance, 10)
        let json = try String(contentsOf: directory.appendingPathComponent("PositivePoints/points.json"))
        XCTAssertFalse(json.contains("ありがとう"))
        XCTAssertFalse(json.contains("すごい"))
        XCTAssertTrue(try first.snapshot(now: now.addingTimeInterval(61)).recent.isEmpty)
    }

    func testDailyCountsAndRetention() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PositiveActivityStore(directory: directory)
        let now = Date()
        let old = Calendar.current.date(byAdding: .day, value: -40, to: now)!
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        _ = try store.recordDetection(text: "ありがとう", now: old)
        _ = try store.recordDetection(text: "ありがとう", now: yesterday)
        _ = try store.recordDetection(text: "ありがとう", now: now)
        let state = try store.snapshot(now: now)
        XCTAssertEqual(state.detectionCount, 3)
        XCTAssertEqual(state.dailyCounts.count, 2)
        XCTAssertEqual(state.dailyCounts[PositiveActivityStore.dayKey(now)], 1)
        XCTAssertEqual(state.dailyCounts[PositiveActivityStore.dayKey(yesterday)], 1)
        XCTAssertNil(state.dailyCounts[PositiveActivityStore.dayKey(old)])
    }

    func testConcurrentInstancesDoNotLoseDetections() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        DispatchQueue.concurrentPerform(iterations: 20) { index in
            _ = try? PositiveActivityStore(directory: directory).recordDetection(text: "ありがとう\(index)")
        }
        XCTAssertEqual(try PositiveActivityStore(directory: directory).snapshot().detectionCount, 20)
    }

    func testPreviousPrototypeMigratesWithoutNewPointsOrInventedHistory() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let folder = directory.appendingPathComponent("PositivePoints")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let data = Data(#"{"totalPoints":25,"rewardedCount":3,"todayPoints":5,"day":"2026-10-21","salt":"legacy","recent":{}}"#.utf8)
        try data.write(to: folder.appendingPathComponent("points.json"))
        let store = PositiveActivityStore(directory: directory)
        var state = try store.snapshot()
        XCTAssertEqual(state.detectionCount, 3)
        XCTAssertEqual(state.legacyPoints, 25)
        XCTAssertTrue(state.dailyCounts.isEmpty)
        _ = try store.recordDetection(text: "ありがとう")
        state = try store.snapshot()
        XCTAssertEqual(state.detectionCount, 4)
        XCTAssertEqual(state.legacyPoints, 30)
    }

    func testFeedbackSettingsFrequencyAndSensitiveInput() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PositiveActivityStore(directory: directory)
        var feedbackCount = 0
        let tracker = PositiveKeyboardTracker(store: store) { feedbackCount += 1 }
        let now = Date()
        // Missing host input traits fail closed before analysis or storage.
        XCTAssertFalse(tracker.processCommittedText("ありがとう", now: now))
        XCTAssertEqual(try store.snapshot().detectionCount, 0)
        tracker.sensitiveInputCheck = { false }
        XCTAssertTrue(tracker.processCommittedText("ありがとう", now: now))
        XCTAssertFalse(tracker.processCommittedText("ありがとう", now: now.addingTimeInterval(1)))
        XCTAssertTrue(tracker.processCommittedText("すごい", now: now.addingTimeInterval(2)))
        XCTAssertEqual(feedbackCount, 1)
        XCTAssertTrue(tracker.processCommittedText("大好き", now: now.addingTimeInterval(60)))
        XCTAssertEqual(feedbackCount, 2)
        try store.updateSettings(.init(feedbackEnabled: false, feedbackInterval: 30))
        XCTAssertTrue(tracker.processCommittedText("最高", now: now.addingTimeInterval(120)))
        XCTAssertEqual(feedbackCount, 2)
        XCTAssertEqual(try store.snapshot(now: now.addingTimeInterval(120)).detectionCount, 4)
        XCTAssertFalse(try PositiveActivityStore(directory: directory).snapshot().settings.feedbackEnabled)
        tracker.sensitiveInputCheck = { true }
        XCTAssertFalse(tracker.processCommittedText("ありがとう", now: now.addingTimeInterval(180)))
    }

    func testFeedbackIntervalSurvivesExtensionRecreation() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        var feedbackCount = 0
        let now = Date()
        let first = PositiveKeyboardTracker(store: PositiveActivityStore(directory: directory)) { feedbackCount += 1 }
        first.sensitiveInputCheck = { false }
        XCTAssertTrue(first.processCommittedText("ありがとう", now: now))
        let second = PositiveKeyboardTracker(store: PositiveActivityStore(directory: directory)) { feedbackCount += 1 }
        second.sensitiveInputCheck = { false }
        XCTAssertTrue(second.processCommittedText("大好き", now: now.addingTimeInterval(10)))
        XCTAssertEqual(feedbackCount, 1)
        XCTAssertTrue(second.processCommittedText("最高", now: now.addingTimeInterval(60)))
        XCTAssertEqual(feedbackCount, 2)
    }

    func testFeedbackStillWorksWithoutSharedStorage() throws {
        let store = PositiveActivityStore(directory: nil)
        XCTAssertThrowsError(try store.recordDetection(text: "ありがとう"))
        var feedbackCount = 0
        let tracker = PositiveKeyboardTracker(store: store) { feedbackCount += 1 }
        tracker.sensitiveInputCheck = { false }
        let now = Date()
        XCTAssertTrue(tracker.processCommittedText("ありがとう", now: now))
        XCTAssertFalse(tracker.processCommittedText("ありがとう", now: now.addingTimeInterval(1)))
        XCTAssertEqual(feedbackCount, 1)
    }
}
