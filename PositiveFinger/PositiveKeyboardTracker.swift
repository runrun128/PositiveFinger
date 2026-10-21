//
//  PositiveKeyboardTracker.swift
//  PositiveFinger
//
//  Created by 市来武 on 2026/10/21.
//

import Foundation

final class PositiveKeyboardTracker {

    static let shared = PositiveKeyboardTracker()

    private let analyzer = PositiveEngine.shared
    private let pointManager = PositivePointManager.shared

    private var lastRewardedText = ""
    private var lastRewardDate = Date.distantPast

    private let cooldown: TimeInterval = 30

    private init() {}

    func processCommittedText(_ text: String) {

        guard !text.isEmpty else {
            return
        }

        let result = analyzer.analyze(text)

        guard result.isPositive else {
            return
        }

        let now = Date()

        // 同じ文章への連続付与を防止
        if text == lastRewardedText &&
            now.timeIntervalSince(lastRewardDate) < cooldown {
            return
        }

        pointManager.addPoints(result.score)

        lastRewardedText = text
        lastRewardDate = now
    }
}
}
