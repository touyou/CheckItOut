# パッドの反応速度ベンチ（タップ → 音が出るまで）

パッドに指が触れてから音が出るまでを、シミュレータで測る土台。
autonomous-perf-loop スキル（touyou/skills、0.4.0）の Step 0 に沿って作った。
周ごとの記録と今の状態は [ledger.md](ledger.md)。

## 何を測っているか

- **点数**: `1000 / 遅れ(ms)`。遅れは、シナリオごとの「指が触れた時刻 → 音が出る時刻（推定）」の中央値を
  重み付きで平均したもの（初回タップ 0.3、同じパッドの連打 0.4、2 つ同時押し 0.3。`expected.json` の `weights`）。
  大きいほど速い。整合性チェックに 1 つでも落ちたら 0 点
- **指が触れた時刻**: `UITouch.timestamp`（タッチイベントの時刻）。ウィンドウに付けた、何も認識しない
  ジェスチャ認識器（`TouchObserver`）で全タッチを記録する
- **音が出る時刻は推定**: `play()` が返った時刻 + `AVAudioSession.outputLatency` + `ioBufferDuration`。
  シミュレータでは実際にスピーカーから出る時刻を取れないため。実機の値ではない
- **内訳**（すべて中央値、ms）
  - `hold_ms`: 触れてから離すまで（UI テストが押す長さ 0.08 秒で決めているので、ほぼ一定）
  - `delivery_ms`: 離したイベントの時刻 → アプリが受け取るまで（シミュレータの配送の遅れを含む）
  - `release_to_play_ms`: 離したイベントの時刻 → `PadPlayerEngine.play` に入るまで（`delivery_ms` を含む）
  - `play_call_ms`: `play` に入ってから `AVAudioPlayer.play()` が返るまで。
    `repeat_play_call_ms`（連打で鳴っている音を止めて鳴らし直す場合）と `first_play_call_ms`（初回）も分けて出す
  - `output_est_ms`: `outputLatency + ioBufferDuration`
- **環境**: 専用のシミュレータ `CheckItOut Perf`（iPhone 17 Pro / iOS 27.2。無ければ bench.sh が作る）。
  **数字は前後の比較にだけ使う**。実機とは配送の遅れも出力の遅れも違う

## シナリオ

| シナリオ | 中身 | 点数に入るか |
|---|---|---|
| `first_tap` | 起動してすぐ、パッド 1〜5 を 1 回ずつ（起動 5 回） | 入る |
| `repeat` | パッド 0（1.3 秒の音）を 10 回続けて押す。2 回目からは鳴っている途中で押し直す | 入る（1 回目は除く） |
| `simultaneous` | パッド 1 と 2 を 2 本指で同時に押す × 5 | 入る（両方の音） |
| `slide_off` | パッド 3 を押したまま外へずらして離す → 鳴らない。続けて普通に押す → 鳴る | 入らない（整合性だけ） |
| `intent` | 起動時に `SoundPlaybackService.playToEnd`（App Intents の再生）でパッド 0 の音を最後まで鳴らし、そのあとパッド 2 を押す | 入らない（整合性だけ） |

## 整合性チェック（`scripts/perf/analyze.py`）

- 押したパッドが、押した回数だけ鳴る。鳴ったパッドの番号と音（ファイル名）が `expected.json` の割り当てと一致する
- `play()` が成功し、再生中で、頭から（位置 0.05 秒以内）鳴っている。連打では毎回頭から鳴り直す
- 2 本指の同時押しで、両方のパッドが鳴る
- **指を離したあとに鳴る**（今の仕様: SwiftUI の `Button`）。ずらして離したら鳴らない
- パッドの再生時のセッションのカテゴリが `.ambient`（消音スイッチで鳴らない振る舞い。シミュレータに消音スイッチは無いので、カテゴリで見る）
- App Intents の再生: 再生中は `.playback`、終わると `.ambient` に戻る。音の長さぶん待ってから返る。そのあともパッドが鳴る
- ログが欠けている（UI テストが落ちた、アプリが落ちた）ときも不合格

## 回し方

```bash
scripts/perf/bench.sh                          # このチェックアウトを 3 回
scripts/perf/bench.sh --cand ../CheckItOut-wt  # 基準と候補を 3 回ずつ交互に
python3 ~/Developer/Private/skills/skills/autonomous-perf-loop/scripts/compare.py \
  --noise-floor 3 \
  --base .perf-runs/results/<dir>/base-{1,2,3}.json \
  --cand .perf-runs/results/<dir>/cand-{1,2,3}.json --touched repeat
```

- 1 回の計測は 2〜3 分（起動 8 回）。結果は `.perf-runs/`（gitignore 済み。終わったら消してよい）
- `compare.py` には `--noise-floor 3`（3% 未満の差はぶれとみなす）を渡す。シミュレータの配送の遅れは
  1 回ごとに数 ms 揺れるため（[ledger.md](ledger.md) の基準値のぶれを参照）
- 採否に使う補助の指標: `play_call_ms` / `repeat_play_call_ms` / `first_play_call_ms` / `release_to_play_ms`。
  `delivery_ms` と `hold_ms` はアプリの外で決まるので**参考**（採用の根拠にしない）。
  `output_est_ms` はセッションの設定（バッファの長さ）を変える案でだけ見る

## 基準の側のコードで測る

`bench.sh` は候補をビルドする前に、次を**基準（このスクリプトがあるチェックアウト、または `--trusted`）のもの**で上書きする。
候補がベンチやチェックを書き換えても効かない。

- `Checkitout/PerfBench/`（アプリ内のプローブ）
- `CheckitoutUITests/TapLatencyBenchTests.swift`（パッドを押す UI テスト）
- `scripts/perf/analyze.py` と `docs/perf/expected.json` は基準の側から直接使う

候補の側に残るフックは、`PadPlayerEngine.play` の中の `TapLatencyProbe.willPlay` / `didPlay` 呼び出し
と、`PadGridView` の `.tapBenchTwoFingerTarget()`、起動時の `installIfNeeded` / `recordReady` / `runIntentCheckIfNeeded`
の呼び出しだけ。時刻はプローブが自分で取り、player の状態（URL・再生中か・位置・音量・速さ・パン）もプローブが読む。

候補をビルドする前に、bench.sh は次の**関門**を通す。1 つでも外れたら計測しない。

- `Checkitout.xcodeproj`（ビルド設定・スキーム・ファイルの所属）が基準と同じ。
  FileSystemSynchronized グループの除外に足すと、上書きしたプローブをビルドから外せてしまうため
- `Checkitout/AudioSample` の音源が基準と同じ
- アプリ側でプローブに触れる行（`TapLatencyProbe` / `PERF_TAP_BENCH` などを含む行）が基準と同じ
- シンボリックリンクが無い

意図してこれらを変える周（再生の仕組みを AVAudioEngine に変えてフックの形が変わる、など）は、人が差分を見てから
`PERF_ALLOW_PROJECT_DIFF=1` / `PERF_ALLOW_HOOK_DIFF=1` で通す。そのときは**レビューで次を確かめる**:

- `willPlay` は鳴らし始める処理の**前**、`didPlay` は実際に音を鳴らし始める呼び出しの**直後**にある。
  鳴らし始めるのを遅らせて（非同期・タイマー）フックだけ先に呼んでいない
- フックの呼び出しを `#if DEBUG` の外に出していない

## 計測用のコードを Release に残さない

`scripts/perf/release_check.sh` で Release をビルドし、バイナリに `TapLatencyProbe` などの文字列が無いことを確かめる（周ごとに回す）。

- `TapLatencyProbe.swift` はファイル全体が `#if DEBUG`。アプリ側の呼び出しもすべて `#if DEBUG` の中
- 有効になるのは Debug ビルドを `-perf-tap-bench` 付きで起動したときだけ。そのときは SwiftData をメモリだけで使い、
  ユーザーのデータを読み書きしない（`expected.json` の割り当てで 16 パッドを埋める）
- `TapLatencyBenchTests` は `PERF_TAP_BENCH_OUT` が無いと skip する（ふつうの `xcodebuild test` では走らない）

## 期待値を変えるとき

- `expected.json` は、振る舞いを意図して変えるときだけ変える（例: ユーザーが決めた仕様の変更）
- 「指を離したあとに鳴る」のチェックは analyze.py の `measure` にある。触れた瞬間に鳴らす設定を足すときは、
  設定ごとに期待値を分ける（オフ: 離したときに鳴る・ずらすと鳴らない。オン: 触れたときに鳴る）
- 期待値やチェックを変えたら、別のエージェントに「だませないか」を 1 回レビューさせる（スキルの bench-harness.md 7 節）

## わかっている穴

- 音が本当にスピーカーから出たかは見ていない。プローブが記録するのは `AVAudioPlayer` の状態（`isPlaying`、位置、URL、音量）と、0.1 秒後もまだ鳴っているか
- ログはアプリの中から書くので、候補のアプリがログを書き換えることは原理的に防げない。関門（フックの行）と差分のレビューで補う
- 連打で古い player を鳴らしたまま新しい player を作る（音が重なる）変更は、プローブからは見えない。差分のレビューで見る
- 計測は Debug ビルド。再生はほぼシステムのフレームワークの中なので、Release との差は小さいと見ている
- 点数は p50 だけ。p95 はシナリオごとの補助の指標として `compare.py` に出る
- 2 本指の同時押しは、XCUITest の `tap(withNumberOfTaps:numberOfTouches: 2)` で、パッド 1 と 2 の境目に置いた
  見えない要素（`tapBenchTwoFingerTarget`、ベンチの起動時だけ）を叩いている。指の間隔は要素の幅で決まる（幅の約 0.9 倍）。
  画面の大きさや向きを変えると外れるので、シミュレータは iPhone 17 Pro の縦向きに固定している
- シミュレータに消音スイッチは無い。`.ambient` のカテゴリで代わりに見ている
- App Intents は `PlaySoundIntent.perform` を直接呼べない（`@Dependency` がランタイムの外では止まる）ので、
  その中身の `SoundPlaybackService.playToEnd` を呼んでいる。インテントの解決（`SoundEntity`）は見ていない
