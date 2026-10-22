import SwiftUI
import Charts

private enum Pop {
    static let ink = Color(red: 0.15, green: 0.13, blue: 0.23)
    static let paper = Color(red: 1, green: 0.98, blue: 0.92)
    static let pink = Color(red: 1, green: 0.43, blue: 0.62)
    static let yellow = Color(red: 1, green: 0.84, blue: 0.26)
    static let purple = Color(red: 0.45, green: 0.33, blue: 0.85)
    static let colors: [Color] = [pink, Color(red: 0.48, green: 0.78, blue: 1), yellow,
                                   Color(red: 0.44, green: 0.83, blue: 0.68), Color(red: 0.75, green: 0.63, blue: 1), Color(red: 1, green: 0.67, blue: 0.43)]
    static let names = ["もも", "ソーダ", "レモン", "ミント", "ライラック", "ピーチ"]
    static let notes = ["のんびり、きみのペースで。", "ちょっとひと息、しゅわっと。", "小さなできたを、ひとつずつ。", "いつものことばに、深呼吸。", "今日はどんなことばに会える？", "ありがとうって、あったかい。"]
    static func index(_ id: String) -> Int { PositiveActivityStore.characters.firstIndex(of: id) ?? 0 }
}

struct PositiveFingerHomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var snapshot = PositiveActivityStore.Snapshot()
    @State private var tab = 0
    @State private var sample = ""
    @State private var result: PositiveAnalysisResult?
    @State private var error: String?
    @State private var reveal: String?
    @State private var drawing = false
    @State private var playMode = 0
    @State private var pendingExchange: String?
    #if DEBUG
    @State private var showingDebugMenu = false
    @State private var confirmingDebugReset = false
    @State private var debugMessage: String?
    #endif
    @State private var showSetup = false
    @State private var showLicenses = false
    private let store = PositiveActivityStore.shared

    var body: some View {
        TabView(selection: $tab) {
            page { home }.tabItem { Label("ホーム", systemImage: "house.fill") }.tag(0)
            page {
                Picker("あそぶ", selection: $playMode) { Text("ガチャ").tag(0); Text("イベント").tag(1) }.pickerStyle(.segmented)
                if playMode == 0 { arcade } else { events }
            }.tabItem { Label("あそぶ", systemImage: "sparkles.rectangle.stack.fill") }.tag(1)
            page { collection }.tabItem { Label("ずかん", systemImage: "square.grid.2x2.fill") }.tag(2)
            page { exchangeShop }.tabItem { Label("交換所", systemImage: "gift.fill") }.tag(3)
            NavigationStack { settings }.tabItem { Label("設定", systemImage: "slider.horizontal.3") }.tag(4)
        }
        .tint(Pop.purple).preferredColorScheme(.light)
        .confirmationDialog("ポイントを使って交換しますか？", isPresented: Binding(get: { pendingExchange != nil }, set: { if !$0 { pendingExchange = nil } }), titleVisibility: .visible) {
            if let id = pendingExchange {
                Button("\(PositiveActivityStore.exchangeCosts[id, default: 0]) ptで交換") { redeem(id); pendingExchange = nil }
            }
            Button("キャンセル", role: .cancel) { pendingExchange = nil }
        }
        .onAppear {
            // PositiveFinger deliberately starts with manual conversion, including existing installs.
            let defaults = UserDefaults(suiteName: PositiveActivityStore.appGroupID)
            if defaults?.bool(forKey: "pf_manual_conversion_migrated") != true {
                defaults?.set(false, forKey: "live_conversion")
                defaults?.set(true, forKey: "pf_manual_conversion_migrated")
            }
            refresh()
        }
        .onChange(of: scenePhase) { if $0 == .active { refresh() } }
        .alert("お知らせ", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) { error = nil }
        } message: { Text(error ?? "") }
        .sheet(isPresented: $showSetup) { setup }
        #if DEBUG
        .sheet(isPresented: $showingDebugMenu) { debugMenu }
        #endif
        .sheet(isPresented: $showLicenses) {
            NavigationStack {
                ScrollView { Text(licenses).font(.caption).textSelection(.enabled).padding() }
                    .navigationTitle("ライセンス").toolbar { Button("閉じる") { showLicenses = false } }
            }
        }
        .sheet(item: Binding(get: { reveal.map { Prize(id: $0) } }, set: { reveal = $0?.id })) { prize in
            prizeView(prize.id).presentationDetents([.medium, .large])
        }
    }

    private func page<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            ScrollView { VStack(alignment: .leading, spacing: 24) { content() }.padding(22) }
                .background(snapshot.exchanges.contains("sky") ? Pop.colors[1].opacity(0.14) : Pop.paper).foregroundStyle(Pop.ink)
                .toolbar(.hidden, for: .navigationBar)
                .refreshable { refresh() }
        }
    }

    private var home: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("POSITIVE").tracking(3)
                    Text("FINGER!").tracking(3)
                }.font(.system(size: 16, weight: .black, design: .rounded))
                Spacer()
                Button { showSetup = true } label: { Image(systemName: "keyboard").font(.title3).padding(13).popPanel(.white, radius: 18) }
                    .accessibilityLabel("キーボードの使い方")
            }
            HStack(alignment: .top) {
                Text("ことばが、\nごほうびに。").font(.system(size: 34, weight: .black, design: .rounded)).lineSpacing(3)
                Spacer(minLength: 0)
                Text(snapshot.exchanges.contains("wordfriend") ? "ことばの友" : "HELLO!").font(.system(size: 12, weight: .black, design: .rounded)).padding(12)
                    .background(Pop.yellow, in: Capsule()).rotationEffect(.degrees(9)).padding(.top, 12)
            }
            VStack(spacing: 0) {
                HStack {
                    Text("きょうの相棒").font(.caption.bold())
                    Spacer()
                    Text("NO. 0\(Pop.index(snapshot.equipped) + 1)").font(.system(.caption, design: .monospaced).bold())
                }
                Companion(index: Pop.index(snapshot.equipped)).frame(height: 155).padding(.vertical, 8)
                Text(Pop.notes[Pop.index(snapshot.equipped)]).font(.subheadline.bold()).padding(.bottom, 18)
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("つかえるポイント").font(.caption.bold())
                        (Text(snapshot.balance.formatted()).font(.system(size: 45, weight: .black, design: .rounded)) + Text(" pt").font(.headline))
                    }
                    Spacer()
                    Button { playMode = 0; tab = 1 } label: { Image(systemName: "arrow.up.right").font(.title2.bold()).frame(width: 50, height: 50).popPanel(Pop.yellow, radius: 18) }
                        .accessibilityLabel("ガチャへ")
                }.padding(.top, 18).overlay(alignment: .top) { Rectangle().frame(height: 1.5) }
            }.padding(20).popPanel(Pop.colors[Pop.index(snapshot.equipped)].opacity(0.28), radius: 28)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("きょうのことば貯金").font(.headline)
                    Spacer()
                    Text("\(snapshot.dailyEarned) / 100 pt").font(.caption.bold())
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Pop.ink.opacity(0.08))
                        Capsule().fill(Pop.purple).frame(width: geo.size.width * min(1, CGFloat(snapshot.dailyEarned) / 100))
                    }
                }.frame(height: 12)
                Text("前向きな表現を確定すると +5 pt。\n無理せず、いつもの会話で。")
                    .font(.caption).lineSpacing(4).foregroundStyle(Pop.ink.opacity(0.65))
            }
            Button { showSetup = true } label: {
                HStack { Image(systemName: "keyboard"); Text("まずはキーボードを使ってみよう").font(.subheadline.bold()); Spacer(); Image(systemName: "chevron.right") }
                    .padding(17).popPanel(.white, radius: 18)
            }
            HStack(spacing: 14) {
                Button { playMode = 1; tab = 1 } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: "flag.2.crossed.fill").font(.title2)
                        Text("みんなのクエスト").font(.subheadline.bold())
                        Text("イベントを見る →").font(.caption)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(16).popPanel(Pop.colors[3].opacity(0.3))
                }
                Button { tab = 3 } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: "gift.fill").font(.title2)
                        Text("ポイント交換所").font(.subheadline.bold())
                        Text("ごほうびを選ぶ →").font(.caption)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(16).popPanel(Pop.yellow.opacity(0.4))
                }
            }.buttonStyle(.plain)
            Text("アプリ内専用ポイントです。現金・ギフト券への交換はまだありません。")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var arcade: some View {
        VStack(alignment: .leading, spacing: 22) {
            eyebrow("THE CAPSULE CLUB")
            Text("次は、だれに\n会えるかな？").font(.system(size: 32, weight: .black, design: .rounded))
            HStack { Text("相棒カプセル").font(.headline); Spacer(); Text("全6種").font(.caption.bold()).padding(8).background(.white, in: Capsule()) }
            ZStack {
                RoundedRectangle(cornerRadius: 36).fill(Pop.colors[1].opacity(0.28))
                VStack(spacing: 0) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 55).fill(.white.opacity(0.7)).overlay(RoundedRectangle(cornerRadius: 55).stroke(Pop.ink, lineWidth: 2))
                        HStack(spacing: -16) {
                            ForEach(0..<3) { i in Companion(index: i).frame(width: 84, height: 100).rotationEffect(.degrees(Double(i - 1) * 18)) }
                        }.padding(.top, 14)
                        Text("PF").font(.system(size: 15, weight: .black, design: .rounded)).offset(y: -65)
                    }.frame(height: 192)
                    VStack(spacing: 12) {
                        Text("GOOD WORDS, GOOD FRIENDS").font(.system(size: 9, weight: .black, design: .monospaced)).tracking(1)
                        Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 33, weight: .bold))
                            .rotationEffect(.degrees(drawing && !reduceMotion ? 180 : 0))
                            .animation(.easeInOut(duration: 0.5), value: drawing)
                            .frame(width: 70, height: 70).popPanel(Pop.yellow, radius: 35)
                        Capsule().fill(Pop.ink).frame(width: 90, height: 15)
                    }.frame(maxWidth: .infinity).padding(18).background(Pop.pink)
                        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Pop.ink, lineWidth: 2))
                }.frame(maxWidth: 245).padding(26)
            }.frame(height: 365)
            Button(action: draw) {
                HStack { Text(drawing ? "ころころ…" : "1回まわす").font(.headline); Spacer(); Text("25 pt").font(.headline) }
                    .padding(20).foregroundStyle(.white).popPanel(Pop.purple, radius: 20)
            }.disabled(drawing || snapshot.balance < 25)
                .opacity(snapshot.balance < 25 ? 0.5 : 1)
            Text(snapshot.balance < 25 ? "あと \(25 - snapshot.balance) pt でまわせるよ。" : "いま \(snapshot.balance) pt ／ 1回 25 pt")
                .font(.subheadline.bold()).frame(maxWidth: .infinity)
            Text("全6種・各1/6の確率。重複あり。出会った相棒はずかんに残ります。ポイントの購入はありません。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var collection: some View {
        VStack(alignment: .leading, spacing: 20) {
            eyebrow("YOUR LITTLE FRIENDS")
            HStack(alignment: .firstTextBaseline) {
                Text("相棒ずかん").font(.system(size: 32, weight: .black, design: .rounded))
                Spacer()
                Text("\(PositiveActivityStore.characters.filter { $0 == "momo" || snapshot.collection[$0, default: 0] > 0 }.count) / 6").font(.headline)
            }
            Text("集めて、選んで。ホームでいっしょに。").font(.subheadline).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(Array(PositiveActivityStore.characters.enumerated()), id: \.element) { i, id in
                    let unlocked = id == "momo" || snapshot.collection[id, default: 0] > 0
                    Button {
                        do { try store.equip(id); refresh() } catch { self.error = "相棒を選べませんでした。" }
                    } label: {
                        VStack(spacing: 8) {
                            HStack { Text(String(format: "NO. %02d", i + 1)); Spacer(); if snapshot.equipped == id { Image(systemName: "checkmark.circle.fill") } }.font(.caption2.bold())
                            if unlocked { Companion(index: i).frame(height: 90) }
                            else { Image(systemName: "questionmark").font(.system(size: 36, weight: .black, design: .rounded)).frame(height: 90).opacity(0.3) }
                            Text(unlocked ? Pop.names[i] : "？？？").font(.headline)
                            Text(id == "momo" ? "はじめの相棒" : unlocked ? "\(snapshot.collection[id, default: 0])回出会った" : "カプセルで出会おう").font(.caption2)
                        }.padding(14).frame(maxWidth: .infinity).popPanel(unlocked ? Pop.colors[i].opacity(0.24) : .white, radius: 22)
                    }.buttonStyle(.plain).disabled(!unlocked)
                }
            }
        }
    }

    private var exchangeShop: some View {
        VStack(alignment: .leading, spacing: 22) {
            eyebrow("THE REWARD COUNTER")
            Text("がんばった分、\nすきなものに。").font(.system(size: 32, weight: .black, design: .rounded))
            HStack { Text("つかえるポイント").font(.subheadline.bold()); Spacer(); Text("\(snapshot.balance) pt").font(.title2.bold()) }
                .padding(20).popPanel(Pop.yellow, radius: 22)
            Text("アプリのごほうび").font(.headline)
            exchangeItem(id: "wordfriend", title: "称号「ことばの友」", description: "ホームのバッジに、あなたの称号を。", symbol: "rosette", color: Pop.pink.opacity(0.25))
            exchangeItem(id: "sky", title: "背景「ソーダの空」", description: "ホームやずかんを、さわやかな空色に。", symbol: "cloud.sun.fill", color: Pop.colors[1].opacity(0.3))
            VStack(alignment: .leading, spacing: 14) {
                Label("いつか、毎日のうれしいに。", systemImage: "giftcard").font(.headline)
                Text("ギフト券・他社ポイントへの交換").font(.subheadline.bold())
                Text("準備中").font(.caption.bold()).padding(.horizontal, 12).padding(.vertical, 6).background(Pop.ink.opacity(0.07), in: Capsule())
                Text("提携サービスとの接続後に公開します。今のポイントはアプリ内専用で、現金やギフト券への交換はできません。")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(20).popPanel(.white)
            Text("交換した背景と称号は自動で反映されます。交換済みのものに再びポイントは使いません。").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func exchangeItem(id: String, title: String, description: String, symbol: String, color: Color) -> some View {
        let owned = snapshot.exchanges.contains(id)
        let cost = PositiveActivityStore.exchangeCosts[id, default: 0]
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 15) {
                Image(systemName: symbol).font(.system(size: 30)).frame(width: 60, height: 65).background(color, in: RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 7) {
                    Text(title).font(.headline)
                    Text(description).font(.caption).foregroundStyle(.secondary)
                }
            }
            Button { pendingExchange = id } label: {
                HStack { Text(owned ? "交換済み・使用中" : "交換する"); Spacer(); if !owned { Text("\(cost) pt") } else { Image(systemName: "checkmark.circle.fill") } }
                    .font(.subheadline.bold()).padding(14).foregroundStyle(owned ? Pop.ink : .white)
                    .background(owned ? Pop.ink.opacity(0.08) : Pop.purple, in: RoundedRectangle(cornerRadius: 13))
            }.disabled(owned || snapshot.balance < cost).opacity(!owned && snapshot.balance < cost ? 0.45 : 1)
        }.padding(20).popPanel(.white)
    }

    private var events: some View {
        VStack(alignment: .leading, spacing: 22) {
            eyebrow("TOGETHER, A LITTLE BETTER")
            Text("ひとりの一歩が、\nみんなの力に。").font(.system(size: 32, weight: .black, design: .rounded))
            VStack(alignment: .leading, spacing: 18) {
                HStack { Label("全員参加クエスト", systemImage: "flag.2.crossed.fill").font(.headline); Spacer(); Text("公開準備中").font(.caption.bold()) }
                Text("ことばで咲かせる、\nありがとうの木").font(.system(size: 27, weight: .black, design: .rounded))
                HStack(spacing: 6) {
                    ForEach(0..<3) { i in Companion(index: [3, 2, 0][i]).frame(height: 105) }
                }.padding(.vertical, 8)
                Text("みんなで10,000回の前向きなことばを集めよう。達成したら参加者全員に限定の相棒を。")
                    .font(.subheadline).lineSpacing(4)
                Divider()
                Text("全体進捗：まだ集計していません").font(.subheadline.bold())
                Text("登録・共有サーバーに未接続です。開催日と正式な報酬は公開時に決定します。他の人の入力文は表示しません。")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(22).popPanel(Pop.colors[3].opacity(0.27), radius: 26)
            VStack(alignment: .leading, spacing: 16) {
                HStack { Text("まずは練習クエスト").font(.headline); Spacer(); Text("この端末限定").font(.caption.bold()) }
                Text("いつものことばを、5つ。").font(.title3.bold())
                Text("参加後、ポイント対象の異なる入力を5件確定してみよう。同じ文の繰り返しや、1日の獲得上限後の入力は進捗に含みません。")
                    .font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    ForEach(0..<5) { i in
                        Image(systemName: i < snapshot.questProgress ? "checkmark" : "circle")
                            .font(.headline).frame(maxWidth: .infinity).frame(height: 36)
                            .background(i < snapshot.questProgress ? Pop.yellow : .white, in: RoundedRectangle(cornerRadius: 10))
                    }
                }.accessibilityElement(children: .ignore).accessibilityLabel("進捗5件中\(snapshot.questProgress)件")
                HStack { Text("達成報酬").font(.caption.bold()); Spacer(); Text("25 pt").font(.title3.bold()) }
                Button {
                    do {
                        if !snapshot.questJoined { try store.joinPracticeQuest() }
                        else { try store.claimPracticeQuest() }
                        refresh()
                    } catch { self.error = "クエストを更新できませんでした。" }
                } label: {
                    Text(snapshot.questClaimed ? "報酬を受け取りました" : !snapshot.questJoined ? "練習クエストに参加" : snapshot.questProgress >= 5 ? "25 ptを受け取る" : "参加中 · \(snapshot.questProgress) / 5")
                        .font(.headline).padding(16).frame(maxWidth: .infinity).foregroundStyle(.white).background(Pop.purple, in: RoundedRectangle(cornerRadius: 15))
                }.disabled(snapshot.questClaimed || (snapshot.questJoined && snapshot.questProgress < 5))
            }.padding(20).popPanel(.white)
            Text("練習の進捗は全体イベントには送信されません。参加状態と進捗はアプリを閉じても残ります。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func redeem(_ id: String) {
        do { try store.exchange(id); refresh() }
        catch PositiveActivityStore.StoreError.insufficientPoints { error = "ポイントが足りません。" }
        catch PositiveActivityStore.StoreError.alreadyOwned { refresh() }
        catch { self.error = "交換を保存できませんでした。ポイント残高を確認してください。" }
    }

    private var settings: some View {
        Form {
            Section("キーボード") {
                Button("キーボードの追加・使い方") { showSetup = true }
                Toggle("入力中の自動変換", isOn: Binding(
                    get: { UserDefaults(suiteName: PositiveActivityStore.appGroupID)?.bool(forKey: "live_conversion") ?? false },
                    set: { UserDefaults(suiteName: PositiveActivityStore.appGroupID)?.set($0, forKey: "live_conversion"); refresh() }
                ))
                Text("オフなら、候補をタップしたときに漢字へ変換します。変更後は入力を確定し、キーボードを切り替えてください。").font(.caption)
                Toggle("検出時のメッセージ", isOn: Binding(get: { snapshot.settings.feedbackEnabled }, set: {
                    var settings = snapshot.settings; settings.feedbackEnabled = $0; save(settings)
                }))

            }
            Section("ことばの研究室") {
                TextField("例：今日はありがとうと言えた", text: $sample, axis: .vertical).onChange(of: sample) { _ in result = nil }
                Button("端末内でおためし判定") { result = PositiveEngine.shared.analyze(sample) }.disabled(sample.isEmpty)
                if let result { Text(result.isPositive ? "見つけた表現：" + result.matchedWords.joined(separator: "・") : "今回は対象の表現は見つかりませんでした。").font(.subheadline) }
                Text("おためしではポイントはつきません。現在は登録語句と否定表現のルールで判定しています。AIの接続は準備中です。").font(.caption)
            }
            Section("ことばの記録") {
                HStack { Text("これまでの検出"); Spacer(); Text("\(snapshot.detectionCount)回").bold() }
                Chart(recentDays, id: \.self) { date in
                    BarMark(x: .value("日", date, unit: .day), y: .value("回数", snapshot.dailyCounts[PositiveActivityStore.dayKey(date), default: 0])).foregroundStyle(Pop.purple).cornerRadius(3)
                }.chartYScale(domain: 0...max(1, recentDays.map { snapshot.dailyCounts[PositiveActivityStore.dayKey($0), default: 0] }.max() ?? 0)).frame(height: 130)
            }
            Section("ポイントについて") {
                Text("対象の表現を確定すると5 pt。1日100 ptまで。ガチャは25 pt、全6種が同じ確率で出ます。相棒の重複はずかんで確認できます。")
                Text("ポイントはこの端末のアプリ内専用です。換金・他社ポイントへの交換・購入には対応していません。")
            }.font(.caption)
            Section("プライバシー") {
                Text("現在のバージョンは入力文を外部に送りません。全文や入力履歴も保存しません。端末内に回数・ポイント・相棒・設定と、重複判定用のハッシュを保存します。語句の検出は気持ちの評価ではありません。パスワードなどの機密入力は解析対象外です。").font(.caption)
                Button("オープンソースライセンス") { showLicenses = true }
            }
            Text("POSITIVE FINGER / PLAYFUL PROTOTYPE").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
                #if DEBUG
                .contentShape(Rectangle())
                .onTapGesture(count: 5) { debugMessage = nil; showingDebugMenu = true }
                #endif
        }.navigationTitle("設定とあそび方")
    }

    #if DEBUG
    private var debugMenu: some View {
        NavigationStack {
            Form {
                Section {
                    Label("開発・動作確認専用", systemImage: "wrench.and.screwdriver.fill")
                    Text("このメニューは開発用ビルドだけに含まれます。追加したポイントは現金や他社ポイントには交換できません。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("ポイントを追加") {
                    HStack { Text("現在の残高"); Spacer(); Text("\(snapshot.balance) pt").bold() }
                    ForEach([100, 1000, 10000], id: \.self) { amount in
                        Button("＋\(amount.formatted()) pt") {
                            do {
                                try store.debugAddPoints(amount)
                                refresh()
                                debugMessage = "\(amount.formatted()) pt追加しました。"
                            } catch { debugMessage = "追加できませんでした。" }
                        }
                    }
                    Text("テスト追加は通常の獲得上限やクエストの進捗には含みません。残高の上限は1,000,000 ptです。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("データリセット") {
                    Button("プレイデータをリセット", role: .destructive) { confirmingDebugReset = true }
                    Text("ポイント・検出記録・相棒・交換アイテム・クエストを初期状態に戻します。キーボードの設定は残します。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let debugMessage { Section { Text(debugMessage).font(.subheadline).accessibilityAddTraits(.updatesFrequently) } }
            }
            .navigationTitle("テストメニュー")
            .toolbar { Button("閉じる") { showingDebugMenu = false } }
            .confirmationDialog("プレイデータをリセットしますか？", isPresented: $confirmingDebugReset, titleVisibility: .visible) {
                Button("リセットする", role: .destructive) {
                    do {
                        try store.debugResetProgress()
                        refresh()
                        result = nil; sample = ""; reveal = nil
                        debugMessage = "プレイデータをリセットしました。"
                    } catch { debugMessage = "リセットできませんでした。" }
                }
                Button("キャンセル", role: .cancel) { }
            } message: { Text("元には戻せません。設定とキーボードの登録状態はそのまま残ります。") }
        }
    }
    #endif

    private var setup: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Companion(index: 0).frame(height: 140).frame(maxWidth: .infinity)
                    Text("いつもの入力で、\nポイントをためよう。").font(.system(size: 28, weight: .black, design: .rounded))
                    ForEach(Array(["設定 → 一般 → キーボード → キーボードを開く", "新しいキーボードを追加 → Positive Finger", "Positive Fingerのフルアクセスを許可", "メモなどで地球儀キーを押して切り替える"].enumerated()), id: \.offset) { i, text in
                        HStack(alignment: .top, spacing: 14) {
                            Text("\(i + 1)").font(.headline).frame(width: 30, height: 30).background(Pop.yellow, in: Circle())
                            Text(text).font(.subheadline.bold()).padding(.top, 4)
                        }
                    }
                    Text("フルアクセスはポイントと設定をアプリに共有するために使います。このバージョンでは入力文を外部へ送信しません。入力の確定を検出し、送信ボタンが押されたかどうかは判定しません。").font(.caption).foregroundStyle(.secondary)
                    Button("iPhoneの設定を開く") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }.font(.headline).padding().frame(maxWidth: .infinity).foregroundStyle(.white).popPanel(Pop.purple)
                }.padding(24)
            }.background(Pop.paper).foregroundStyle(Pop.ink)
                .toolbar { Button("閉じる") { showSetup = false } }
        }
    }

    private func prizeView(_ id: String) -> some View {
        VStack(spacing: 20) {
            Text("HELLO, NEW FRIEND!").font(.system(.caption, design: .monospaced).bold()).tracking(2)
            Companion(index: Pop.index(id)).frame(height: 150)
            Text("\(Pop.names[Pop.index(id)])がやってきた！").font(.title2.bold())
            Text("\(snapshot.collection[id, default: 0])回目の出会い。ずかんから相棒に選べるよ。").font(.caption)
            Button("相棒にする") {
                do { try store.equip(id); refresh(); reveal = nil; tab = 0 } catch { self.error = "相棒を選べませんでした。" }
            }.font(.headline).padding(16).frame(maxWidth: .infinity).foregroundStyle(.white).popPanel(Pop.purple)
            Button("ずかんを見る") { reveal = nil; tab = 2 }.font(.subheadline.bold())
        }.padding(28).frame(maxWidth: .infinity, maxHeight: .infinity).background(Pop.paper).foregroundStyle(Pop.ink)
    }

    private func draw() {
        guard !drawing else { return }
        do {
            let id = try store.draw()
            refresh(); drawing = true
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: reduceMotion ? 0 : 600_000_000)
                drawing = false; reveal = id
            }
        } catch PositiveActivityStore.StoreError.insufficientPoints { error = "ポイントが足りません。" }
        catch { self.error = "ガチャを保存できませんでした。もう一度お試しください。" }
    }
    private func refresh() {
        do { snapshot = try store.snapshot() }
        catch { self.error = "データを読み込めませんでした。アプリを開き直してください。" }
    }
    private func save(_ settings: PositiveActivityStore.Settings) {
        do { try store.updateSettings(settings); refresh() } catch { self.error = "設定を保存できませんでした。" }
    }
    private func eyebrow(_ text: String) -> some View { Text(text).font(.system(size: 11, weight: .black, design: .monospaced)).tracking(2).foregroundStyle(Pop.purple) }
    private var recentDays: [Date] { (-6...0).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: Calendar.current.startOfDay(for: Date())) } }
    private var licenses: String { Bundle.main.url(forResource: "Acknowledgements", withExtension: "txt").flatMap { try? String(contentsOf: $0) } ?? "ライセンスを読み込めませんでした。" }
    private struct Prize: Identifiable { let id: String }
}

/// A small, vector-drawn finger companion; scales cleanly on iPhone 8 and Dynamic Type layouts.
private struct Companion: View {
    let index: Int
    var body: some View {
        GeometryReader { geo in
            let h = min(geo.size.height, geo.size.width * 1.05)
            ZStack {
                Ellipse().fill(Pop.ink.opacity(0.12)).frame(width: h * 0.75, height: h * 0.09).offset(y: h * 0.43)
                Capsule().fill(Pop.colors[index]).frame(width: h * 0.57, height: h * 0.86)
                    .overlay(Capsule().stroke(Pop.ink, lineWidth: 2.5))
                Capsule().fill(.white.opacity(0.45)).frame(width: h * 0.23, height: h * 0.18).offset(y: -h * 0.23)
                HStack(spacing: h * 0.16) {
                    ForEach(0..<2) { _ in Capsule().fill(Pop.ink).frame(width: h * 0.035, height: h * 0.07) }
                }.offset(y: h * 0.05)
                HStack(spacing: h * 0.24) { ForEach(0..<2) { _ in Ellipse().fill(Color.white.opacity(0.5)).frame(width: h * 0.08, height: h * 0.045) } }.offset(y: h * 0.13)
                Text(index == 2 ? "⌣" : "ᴗ").font(.system(size: h * 0.19, weight: .bold, design: .rounded)).offset(y: h * 0.14)
                if index == 4 { Image(systemName: "star.fill").font(.system(size: h * 0.15)).foregroundStyle(Pop.yellow).offset(x: h * 0.25, y: -h * 0.3) }
                if index == 3 { Image(systemName: "leaf.fill").font(.system(size: h * 0.18)).foregroundStyle(Pop.purple).rotationEffect(.degrees(-20)).offset(x: h * 0.2, y: -h * 0.32) }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.accessibilityElement(children: .ignore).accessibilityLabel("相棒の" + Pop.names[index])
    }
}
private extension View {
    func popPanel(_ color: Color, radius: CGFloat = 20) -> some View {
        self.background {
            RoundedRectangle(cornerRadius: radius).fill(color)
                .shadow(color: Pop.ink, radius: 0, x: 0, y: 3)
        }
        .overlay(RoundedRectangle(cornerRadius: radius).stroke(Pop.ink, lineWidth: 1.8))
    }
}
