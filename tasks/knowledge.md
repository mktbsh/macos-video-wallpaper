# Knowledge - 過去の失敗と学び

## 記録ルール

- バグを解決したら、ここにパターンと対策を追記する
- 設計上の判断ミスや整合性の注意点も記録する
- 同じ失敗を繰り返さないための知見をまとめる

---

## XcodeGen の entitlements は `project.yml` を source of truth にする

**症状:** `Sources/VideoWallpaper.entitlements` を直接編集しても `xcodegen generate` 後に内容が消える、または build 中に `Entitlements file ... was modified during the build` で失敗する。
**原因:** このリポジトリでは entitlements が `project.yml` から生成される。さらに `ENABLE_APP_SANDBOX = YES` の build setting を併用すると、Xcode 側の自動生成と hand-authored entitlements が衝突する。
**対策:** sandbox 関連キーは `project.yml` の `entitlements.properties` に定義し、`Sources/VideoWallpaper.entitlements` は生成物として扱う。`ENABLE_APP_SANDBOX` は追加しない。

---

## Hardened Runtime の有効確認は Release build の `codesign` で行う

**症状:** test / Debug build で `Disabling hardened runtime with ad-hoc codesigning.` と出て、設定が効いていないように見える。
**原因:** ad-hoc 署名の test / Debug build では hardened runtime が無効化されるが、`ENABLE_HARDENED_RUNTIME = YES` の Release build では `codesign -o runtime` が有効になる。
**対策:** 判定は `xcodebuild build -configuration Release` 後に `codesign -dv --verbose=4 <app>` を見て `flags=...runtime` が付いていることを確認する。

---

## `private extension` 内でも private nested type を受ける関数は `private` 明示が必要

**症状:** CI / Release build で `method must be declared private because its parameter uses a private type` が出てコンパイル失敗する。
**原因:** `private extension Foo` 内のメソッドは、明示しないと `private` nested type を引数に取れない可視性として扱われることがある。Swift 6 / Xcode 16.4 では nested private type を受ける helper に `private` を明示しないと落ちる。
**対策:** `private struct Context` などを引数に取る helper は、`private extension` の中でも `private func ...` を明示する。必要がない限り nested type 側の可視性は広げない。

---

## NSWindow.isReleasedWhenClosed = false が必須

**症状:** 対象画面を切り替えると `invalidate()` → `window.close()` でクラッシュ。
**原因:** `NSWindow` のデフォルトは `isReleasedWhenClosed = true`。ARC が管理しているのに AppKit が二重解放する。
**対策:** `WallpaperWindowController.init` で `window.isReleasedWhenClosed = false` を設定する。

---

## xcodegen generate を build の前に必ず実行する

**症状:** 新しい `.swift` ファイルを追加してもビルドに含まれず、シンボルが見つからないエラーになる。
**原因:** `project.pbxproj` が古いままで新ファイルを認識していない。
**対策:** Makefile の `build` ターゲット冒頭で `xcodegen generate` を実行する。

---

## XcodeGen リポジトリで SwiftPM command plugin を使うなら専用 Package.swift を切る

**症状:** `swift package --disable-sandbox lefthook ...` が `Could not find Package.swift` で失敗する。
**原因:** XcodeGen ベースのアプリは Swift Package の manifest を持たないため、SwiftPM command plugin を解決できない。
**対策:** ルートに開発ツール専用の `Package.swift` を追加し、ダミー target は `Sources/` の外に置く。`Sources/` 配下に置くと XcodeGen のアプリ target に巻き込まれる。

---

## SwiftLint を SwiftPM plugin で動かすなら .build を lint 対象から外す

**症状:** `swift package plugin swiftlint ...` が `.build/checkouts` 配下の依存パッケージまで lint して失敗する。
**原因:** SwiftPM plugin 実行時に依存 checkout が `.build` に展開され、SwiftLint の走査対象に含まれる。
**対策:** `.swiftlint.yml` の `excluded` に `.build` と `.swiftpm` を追加する。hook は `swift package plugin --allow-writing-to-package-directory swiftlint --strict` で呼ぶ。

---

## Lefthook を SwiftPM plugin で起動した hook から nested SwiftPM は呼ばない

**症状:** `swift package --disable-sandbox lefthook run pre-commit` の中でさらに `swift package plugin swiftlint ...` を呼ぶと固まる。
**原因:** 外側の `swift-package` が `.build.lock` を保持したまま、内側の `swift-package` が同じ lock を取りにいってデッドロックする。
**対策:** hook からは nested `swift package` を呼ばず、事前に取得した SwiftLint artifact を直接実行する。artifact の bootstrap は `swift package plugin --list >/dev/null` で行う。

---

## preBuildScript の outputFiles 宣言はしない

**症状:** ビルド日時を生成するスクリプトが初回しか走らず、`BuildInfo.swift` が更新されない。
**原因:** `outputFiles` を宣言すると Xcode がファイルの存在を確認し、存在していればスクリプトをスキップする。
**対策:** `outputFiles` を省略する。スクリプトは毎ビルド無条件に実行される。

---

## preBuildScript 内の heredoc はインデントに注意

**症状:** YAML 内の heredoc でインデントをつけると、生成される Swift ファイルに余分なスペースが混入してコンパイルエラーになる。
**対策:** `printf` を使う。

```yaml
script: |
  printf 'enum BuildInfo {\n    static let version = "%s"\n}\n' "$VERSION" > "${SRCROOT}/Sources/BuildInfo.swift"
```

---

## .app のインストールは rm -rf してから cp -R する

**症状:** `make run` で `/Applications` 配下のアプリが更新されない。
**原因:** `cp -R src dst` は既存の `dst` にマージするため、バイナリが差し替わらない。`cp -Rf` も同様に失敗する。
**対策:** `rm -rf $(INSTALL_DIR)/$(APP_NAME)` で一度削除してから `cp -R` する。対象パスは変数で固定されているため安全。

---

## @Suite(.serialized) で UserDefaults の競合を防ぐ

**症状:** UserDefaults を読み書きするテストが並列実行時に不安定になる（フレーキー）。
**原因:** Swift Testing はデフォルトで並列実行するため、複数テストが同じキーを同時に読み書きする。
**対策:** UserDefaults を触るテストスイートには `@Suite(.serialized)` を付ける。

---

## playlist persistence 系テストは suite-scoped defaults と明示 cleanup を使う

**症状:** migration / fallback 系のテストが `UserDefaults.standard` を使うと、前後のテストや再実行の残留状態に影響される。
**原因:** 同じグローバル defaults を共有すると、bookmark 由来の state がテスト境界をまたいで残る。
**対策:** `UserDefaults(suiteName:)` を毎テストで切り、`removePersistentDomain(forName:)` で開始時と終了時の両方を掃除する。migration 系は 2 回目の `load()` でも legacy に戻らないことを確認すると one-time fallback を表現しやすい。

---

## bookmark から復元した file URL は path から組み直す

**症状:** Security-scoped bookmark を解決すると、同じファイルでも `file:///private/var/...` と `file:///var/...` の差で URL 比較が落ちることがある。
**原因:** bookmark 解決結果の内部表現をそのまま持ち回ると、`URL` の見た目と `==` 判定が元の入力とずれる。
**対策:** 永続化境界で `url.path` を取り出して新しい `URL(fileURLWithPath:)` を作り直す。`/private/` プレフィックスが付く環境でも、アプリ内で使う URL を一貫させられる。

---

## Swift Testing の `#require` に mutating call を直接渡さない

**症状:** `#require(session.beginPlayback(using: &store))` のように mutating method を直接渡すと、macro 展開後に `'$0' is immutable` でコンパイルエラーになる。
**原因:** `#require` が式をそのまま評価するのではなく、内部の一時束縛へ展開するため、`inout` を含む mutating call と相性が悪い。
**対策:** mutating call の結果は先にローカル変数へ代入し、その変数を `#require(...)` / `#expect(...)` に渡す。

---

## CGDisplayIsBuiltin の戻り値は Bool ではなく boolean_t (Int32)

**症状:** `CGDisplayIsBuiltin(id)` を `Bool` として直接使うとコンパイルエラー。
**対策:** `CGDisplayIsBuiltin(id) != 0` / `== 0` で比較する。

---

## 設定値 enum パターン

`DimLevel` / `PowerSavingMode` / `VideoGravity` はすべて同じ構造。新しい設定を追加するときはこのパターンに従う。

```swift
enum Xxx: String, CaseIterable {
    case foo = "foo"

    var label: String { ... }          // メニュー表示テキスト
    static var saved: Xxx { ... }      // UserDefaults から復元
    func save() { ... }                // UserDefaults に保存
}
```

---

## ローカライズのテストは locale 専用 bundle を明示的に引く

**症状:** `Bundle.localizations` や現在ロケールの fallback に頼るテストだと、`ja` リソース不足やキー未解決を見逃しやすい。
**原因:** hosted unit test では `Bundle(for: AppDelegate.self)` が実際の app bundle になるが、`bundle.localizations` の値と `xx.lproj` 実体、fallback 挙動は一致しないことがある。
**対策:** ローカライズ検証は `Bundle(for: AppDelegate.self)` を起点に `en.lproj` / `ja.lproj` の sub-bundle を明示的に解決し、anchor string を exact match で確認する。UI の label テストは、その locale で bundle が返す文字列と比較する。

---

## bookmark resolver で security-scoped access を開始しない

**症状:** 起動時や画面再構成で bookmark を解決するたびに `startAccessingSecurityScopedResource()` が積み上がり、長時間稼働で解放漏れを起こす。
**原因:** bookmark 解決関数が URL 解決と access 開始の両方を担っていた。
**対策:** resolver は URL を返すだけにし、`startAccessing...` / `stopAccessing...` は再生セッション所有者で一元管理する。

---

## プレイリスト更新は AppDelegate / PlaylistStore 経由に一本化する

**症状:** drag & drop やメニューが UI 側で直接 `load()` すると、playlist state と現在再生 state が分岐しやすい。
**原因:** 再生・メニュー・エディタがそれぞれ部分的に状態を持つと、source of truth が複数になる。
**対策:** 変更は `PlaylistStore` を更新してから `AppDelegate` 経由で再生と UI を再適用する。

---

## 同じ再生 target への `load()` は no-op にする

**症状:** 画面再構成や occlusion 復帰で同じ URL を再読み込みすると、`AVPlayerItem` / `AVPlayerLooper` が無駄に再生成される。
**原因:** `load(videoURL:timeRange:)` が `URL + timeRange` の同一性を見ていなかった。
**対策:** 再生 target が同一なら既存 looper を再利用し、必要なら `play()` だけ呼ぶ。

---

## screen 再構成では active playback token を再発行しない

**症状:** `didChangeScreenParametersNotification` のたびに `PlaybackSession.beginPlayback()` を呼ぶと、同じ playlist item でも新しい token が発行され、surviving controller が reload / orderFront / orderOut を再実行してしまう。
**原因:** 画面構成の更新と playlist の再生開始を同じ経路で扱っていた。
**対策:** screen 再構成では current token を維持し、新規 controller のみ current playback に同期する。playlist 変更時だけ全 controller に対して `beginPlayback()` を行う。

---

## `NSMenu` は固定 item を保持して差分更新する

**症状:** summary 更新ごとに `buildMenu()` で全項目を作り直すと UI churn が増え、項目参照を使うテストも不安定になる。
**原因:** 軽いタイトル変更までメニュー全 rebuild に乗せていた。
**対策:** `NSMenuItem` を一度生成して保持し、`title` / `state` / `isEnabled` / `isHidden` だけ更新する。

---

## 再生完了ベースのローテーション token は AppDelegate が持つ

**症状:** 複数画面のどれか 1 つから遅れて届いた完了通知で、すでに次の動画へ進んだ後の playlist state がもう一度 advance される。
**原因:** controller ごとの完了通知に session identity がなく、manual 操作後や画面再構成後も古い完了を区別できない。
**対策:** `playlistStore.beginPlayback()` で発行した token を `AppDelegate` が保持し、全 controller に同じ token を配る。完了通知は current token のときだけ消費し、次 item 適用時に必ず新 token を発行する。

---

## `didPlayToEndTime` seam は player ではなく item / target 単位で切る

**症状:** `AVPlayer` だけを fake にしても、`didPlayToEndTime` の stale notification や `clearVideo()` / `invalidate()` の security-scoped cleanup を deterministic に検証できない。
**原因:** 再生完了通知は `AVPlayerItem` 単位で飛び、security-scoped access は `URL.startAccessing...` / `stopAccessing...` の副作用として発生するため、player abstraction だけでは観測点が足りない。
**対策:** seam は `PlaybackObservationTarget` と `SecurityScopedAccessHandle` まで分ける。`didPlayToEndTime` は player ではなく item / target 単位の観測として扱い、controller test では古い target への finish 発火と access handle の `stop()` 呼び出し回数を直接検証する。

---

## `pause` / `resume` / `clear` の冪等化は window visibility state と分けて持つ

**症状:** battery policy や screen lifecycle が同じ `pausePlayback()` / `resumePlayback()` / `clearVideo()` を連続で呼ぶと、`orderFront` / `orderOut` と `play` / `pause` が重複する。
**原因:** これらの操作が「今 visible か」「再生開始待ちか」を見ずに毎回 AppKit と player に触っていた。
**対策:** controller 内で window の ordered state と playback start pending state を持ち、状態が変わらない呼び出しは no-op にする。`clearVideo()` も既に hidden で paused なら何もしない。

---

## security-scoped cleanup を test するなら `start/stop` を handle 化する

**症状:** `clearVideo()` / `invalidate()` で access が正しく解放されたかを test したくても、`URL.startAccessingSecurityScopedResource()` / `stopAccessingSecurityScopedResource()` を直接叩く実装だと stop 回数を観測できない。
**原因:** security-scoped API が URL への副作用として露出しており、開始と終了のライフサイクルをテスト側から保持できない。
**対策:** `startAccessing(...)` は `SecurityScopedAccessHandle` を返し、cleanup はその handle の `stop()` に集約する。fake handle で stop 回数を数えると controller の cleanup を deterministic に検証できる。

---

## 同じ URL と timeRange でも token が変われば playback は再始動する

**症状:** single-item playlist や同一 entry の再適用で、`URL + timeRange` だけを見た same-target no-op が効くと再生が再スタートせず、自動ローテーションが止まる。一方で token 変更のたびに `AVPlayerItem` と security-scoped access まで作り直すと、短いループで CPU / メモリ churn が大きい。
**原因:** playback session の境界と media resource の同一性を同じ判定で扱っていた。
**対策:** `WallpaperWindowController.load(...)` の同一判定には playback token を含める。ただし `URL + timeRange` が同じなら `AVPlayerItem` / access handle は再利用し、completion observation の付け替えと `seek` による再始動だけを行う。

---

## seek completion の MainActor ハンドオフは main-thread 直行を優先する

**症状:** `AVPlayer.seek` の完了後に毎回 `Task { @MainActor in ... }` を作ると、すでに main thread 上で戻ってきた完了通知まで余計な task churn が発生する。
**原因:** completion を常に新規 task に投げていたため、同期的に処理できるケースでも一段余計な hop が入っていた。
**対策:** まず main thread ならその場で `@MainActor` completion を実行し、background callback のときだけ main queue へ handoff する。これで MainActor 正しさを保ちながら、seek completion の hot path を軽くできる。

---

## playlist 永続化で bookmark payload を hot path に載せない

**症状:** 自動ローテーションや playlist editor の入力で CPU / メモリ使用率が上がる。`currentItem` が変わるだけでも main thread で全 item の security-scoped bookmark を作り直していた。
**原因:** `PlaylistPersistence.save(store:)` が playlist metadata と bookmark data を同じ blob に詰めており、`currentItemID` や display name だけの更新でも全 bookmark を再生成・再 JSON encode していた。
**対策:** metadata と bookmark payload を別 key で保存する。bookmark は `item.id + normalized path` が同じ限り再利用し、URL が変わった item だけ再生成する。旧 `playlistState` 形式は load 時に新形式へ migrate する。

---

## playlist editor の start/end は 1 回でコミットする

**症状:** current item を編集中に start と end を別々に保存すると、同じ logical edit で playback-sensitive な更新が複数回走る。
**原因:** editor が start/end を個別 callback で流し、AppDelegate 側でも個別に `updatePlaylistItem()` と `applyCurrentPlaylistItem()` を呼んでいた。
**対策:** editor では time range をひとつの commit として扱い、AppDelegate 側も単一の `onTimeRangeChanged` でまとめて更新する。`useFullVideo` の切り替えは既存の `updateUseFullVideo` に寄せて、余分な nil/nil 更新を流さない。

---

## macOS 固有の注意点

- `NSWindow` は必ず `isReleasedWhenClosed = false` を設定する（デフォルト true は ARC と二重解放を起こす）
- `CGDisplayIsBuiltin()` の戻り値は `boolean_t` (Int32)。`!= 0` / `== 0` で比較する
- バッテリー状態: `IOKit.ps` の `IOPSCopyPowerSourcesInfo` + `kIOPMBatteryPowerKey`
- 電源変化通知: `NSNotification.Name(rawValue: kIOPSNotifyPowerSource)`
- 壁紙非表示: `window.orderOut(nil)` / 再表示: `window.orderFront(nil)`

---

## SwiftLint の trailing_comma ルール

**症状:** CI の Lint ステージで `Collection literals should not have trailing commas (trailing_comma)` エラーが出る。
**原因:** 配列リテラルの最終要素の後にカンマを付けていた（例: `[.foo, .bar,]`）。Swift の標準スタイルでは許容されるが、SwiftLint のデフォルトルール `trailing_comma` は禁止している。
**対策:** 配列リテラル `[...]` の最終要素にはカンマを付けない。関数呼び出しの末尾引数のカンマとは無関係で、配列・辞書リテラルの `]` / `}` 直前のカンマだけが対象。

---
