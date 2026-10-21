import Foundation

final class PositiveKeyboardTracker {
    static let shared = PositiveKeyboardTracker()
    private init() {}

    @discardableResult
    func processCommittedText(_ text: String) -> Int {
        let result = PositiveEngine.shared.analyze(text)
        guard result.isPositive else { return 0 }
        // No fallback store: points must never silently diverge between the two targets.
        return (try? PositivePointManager.shared.reward(text: text, score: result.score)) ?? 0
    }
}
