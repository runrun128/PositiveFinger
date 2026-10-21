//
//  AzooKeyMessage.swift
//  azooKey
//
//  Created by β α on 2023/07/22.
//  Copyright © 2023 DevEn3. All rights reserved.
//

import Foundation
import KeyboardViews

public enum MessageIdentifier: String, CaseIterable, MessageIdentifierProtocol {
    case mock = "mock_alert_2022_09_16_03"
    case iOS15_4_new_emoji = "iOS_15_4_new_emoji"                    // MARK: frozen
    case iOS16_4_new_emoji = "iOS_16_4_new_emoji_commit"                    // MARK: frozen
    case iOS17_4_new_emoji = "iOS_17_4_new_emoji_commit"                    // MARK: frozen
    case ver1_9_user_dictionary_update = "ver1_9_user_dictionary_update_release" // MARK: frozen
    case ver2_1_emoji_tab = "ver2_1_emoji_tab"

    // MARK: 過去にプロダクションで用いていたメッセージID
    // ver1_9_user_dictionary_updateが実行されれば不要になるので、この宣言は削除
    // case ver1_5_update_loudstxt = "ver1_5_update_loudstxt"           // MARK: frozen
    // iOS15_4_new_emojiが実行されれば不要になるので、この宣言は削除
    // case iOS14_5_new_emoji = "iOS_14_5_new_emoji_fixed_ver_1_6_1"    // MARK: frozen
    // 新機能の紹介も削除
    // case liveconversion_introduction = "liveconversion_introduction" // MARK: frozen
    // case ver1_8_autocomplete_introduction = "ver1_8_autocomplete_introduction" // MARK: frozen

    public var key: String {
        self.rawValue + "_status"
    }

    public var needUsingContainerApp: Bool {
        switch self {
        case .ver1_9_user_dictionary_update, .ver2_1_emoji_tab:
            return true
        case .iOS15_4_new_emoji, .iOS16_4_new_emoji, .iOS17_4_new_emoji, .mock:
            return false
        }
    }

    public var id: String {
        self.rawValue
    }
}

public enum AzooKeyMessageProvider: ApplicationSpecificKeyboardViewMessageProvider {
    public typealias MessageID = MessageIdentifier

    public static var userDefaults: UserDefaults { UserDefaults(suiteName: SharedStore.appGroupKey)! }
    public static var messages: [MessageData<MessageIdentifier>] {
        [
            MessageData(
                id: .iOS15_4_new_emoji,
                title: "お知らせ",
                description: "iOS15.4で新しい絵文字が追加されました。本体アプリを開き、データを更新しますか？",
                button: .two(primary: .openContainer(text: "更新"), secondary: .later),
                precondition: {
                    if #available(iOS 15.4, *) {
                        return true
                    } else {
                        return false
                    }
                },
                silentDoneCondition: {
                    // ダウンロードがv1.8以降の場合はDone
                    if (SharedStore.initialAppVersion ?? .azooKey_v1_7_1) >= .azooKey_v1_8 {
                        return true
                    }
                    // .iOS16_4の方が終わっていたらDone
                    if MessageManager<MessageID>.checkDone(.iOS16_4_new_emoji, userDefaults: userDefaults) {
                        return true
                    }
                    return false
                },
                containerAppShouldMakeItDone: { false }
            ),
            MessageData(
                id: .iOS16_4_new_emoji,
                title: "お知らせ",
                description: "iOS16.4で「🫨 (震える顔)」「🩵 (水色のハート)」「🪽 (羽)」などの新しい絵文字が追加されました。本体アプリを開き、データを更新しますか？",
                button: .two(primary: .openContainer(text: "更新"), secondary: .later),
                precondition: {
                    if #available(iOS 16.4, *) {
                        return true
                    } else {
                        return false
                    }
                },
                silentDoneCondition: {
                    // ダウンロードがv2.0.2以降の場合はDone
                    if (SharedStore.initialAppVersion ?? .azooKey_v1_7_1) >= .azooKey_v2_0_2 {
                        return true
                    }
                    return false
                },
                containerAppShouldMakeItDone: { false }
            ),
            MessageData(
                id: .iOS17_4_new_emoji,
                title: "お知らせ",
                description: "iOS17.4で「🙂‍↕️️ (うなづく顔)」「🙂‍↔️️ (首を振る顔)」「🐦‍🔥️ (不死鳥)」などの新しい絵文字が追加されました。本体アプリを開き、データを更新しますか？",
                button: .two(primary: .openContainer(text: "更新"), secondary: .later),
                precondition: {
                    if #available(iOS 17.4, *) {
                        return true
                    } else {
                        return false
                    }
                },
                silentDoneCondition: {
                    // ダウンロードがv2.0.2以降の場合はDone
                    if (SharedStore.initialAppVersion ?? .azooKey_v1_7_1) >= .azooKey_v2_2_3 {
                        return true
                    }
                    return false
                },
                containerAppShouldMakeItDone: { false }
            ),
            MessageData(
                id: .ver1_9_user_dictionary_update,
                title: "お願い",
                description: "内部データの更新のため本体アプリを開いてください。\n更新は数秒で終わります。",
                button: .one(.openContainer(text: "更新")),
                precondition: {
                    // ユーザ辞書に登録があるのが条件。
                    let directoryPath = SharedStore.keyboardContainerURL
                    let binaryFilePath = directoryPath.appendingPathComponent("user.louds", isDirectory: false).path
                    return FileManager.default.fileExists(atPath: binaryFilePath)
                },
                silentDoneCondition: {
                    // ダウンロードがv1.9以降の場合はDone
                    if (SharedStore.initialAppVersion ?? .azooKey_v1_7_1) >= .azooKey_v1_9 {
                        return true
                    }
                    return false
                },
                containerAppShouldMakeItDone: {
                    // ユーザ辞書に登録がない場合はDoneにして良い。
                    let directoryPath = SharedStore.keyboardContainerURL
                    let binaryFilePath = directoryPath.appendingPathComponent("user.louds", isDirectory: false).path
                    return !FileManager.default.fileExists(atPath: binaryFilePath)
                }
            ),
            MessageData(
                id: .ver2_1_emoji_tab,
                title: "お知らせ",
                description: "azooKeyで絵文字タブが使えるようになりました。本体アプリを開き、タブバーに絵文字タブを追加しますか？",
                button: .two(primary: .openContainer(text: "追加"), secondary: .later),
                precondition: {
                    true
                },
                silentDoneCondition: {
                    if (try? CustardManager.load().tabbar(identifier: 0))?.items.contains(where: {$0.actions.contains(.moveTab(.system(.emoji_tab)))}) == true {
                        return true
                    }
                    return false
                },
                containerAppShouldMakeItDone: { true }
            )
        ]
    }
}

public extension MessageManager where ID == MessageIdentifier {
    @MainActor init() {
        self.init(necessaryMessages: AzooKeyMessageProvider.messages, userDefaults: UserDefaults(suiteName: SharedStore.appGroupKey)!)
    }
}
