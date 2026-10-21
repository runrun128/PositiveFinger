//
//  PositiveFingerHomeView.swift
//  PositiveFinger
//
//  Created by 市来武 on 2026/10/21.
//

import SwiftUI

struct PositiveFingerHomeView: View {

    @State private var totalPoints = 0
    @State private var sampleText = ""
    @State private var resultMessage = ""

    private let analyzer = PositiveEngine.shared
    private let pointManager = PositivePointManager.shared

    var body: some View {

        NavigationStack {

            ScrollView {

                VStack(spacing: 24) {

                    Image(systemName: "hand.point.up.left.fill")
                        .font(.system(size: 70))
                        .foregroundStyle(.orange)

                    Text("Positive Finger")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("あなたの言葉から、ポジティブを広げよう。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    VStack(spacing: 12) {

                        Text("TOTAL POINTS")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("\(totalPoints)")
                            .font(.system(size: 56, weight: .bold))
                            .foregroundStyle(.orange)

                        Text("ポイント")
                            .font(.subheadline)

                    }
                    .frame(maxWidth: .infinity)
                    .padding(30)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.orange.opacity(0.1))
                    )

                    VStack(alignment: .leading, spacing: 12) {

                        Text("ポジティブ判定テスト")
                            .font(.headline)

                        TextField(
                            "文章を入力してください",
                            text: $sampleText,
                            axis: .vertical
                        )
                        .textFieldStyle(.roundedBorder)

                        Button {

                            let result = analyzer.analyze(sampleText)

                            if result.isPositive {

                                resultMessage =
                                    "ポジティブ！ +\(result.score)ポイント"

                                pointManager.addPoints(result.score)

                                totalPoints = pointManager.totalPoints

                            } else {

                                resultMessage =
                                    "ポジティブな言葉は見つかりませんでした"
                            }

                        } label: {

                            Text("判定する")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.orange)
                                .foregroundStyle(.white)
                                .clipShape(
                                    RoundedRectangle(cornerRadius: 14)
                                )
                        }

                        Text(resultMessage)
                            .font(.subheadline)

                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.gray.opacity(0.08))
                    )

                    Text("ポジティブな言葉を、毎日の習慣に。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                }
                .padding()
            }
            .navigationTitle("ホーム")
            .onAppear {
                totalPoints = pointManager.totalPoints
            }
        }
    }
}

#Preview {
    PositiveFingerHomeView()
}
}
