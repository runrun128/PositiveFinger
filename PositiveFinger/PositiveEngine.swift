//
//  PositiveEngine.swift
//  PositiveFinger
//
//  Created by 市来武 on 2026/10/21.
//

import Foundation

struct PositiveAnalysisResult {
    let score: Int
    let matchedWords: [String]

    var isPositive: Bool {
        score > 0
    }
}

final class PositiveEngine {

    static let shared = PositiveEngine()

    private init() {}

    private let positiveWords: [String: Int] = [
        "ありがとう": 10,
        "ありがとうございます": 15,
        "感謝": 10,
        "嬉しい": 5,
        "うれしい": 5,
        "楽しい": 5,
        "たのしい": 5,
        "最高": 5,
        "大好き": 10,
        "好き": 5,
        "おめでとう": 10,
        "頑張った": 10,
        "がんばった": 10,
        "素晴らしい": 10,
        "すごい": 5,
        "幸せ": 10,
        "助かった": 5,
        "よかった": 5,
        "いいね": 5,
        "応援してる": 10,
        "大丈夫": 5,
        "できた": 5
    ]

    func analyze(_ text: String) -> PositiveAnalysisResult {

        var score = 0
        var matchedWords: [String] = []

        // 長い単語を優先して重複判定を防ぐ
        let sortedWords = positiveWords.keys.sorted {
            $0.count > $1.count
        }

        var remainingText = text

        for word in sortedWords {

            if remainingText.contains(word) {

                score += positiveWords[word] ?? 0
                matchedWords.append(word)

                remainingText = remainingText.replacingOccurrences(
                    of: word,
                    with: ""
                )
            }
        }

        return PositiveAnalysisResult(
            score: score,
            matchedWords: matchedWords
        )
    }
}
