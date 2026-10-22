//
//  PositiveEngine.swift
//  PositiveFinger
//
//  Created by 市来武 on 2026/10/21.
//

import Foundation

struct PositiveAnalysisResult {
    let matchedWords: [String]

    var isPositive: Bool {
        !matchedWords.isEmpty
    }
}

protocol PositiveExpressionAnalyzing {
    func analyze(_ text: String) -> PositiveAnalysisResult
}

final class PositiveEngine: PositiveExpressionAnalyzing {

    static let shared = PositiveEngine()

    private init() {}

    private let positiveWords: [String] = [
        "ありがとう",
        "ありがとうございます",
        "感謝",
        "嬉しい",
        "うれしい",
        "楽しい",
        "たのしい",
        "最高",
        "大好き",
        "好き",
        "おめでとう",
        "頑張った",
        "がんばった",
        "素晴らしい",
        "すごい",
        "幸せ",
        "助かった",
        "よかった",
        "いいね",
        "応援してる",
        "大丈夫",
        "できた"
    ]

    func analyze(_ text: String) -> PositiveAnalysisResult {

        var matchedWords: [String] = []

        // 長い単語を優先して重複判定を防ぐ
        let sortedWords = positiveWords.sorted {
            $0.count == $1.count ? $0 < $1 : $0.count > $1.count
        }

        var remainingText = text.precomposedStringWithCompatibilityMapping

        for word in sortedWords {

            if remainingText.ranges(of: word).contains(where: { range in
                let tail = String(remainingText[range.upperBound...].prefix(16))
                let negations = ["じゃない", "ではない", "でない", "くない", "しくない", "とは思わない", "と思わない", "と言えな", "って言えな", "といえな", "とは言えな", "ではなかった", "じゃなかった", "くなかった", "しくなかった", "ない", "なかった"]
                return !negations.contains(where: { tail.hasPrefix($0) })
            }) {

                matchedWords.append(word)

                remainingText = remainingText.replacingOccurrences(
                    of: word,
                    with: "\u{FFFC}"
                )
            }
        }

        return PositiveAnalysisResult(
            matchedWords: matchedWords
        )
    }
}

private extension String {
    func ranges(of word: String) -> [Range<String.Index>] {
        var result: [Range<String.Index>] = []
        var start = startIndex
        while start < endIndex, let range = range(of: word, range: start..<endIndex) {
            result.append(range); start = range.upperBound
        }
        return result
    }
}
