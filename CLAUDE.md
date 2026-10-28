# CheckItOut

サウンドボードアプリ（SwiftUI + SwiftData）。旧 RealmSwift 版から移行済みで、Realm は起動時の一度きりのデータ移行のためだけに依存として残している（`Checkitout/Services/Migration.swift` 参照）。

## デプロイ / リリース

- **`production` ブランチへのマージでデプロイが走る。** Xcode Cloud がビルドし、TestFlight まで自動で配信される。ワークフローの詳細（トリガー・ビルド番号管理・配布先）は App Store Connect 側で管理されており、リポジトリ内の `Checkitout.xcodeproj/xcshareddata/xcodecloud/manifest.json` はワークフロー ID の参照のみ。
- 通常の開発は `main`（デフォルトブランチ）。リリースしたい変更を `production` にマージすると配信される。
- 手動で `xcodebuild archive` する必要はない。CI に任せる。

## 依存フレームワークの埋め込み（重要な落とし穴）

- `RealmSwift` は**動的フレームワーク**。ターゲットの General → "Frameworks, Libraries, and Embedded Content" で必ず **Embed & Sign** にしておくこと。
- リンクのみ（Do Not Embed）だと Debug のローカル実行は DerivedData 経由で動いてしまうが、archive / TestFlight ビルドでは `dyld: Library not loaded: @rpath/RealmSwift.framework/RealmSwift` で**起動時に即クラッシュする**。v1.1.0 (1) はこれで全端末クラッシュした。
- realm-core は RealmSwift 内に含まれるため、`Realm` を別途 embed する必要はない。

## Xcode プロジェクトファイルの編集

- Xcode を開いた状態で `project.pbxproj` を外部ツールから直接編集しないこと（Xcode がクラッシュする）。ターゲット設定の変更は Xcode の UI で行う。

## 共通の運用ルール（全リポジトリ共通）

- **ブランチ名は役割で付ける**: `feature/` `fix/` `chore/` `docs/` `refactor/` `style/` `release/x.y.z` などの接頭辞 + 短い英語の説明（例: `fix/widget-crash`）。`claude/...` や自動生成の名前は使わない。このリポジトリに別の命名ルールが書いてあればそちらに従う
- **アップデート文は少しあたたかく**: App Store の What's New・Google Play のリリースノート・`.github/devnull/next.md` などの告知は、変更点を並べるだけにしない。冒頭に使う人へのひとこと（その変更で何がうれしくなるか、など）を添えてから変更点を書く。ja / en とも同じ温度にする（Play は 500 字以内）
  - 例:「いつも使ってくださり、ありがとうございます。今回は○○をもっと気持ちよく使えるようにしました。」→ 続けて変更点
- **使い終わったものは消す**: マージ済み・不要になった作業ブランチ（リモートも）、一時ファイル、ビルド成果物、書き出した画像などは作業の最後に削除して容量を空ける。`main` / `production` / 既定ブランチ / 開いている PR のブランチは消さない
