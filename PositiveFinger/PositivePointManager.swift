//
//  PositivePointManager.swift
//  PositiveFinger
//
//  Created by 市来武 on 2026/10/21.
//

import Foundation

final class PositivePointManager {

    static let shared = PositivePointManager()

    private let pointsKey = "positiveFinger.totalPoints"

    // 自分のApp Group IDに変更する
    private let appGroupID = "group.com.example.positivefinger"

    private var storage: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    private init() {}

    var totalPoints: Int {
        storage?.integer(forKey: pointsKey) ?? 0
    }

    func addPoints(_ points: Int) {

        guard points > 0 else {
            return
        }

        guard let storage else {
            return
        }

        let newTotal = totalPoints + points

        storage.set(
            newTotal,
            forKey: pointsKey
        )
    }

    func resetPoints() {
        storage?.set(0, forKey: pointsKey)
    }
}
}
