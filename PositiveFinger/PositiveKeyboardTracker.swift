import Foundation

extension Notification.Name {
    static let positiveStorageAvailable = Notification.Name("PositiveFinger.storageAvailable")
    static let positiveStorageUnavailable = Notification.Name("PositiveFinger.storageUnavailable")
    static let positiveExpressionDetected = Notification.Name("PositiveFinger.expressionDetected")
}

/// Called only for keyboard commits, never for the host app's send action.
final class PositiveKeyboardTracker {
    static let shared = PositiveKeyboardTracker()
    var sensitiveInputCheck: () -> Bool = { true }
    private let store: PositiveActivityStore
    private let onFeedback: () -> Void
    private var lastFeedbackDate = Date.distantPast
    private var recent: [String: Date] = [:]
    private let salt = UUID().uuidString
    private var storeGeneration: String?

    init(store: PositiveActivityStore = .shared, onFeedback: @escaping () -> Void = {
        NotificationCenter.default.post(name: .positiveExpressionDetected, object: nil)
    }) {
        self.store = store
        self.onFeedback = onFeedback
    }

    @discardableResult
    func processCommittedText(_ text: String, now: Date = Date()) -> Bool {
        guard !sensitiveInputCheck() else { return false }
        guard PositiveEngine.shared.analyze(text).isPositive else { return false }
        if let generation = try? store.snapshot(now: now).salt, generation != storeGeneration {
            recent.removeAll()
            lastFeedbackDate = .distantPast
            storeGeneration = generation
        }
        recent = recent.filter { (0..<30).contains(now.timeIntervalSince($0.value)) }
        let fingerprint = PositiveActivityStore.fingerprint(PositiveActivityStore.normalize(text), salt: salt)
        guard recent[fingerprint] == nil else { return false }
        // Full Access may be off. Feedback still works, but statistics never fall back
        // to an isolated store that the main app could not read.
        let recorded: Bool?
        do {
            recorded = try store.recordDetection(text: text, now: now)
            NotificationCenter.default.post(name: .positiveStorageAvailable, object: nil)
        }
        catch {
            recorded = nil
            NotificationCenter.default.post(name: .positiveStorageUnavailable, object: nil)
        }
        guard recorded != false else { return false }
        recent[fingerprint] = now
        let shouldShow = (try? store.claimFeedback(now: now))
            ?? (now.timeIntervalSince(lastFeedbackDate) >= PositiveActivityStore.Settings().feedbackInterval)
        if shouldShow {
            lastFeedbackDate = now
            onFeedback()
        }
        return true
    }
}
