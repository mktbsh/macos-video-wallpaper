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

## cp -R はディレクトリをマージする（上書きしない）

**症状:** `make run` で `/Applications` 配下のアプリが更新されない。
**原因:** `cp -R src dst` は既存の `dst` にマージするため、古いファイルが残る。
**対策:** `cp -R` の前に `rm -rf` で削除してから上書きする。

---

## @Suite(.serialized) で UserDefaults の競合を防ぐ

**症状:** UserDefaults を読み書きするテストが並列実行時に不安定になる（フレーキー）。
**原因:** Swift Testing はデフォルトで並列実行するため、複数テストが同じキーを同時に読み書きする。
**対策:** UserDefaults を触るテストスイートには `@Suite(.serialized)` を付ける。

---

## CGDisplayIsBuiltin の戻り値は Bool ではなく boolean_t (Int32)

**症状:** `CGDisplayIsBuiltin(id)` を `Bool` として直接使うとコンパイルエラー。
**対策:** `CGDisplayIsBuiltin(id) != 0` / `== 0` で比較する。

---
