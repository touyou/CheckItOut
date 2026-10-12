# セキュリティ点検結果（2026-10-12）

IPA の 2026-10-09 の注意喚起（[不正アクセスによる漏えい等の事案を踏まえ、速やかに実施すべき対策等について](https://www.ipa.go.jp/security/security-alert/2026/alert20261009.html)）に沿って、アプリのみのプロジェクト向けの点検手順を当てはめた結果。対象は main `4d5dd7e` 時点。

鍵の埋め込みと通信まわりの問題は無し。残っている所見は中 1 件、低 4 件。

確かめていないものは「未確認」と書き、推測で埋めていない。

## 所見

| 重大度 | 場所 | 内容 | 確かめた範囲 | 状態 |
| --- | --- | --- | --- | --- |
| 中 | GitHub の共同作業者 | write 権限を持つ共同作業者が 1 名いる。`production` に push でき、Xcode Cloud の TestFlight 向けビルドを起動できる | GitHub API で権限を確認 | 未対応。今も必要か判断する |
| 中 | GitHub の Webhook 設定 | 2019-01-11 作成の Webhook が push のたびに `webhooks.receiver.gitguardian.ovh` へ通知していた。GitGuardian の正規の受け口かは未確認 | GitHub API で設定を確認 | 対応済み。2026-10-12 に削除 |
| 低 | GitHub のセキュリティ設定 | secret scanning と push protection が無効だった | GitHub API で確認 | 対応済み。2026-10-12 に両方を有効化 |
| 低 | `Checkitout/AudioSample/` の `hosaka.wav`、`kirin.wav`、`taguchi.wav` | 個人の音声が公開リポジトリとアプリに入っている。使うのは `Checkitout/Services/Migration.swift` の `#if DEBUG` 内だけ | リポジトリと Debug ビルドの中身を確認。リリースビルドへの同梱は推測 | 未対応 |
| 低 | アプリ本体 | `PrivacyInfo.xcprivacy` が無い。`Checkitout/Services/Migration.swift` で `UserDefaults` を使っており、理由の申告が要る API に当たる。Realm の 3 つのバンドルには同梱されている | ソースと Debug ビルドの中身を確認 | 未対応 |
| 低 | コミット履歴 | 47 コミットに個人のメールアドレスが残っている | `git log` で確認 | 未対応 |
| 低 | 未追跡の `Checkitout.xcodeproj/xcshareddata/xcodecloud/manifest.json` | Xcode Cloud のワークフローの内部 ID が入っている。コミットすると公開される | ファイルの中身を確認 | 未対応。コミットするか判断する |

過去の履歴にある `.pem` 6 件は、Carthage で取り込んでいた Realm のテスト用証明書で、自分の鍵ではない。

## 通信先と SDK

通信先は無し。ソースに URL の直書きも、通信に使う API の呼び出しも無い。通信が無いため、アプリ内の値の分類と BaaS の権限設定の点検は対象外。

| SDK | バージョン | 用途 | 通信 |
| --- | --- | --- | --- |
| realm-swift | 20.0.5 | 旧 Realm データを SwiftData へ一度だけ移行する | 無し。同期機能は使わず、ローカルファイルを開くだけ |
| realm-core | 20.1.5 | realm-swift の依存 | 無し |

## アプリに入っている値

鍵らしい名前、鍵らしい形は、ソースにも Debug シミュレータ用ビルドの成果物（`Info.plist`、実行ファイルの `strings`）にも 0 件。

## 問題が無かった項目

- ATS の例外
- 証明書検証の緩和
- ログへの秘密の出力（`print`、`NSLog`、`os_log`、`Logger` の使用が 0 件）
- URL スキーム、Universal Link、App Intents
- WebView
- 秘密の保存（`UserDefaults` は移行済みフラグ 1 つだけ）
- デバッグ用の抜け道（`#if DEBUG` はサンプル音の追加だけ）
- 秘密ファイルの追跡（現在）
- CI スクリプト（`ci_scripts`、GitHub Actions、fastlane のいずれも無し）
- Dependabot の未対応アラート（0 件）
- デプロイキー（0 件）

## 確かめられなかった項目

| 項目 | 理由 |
| --- | --- |
| 開発と配布に使うアカウントの棚卸し（多要素認証、発行済み API キーの一覧と最終利用日、メンバー、サインイン履歴） | 各サービスのダッシュボードでしか見られない |
| App Store に出した ipa そのもの | 確認したのは Debug シミュレータ用ビルド。リリース用のアーカイブは見ていない |
| App Store の「App のプライバシー」申告と実態の一致 | App Store Connect の申告内容を見ていない |
| Realm の保守状況 | MongoDB が Realm（Atlas Device SDK）の提供を終えたという記憶があるが、今回は確かめていない。移行専用なので、依存ごと外す判断もありうる |
| 他の端末に残っている認証や鍵ファイル | 点検に使った Mac 以外は見ていない |
| GitHub に連携している GitHub App / OAuth アプリ | 確認していない |
