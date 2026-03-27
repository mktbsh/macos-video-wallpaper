# Knowledge - 過去の失敗と学び

## 記録ルール

- バグを解決したら、ここにパターンと対策を追記する
- 設計上の判断ミスや整合性の注意点も記録する
- 同じ失敗を繰り返さないための知見をまとめる

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

## CGDisplayIsBuiltin の戻り値は Bool ではなく boolean_t (Int32)

**症状:** `CGDisplayIsBuiltin(id)` を `Bool` として直接使うとコンパイルエラー。
**対策:** `CGDisplayIsBuiltin(id) != 0` / `== 0` で比較する。

---

## 設定値 enum パターン

`ScreenTarget` / `DimLevel` / `PowerSavingMode` / `VideoGravity` はすべて同じ構造。新しい設定を追加するときはこのパターンに従う。

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

## `NSMenu` は固定 item を保持して差分更新する

**症状:** summary 更新ごとに `buildMenu()` で全項目を作り直すと UI churn が増え、項目参照を使うテストも不安定になる。
**原因:** 軽いタイトル変更までメニュー全 rebuild に乗せていた。
**対策:** `NSMenuItem` を一度生成して保持し、`title` / `state` / `isEnabled` / `isHidden` だけ更新する。

---

## macOS 固有の注意点

- `NSWindow` は必ず `isReleasedWhenClosed = false` を設定する（デフォルト true は ARC と二重解放を起こす）
- `CGDisplayIsBuiltin()` の戻り値は `boolean_t` (Int32)。`!= 0` / `== 0` で比較する
- バッテリー状態: `IOKit.ps` の `IOPSCopyPowerSourcesInfo` + `kIOPMBatteryPowerKey`
- 電源変化通知: `NSNotification.Name(rawValue: kIOPSNotifyPowerSource)`
- 壁紙非表示: `window.orderOut(nil)` / 再表示: `window.orderFront(nil)`

---
