import XCTest
@testable import PositiveFingerCore

final class PositiveFingerCoreTests: XCTestCase {
    func testLongestPhraseWinsAndRepeatedWordsCountOnce() {
        let result = PositiveEngine.shared.analyze("ありがとうございます。ありがとう！大好き、大好き")
        XCTAssertEqual(result.score, 35)
        XCTAssertEqual(Set(result.matchedWords), Set(["ありがとうございます", "ありがとう", "大好き"]))
        XCTAssertEqual(PositiveEngine.shared.analyze("ありがとうありがとう").score, 10)
        XCTAssertEqual(PositiveEngine.shared.analyze("今日は雨です").score, 0)
    }

    func testRemovingMatchDoesNotCreateArtificialPhrase() {
        XCTAssertEqual(PositiveEngine.shared.analyze("好ありがとうき").score, 10)
    }

    func testRewardPersistsAndDuplicateSurvivesRecreation() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = PositivePointManager(directory: directory)
        let date = Date()
        XCTAssertEqual(try first.reward(text: "ありがとう", score: 10, now: date), 10)
        let second = PositivePointManager(directory: directory)
        XCTAssertEqual(try second.reward(text: " ありがとう\n", score: 10, now: date.addingTimeInterval(1)), 0)
        XCTAssertEqual(try second.reward(text: "すごい", score: 5, now: date.addingTimeInterval(2)), 5)
        XCTAssertEqual(try second.reward(text: "ありがとう", score: 10, now: date.addingTimeInterval(3)), 0)
        XCTAssertEqual(try second.reward(text: "ありがとう", score: 10, now: date.addingTimeInterval(30)), 10)
        XCTAssertEqual(try first.snapshot().totalPoints, 25)
        XCTAssertEqual(try first.snapshot().rewardedCount, 3)
        let json = try String(contentsOf: directory.appendingPathComponent("PositivePoints/points.json"))
        XCTAssertFalse(json.contains("ありがとう"))
        XCTAssertFalse(json.contains("すごい"))
    }

    func testTodayResetsAndUnavailableStorageThrows() throws {
        XCTAssertThrowsError(try PositivePointManager(directory: nil).reward(text: "ありがとう", score: 10))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PositivePointManager(directory: directory)
        let today = Calendar.current.startOfDay(for: Date()).addingTimeInterval(60)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        _ = try store.reward(text: "ありがとう", score: 10, now: today)
        XCTAssertEqual(store.pointsToday(try store.snapshot(), now: tomorrow), 0)
        _ = try store.reward(text: "すごい", score: 5, now: tomorrow)
        XCTAssertEqual(try store.snapshot().totalPoints, 15)
        XCTAssertEqual(store.pointsToday(try store.snapshot(), now: tomorrow), 5)
    }

    func testConcurrentInstancesDoNotLosePoints() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        DispatchQueue.concurrentPerform(iterations: 20) { index in
            let store = PositivePointManager(directory: directory)
            _ = try? store.reward(text: "ありがとう\(index)", score: 10)
        }
        XCTAssertEqual(try PositivePointManager(directory: directory).snapshot().totalPoints, 200)
    }
}
