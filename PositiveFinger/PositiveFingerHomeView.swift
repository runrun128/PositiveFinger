import SwiftUI

struct PositiveFingerHomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var snapshot = PositivePointManager.Snapshot()
    @State private var sampleText = ""
    @State private var result: PositiveAnalysisResult?
    @State private var storageUnavailable = false
    @State private var showingLicenses = false
    private let store = PositivePointManager.shared
    private let orange = Color(red: 0.92, green: 0.34, blue: 0.14)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack {
                        Label("Positive Finger", systemImage: "hand.point.up.left.fill")
                            .font(.headline).foregroundStyle(orange)
                        Spacer()
                        Text("ことばの力を、毎日に。")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("そのひと言が、\n今日を明るくする。")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .fixedSize(horizontal: false, vertical: true)
                        Text("「ありがとう」からはじめる、小さな習慣。")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        Label("あなたが届けたポジティブ", systemImage: "sparkles")
                            .font(.subheadline.weight(.medium))
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(snapshot.totalPoints.formatted())
                                .font(.system(size: 64, weight: .bold, design: .rounded))
                                .minimumScaleFactor(0.4).lineLimit(1)
                            Text("pt").font(.title3.bold())
                        }
                        Divider().overlay(.white.opacity(0.3))
                        HStack {
                            Label("今日 +\(store.pointsToday(snapshot)) pt", systemImage: "sun.max")
                            Spacer()
                            Text("\(snapshot.rewardedCount) 回のひと言")
                        }.font(.caption)
                    }
                    .foregroundStyle(.white).padding(24).frame(maxWidth: .infinity, alignment: .leading)
                    .background(LinearGradient(colors: [orange, Color(red: 0.98, green: 0.59, blue: 0.27)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(RoundedRectangle(cornerRadius: 28))

                    VStack(alignment: .leading, spacing: 14) {
                        Label("キーボードをはじめよう", systemImage: "keyboard")
                            .font(.headline)
                        step("1", "設定 → 一般 → キーボード → キーボード")
                        step("2", "「新しいキーボードを追加」でPositive Fingerを選択")
                        step("3", "ポイント共有には「フルアクセスを許可」をオン")
                        Text("地球儀キーで切り替え、言葉を入力して確定するとポイントが貯まります。")
                            .font(.caption).foregroundStyle(.secondary)
                        if storageUnavailable {
                            Label("共有保存先を確認できません。Xcodeの両ターゲットでApp Groupsと署名を確認してください。", systemImage: "exclamationmark.circle")
                                .font(.caption).foregroundStyle(.orange)
                        }
                    }.card()

                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("ことばを試してみる").font(.headline)
                            Spacer()
                            Text("おためし").font(.caption).foregroundStyle(orange)
                        }
                        TextField("例：いつもありがとう！", text: $sampleText, axis: .vertical)
                            .lineLimit(3...5).padding(14)
                            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
                            .onChange(of: sampleText) { _ in result = nil }
                        Button {
                            result = PositiveEngine.shared.analyze(sampleText)
                        } label: {
                            Label("ポジティブを見つける", systemImage: "sparkles")
                                .font(.subheadline.bold()).frame(maxWidth: .infinity).padding(14)
                        }
                        .buttonStyle(.plain).foregroundStyle(.white)
                        .background(orange, in: RoundedRectangle(cornerRadius: 14))
                        .disabled(sampleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        if let result {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(result.isPositive ? "素敵なひと言！ \(result.score) pt相当" : "今回は対象の言葉が見つかりませんでした。")
                                    .font(.subheadline.weight(.semibold))
                                if result.isPositive {
                                    Text(result.matchedWords.joined(separator: " ・ ")).font(.caption)
                                }
                            }.foregroundStyle(orange)
                        }
                        Text("ここでは判定だけを体験できます。ポイントはキーボードでの確定時に加算されます。")
                            .font(.caption).foregroundStyle(.secondary)
                    }.card()

                    VStack(alignment: .leading, spacing: 8) {
                        Label("あなたのことばは、あなたのもの。", systemImage: "lock.shield")
                            .font(.subheadline.bold())
                        Text("判定はすべて端末内で行います。入力文の保存・外部送信は行いません。同じ言葉の繰り返しは30秒間、重複加算されません。判定は登録語句に基づくため、文脈によっては意図と異なる結果になることがあります。")
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(.horizontal, 4)
                    Button("日本語入力・変換：azooKey / ライセンス") { showingLicenses = true }
                        .font(.caption2).foregroundStyle(.secondary)
                }.padding(24)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingLicenses) {
                NavigationStack {
                    ScrollView {
                        Text(licenseText).font(.caption).textSelection(.enabled).padding()
                    }
                    .navigationTitle("オープンソースライセンス")
                    .toolbar { Button("閉じる") { showingLicenses = false } }
                }
            }
            .onAppear(perform: refresh)
            .onChange(of: scenePhase) { phase in if phase == .active { refresh() } }
            .refreshable { refresh() }
        }.tint(orange)
    }

    private func step(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number).font(.caption.bold()).foregroundStyle(orange)
                .frame(width: 22, height: 22).background(orange.opacity(0.1), in: Circle())
            Text(text).font(.caption).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var licenseText: String {
        guard let url = Bundle.main.url(forResource: "Acknowledgements", withExtension: "txt"),
              let text = try? String(contentsOf: url) else { return "ライセンスを読み込めませんでした。" }
        return text
    }

    private func refresh() {
        do { snapshot = try store.snapshot(); storageUnavailable = false }
        catch { storageUnavailable = true }
    }
}

private extension View {
    func card() -> some View {
        self.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
    }
}
