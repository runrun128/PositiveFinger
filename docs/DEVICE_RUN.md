# シミュレータを追加せずiPhone 8へ入れる

2026-10-22、Xcode 15.3 / iPhone 8（iOS 16.7.8）で署名付きビルド、端末へのインストール、信頼設定後の実機起動に成功。App Launch計測がエラーなく完了したことを確認。

## 分かった原因と対処

端末自体は認識されていても、シミュレータ未導入の判定によって、実機も実行先から除外されていた。

Xcode内の診断用設定 `-IDEPlatformCoordinatorIgnoreSimulatorStatus=YES` を、そのコマンドに限って指定すると実機を選べた。実機を選んだスキームビルドでは、Personal Teamの端末登録・開発用プロファイル生成も成功した。

この設定はXcodeの内部設定であり、他のバージョンでの動作は保証しない。恒久設定やXcode本体の改変は行っていない。通常のGUIの実行ボタンには、このコマンドの指定は反映されない。

画像カタログのコンパイルにもシミュレータが要求されるため、この経路では `EXCLUDED_SOURCE_FILE_NAMES=*.xcassets` を指定する。キーボードの明暗・高コントラストの色は、同じ色定義を使うコード側のフォールバックを追加した。既存のカタログは保持しており、通常ビルドではそちらを優先する。AppIconは現在未設定のため、この経路では仮のアイコンになる。

## 次回のビルド

端末をUSB接続してロックを解除し、リポジトリで実行する。

```sh
bash scripts/build-iphone.sh
```

複数端末が接続されている場合はUDIDを第1引数に指定する。スクリプトは既存の署名アカウントで必要な端末登録・プロファイル更新を行う。iOSランタイムのダウンロードや有料登録は行わない。Swift Packageの依存関係は既存キャッシュを優先する。

生成先：`.build/device-run/Build/Products/Debug-iphoneos/PositiveFinger.app`

## 転送と起動

1. Xcode → Window → Devices and Simulators → 接続中のiPhoneを選ぶ。
2. Installed Appsの＋から、生成した `PositiveFinger.app` を選択。
3. 初回はiPhoneの設定 → 一般 → VPNとデバイス管理 → デベロッパAPPで、自分の開発用Apple IDを信頼する。
4. iPhone上の「Positive Finger」を開く。

既に転送済みのアプリをターミナルで起動確認する場合は、Xcode同梱の `xctrace` が使える。

```sh
xcrun xctrace record --template 'App Launch' --device '<端末のUDID>' \
  --time-limit 3s --output /tmp/positivefinger-launch.trace \
  --launch -- com.positivefinger.PositiveFinger
```

これは短時間の起動計測であり、アプリの転送は行わない。出力先は毎回新しいパスを指定する。Personal Teamの署名には有効期限があり、期限が切れたら再ビルド・再インストールする。
