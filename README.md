# flutter_geoloc4

GPS・Wi-Fi を使って位置情報を自動記録し、地図上で可視化する Flutter 製のジオロケーションノートアプリです。
バックグラウンドでの位置情報収集、Wi-Fi SSID との紐付け記録、お寺などの訪問スポット管理など、行動ログを多角的に管理できます。

---

## 主な機能

### 位置情報の記録・管理
- **GPS位置情報の自動記録** — 緯度・経度・日時をローカル DB (Isar) に保存
- **バックグラウンド収集** — アプリが非アクティブな状態でも位置情報を継続収集
- **日次・履歴表示** — 日ごとの位置情報ログをリスト表示
- **ピックアップ表示** — 任意の記録をピックアップしてハイライト表示

### Wi-Fi位置情報（Android連携）
- **Wi-Fi SSID × 位置情報の記録** — 接続中の Wi-Fi SSID と緯度・経度・日時を紐付けて記録
- **Kotlin Room DB との連携** — Android ネイティブ側 (Kotlin / Room) が収集したデータを [Pigeon](https://pub.dev/packages/pigeon) 経由で Flutter へ取り込み
- **収集の開始・停止・削除** — Flutter UI からネイティブの収集処理を制御

### 地図表示
- **OpenStreetMap ベースの地図** — `flutter_map` を使用した軽量マップ表示
- **記録した位置をプロット** — GPS / Wi-Fi 記録を地図上にマーカー表示
- **東京市区町村データの重ね表示** — JSON ベースの市区町村データをマップに重ねて表示

### お寺・訪問スポット管理
- **お寺一覧・位置情報** — お寺の座標データをマップ上に表示
- **訪問日の記録** — 訪問済みのお寺と訪問日を管理
- **写真表示** — お寺の写真をアプリ内で閲覧

### その他
- **逆ジオコーディング** — 緯度・経度から住所情報を取得
- **祝日データ連携** — 日付表示に祝日情報を反映
- **歩行記録** — 歩行ログモデルによる移動記録管理

---

## 技術スタック

| カテゴリ | 技術 |
|---|---|
| フレームワーク | [Flutter](https://flutter.dev/) (Dart SDK ^3.5.0) |
| 状態管理 | [Riverpod](https://riverpod.dev/) (hooks_riverpod / riverpod_annotation) |
| ローカルDB | [Isar](https://isar.dev/) v3 |
| 地図 | [flutter_map](https://pub.dev/packages/flutter_map) + [latlong2](https://pub.dev/packages/latlong2) (OpenStreetMap) |
| 位置情報 | [location](https://pub.dev/packages/location) / [permission_handler](https://pub.dev/packages/permission_handler) |
| バックグラウンド | [background_task](https://pub.dev/packages/background_task) |
| ネイティブ通信 | [Pigeon](https://pub.dev/packages/pigeon) (Flutter ↔ Kotlin) |
| コード生成 | freezed / json_serializable / riverpod_generator / build_runner |
| 画像キャッシュ | [cached_network_image](https://pub.dev/packages/cached_network_image) / [flutter_cache_manager](https://pub.dev/packages/flutter_cache_manager) |
| フォント | KiwiMaru / Google Fonts |

---

## 対応プラットフォーム

- Android（Wi-Fi位置情報収集はAndroidのみ対応）
- iOS
- macOS
- Windows
- Linux

---

## データモデル (Isar Collections)

| コレクション | 概要 |
|---|---|
| `Geoloc` | GPS位置情報（日付・時刻・緯度・経度） |
| `KotlinRoomData` | Kotlin Room から同期したWi-Fi位置情報（SSID付き） |
| `Config` | アプリ設定 |

---

## Pigeon インターフェース

Android ネイティブ側との通信は Pigeon で型安全に定義されています。

```dart
// pigeons/wifi_location.dart
@HostApi()
abstract class WifiLocationApi {
  List<WifiLocation> getWifiLocations();   // 記録済みデータを取得
  void deleteAllWifiLocations();           // 全データを削除
  void startLocationCollection();          // 収集を開始
  bool isCollecting();                     // 収集中かどうか
}
```

---

## プロジェクト構成

```
lib/
├── main.dart                  # エントリーポイント・バックグラウンドハンドラ設定
├── collections/               # Isarコレクション定義
│   ├── geoloc.dart            # GPS位置情報
│   ├── kotlin_room_data.dart  # Wi-Fi位置情報（Kotlin連携）
│   └── config.dart            # 設定
├── controllers/               # Riverpodコントローラー
├── models/                    # データモデル（Freezed）
│   ├── geoloc_model.dart
│   ├── temple_model.dart      # お寺情報
│   ├── municipal_model.dart   # 市区町村情報
│   ├── lat_lng_address.dart   # 逆ジオコーディング結果
│   ├── holiday.dart           # 祝日データ
│   └── walk_record_model.dart # 歩行記録
├── data/http/                 # HTTP通信層
├── ripository/                # データアクセス層
├── pigeon/                    # Pigeon生成コード
├── screens/
│   ├── home_screen.dart       # ホーム画面
│   ├── components/            # ダイアログ・アラートコンポーネント
│   └── parts/                 # 共通UIパーツ
├── mixin/                     # Mixinクラス
├── enums/                     # 列挙型
├── extensions/                # 拡張メソッド
└── utilities/                 # ユーティリティ
pigeons/
└── wifi_location.dart         # PigeonのAPI定義
assets/
├── images/                    # 画像リソース
└── json/                      # 市区町村データ等のJSONファイル
```

---

## セットアップ

### 前提条件

- Flutter SDK (Dart ^3.5.0)
- Android Studio / Xcode（ネイティブビルド用）

### インストール手順

```bash
# リポジトリをクローン
git clone https://github.com/toyotarou/flutter_geoloc4.git
cd flutter_geoloc4

# 依存パッケージをインストール
flutter pub get

# コード生成（Isar / Riverpod / Freezed / Pigeon）
dart run build_runner build --delete-conflicting-outputs

# アプリを実行
flutter run
```

### パーミッション

Android・iOS それぞれで以下の権限が必要です。

| 権限 | 用途 |
|---|---|
| `ACCESS_FINE_LOCATION` | GPS位置情報の取得 |
| `ACCESS_BACKGROUND_LOCATION` | バックグラウンド位置情報の取得 |
| `ACCESS_WIFI_STATE` | Wi-Fi SSID の取得 |

---

## ライセンス

このプロジェクトはプライベートリポジトリです (`publish_to: 'none'`)。
