# Privacy Policy

**VideoWallpaper** is an open-source macOS application. This document describes how the app handles your data.

## Data Collection

VideoWallpaper **does not collect any personal data**. No analytics, telemetry, or crash reports are sent anywhere. The app never makes network requests.

## Local Storage

The following data is stored **locally on your Mac only**, using macOS `UserDefaults`:

| Data | Purpose |
|------|---------|
| Selected video file (security-scoped bookmark) | Restore your wallpaper video after reboot |
| Dim level | Remember screen brightness setting |
| Screen target | Remember which displays to use |
| Power saving mode | Remember battery behavior preference |
| Video gravity | Remember video scaling preference |

This data never leaves your device.

## System Capabilities Used

| Capability | How it is used |
|------------|----------------|
| **File access** | Reads the video file you select. Access is granted by you via the file picker or drag & drop and is scoped to that file only. |
| **Desktop wallpaper** | Sets the system wallpaper via `NSWorkspace` when you change the video or dim level. |
| **Power source monitoring** | Reads battery / AC power status via IOKit to support the power saving mode feature. |

## Third-Party SDKs

VideoWallpaper uses **no third-party libraries or SDKs**. It relies exclusively on Apple system frameworks (AVFoundation, AppKit, IOKit, CoreGraphics).

## Disclaimer

This software is provided **"as is"**, without warranty of any kind, express or implied. The author is not liable for any damage to your system, data loss, or any other issue arising from the use of this software. Use at your own risk.

See [LICENSE](LICENSE) for the full MIT License terms.

## Contact

For questions or concerns, please open an issue at
https://github.com/mktbsh/macos-video-wallpaper/issues

---

# プライバシーポリシー

**VideoWallpaper** はオープンソースの macOS アプリケーションです。本ドキュメントはアプリのデータの取り扱いについて説明します。

## データの収集

VideoWallpaper は**個人データを一切収集しません**。アナリティクス、テレメトリ、クラッシュレポートなどの情報はどこにも送信されません。アプリはネットワークへの接続を一切行いません。

## ローカルへの保存

以下のデータのみ、macOS の `UserDefaults` を使用して**お使いの Mac 上にのみ**保存されます。

| データ | 目的 |
|------|------|
| 選択した動画ファイル（セキュリティスコープブックマーク） | 再起動後も壁紙動画を復元するため |
| 明るさ設定 | 画面の明るさ設定を記憶するため |
| 対象ディスプレイ設定 | 使用するディスプレイを記憶するため |
| 省電力モード設定 | バッテリー時の動作設定を記憶するため |
| 動画の表示方法設定 | 動画のスケーリング設定を記憶するため |

これらのデータがデバイスの外に出ることはありません。

## 使用するシステム機能

| 機能 | 用途 |
|------|------|
| **ファイルアクセス** | ユーザーが選択した動画ファイルを読み込みます。アクセス権はファイルピッカーまたはドラッグ＆ドロップで付与され、そのファイルのみに限定されます。 |
| **デスクトップ壁紙** | 動画や明るさ設定の変更時に `NSWorkspace` 経由でシステム壁紙を設定します。 |
| **電源監視** | 省電力モード機能のため、IOKit 経由でバッテリー/AC 電源状態を読み取ります。 |

## サードパーティ SDK

VideoWallpaper は**サードパーティのライブラリや SDK を一切使用しません**。Apple のシステムフレームワーク（AVFoundation、AppKit、IOKit、CoreGraphics）のみを使用しています。

## 免責事項

本ソフトウェアは「現状のまま（as is）」で提供されます。作者は、本ソフトウェアの使用によって生じたいかなる損害（システムへの影響、データ損失、その他の問題を含む）についても責任を負いません。ご使用はご自身の責任でお願いします。

完全な MIT ライセンスの条項については [LICENSE](LICENSE) をご覧ください。

## お問い合わせ

ご質問・ご不明点は Issue を作成してください。
https://github.com/mktbsh/macos-video-wallpaper/issues
