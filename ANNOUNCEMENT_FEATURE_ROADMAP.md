# お知らせ機能 開発ロードマップ

## 概要
ホーム画面上部にお知らせボタンを設置し、ユーザーに更新情報やメンテナンス情報などを伝えるための機能を開発する。

---

## フェーズ1: 基本的な表示機能の実装

### 目的
まずは、お知らせ情報をアプリ内で表示するための基本的な仕組みを構築する。

### タスクリスト

- [x] **1. データソースの準備**
    - [x] `assets/announcements.json` ファイルを作成し、お知らせのダミーデータ（ID, タイトル, 本文, 作成日時など）を記述する。
    - [x] `pubspec.yaml` に上記アセットへのパスを追加する。

- [x] **2. データモデルの作成**
    - [x] `announcements.json` の構造に対応する `Announcement` モデルクラスを `lib/models/announcement.dart` に作成する。

- [x] **3. データ読み込みロジックの実装**
    - [x] JSONファイルを読み込み、`Announcement` オブジェクトのリストに変換するサービスクラス `AnnouncementService` を `lib/services/announcement_service.dart` に作成する。

- [x] **4. UIの実装**
    - [x] **お知らせ一覧画面 (`AnnouncementsScreen`)**
        - [x] `lib/screens/announcements_screen.dart` を作成する。
        - [x] `AnnouncementService` を使ってデータを読み込み、お知らせのタイトルを `ListView` で表示する。
        - [x] 各項目をタップすると、お知らせ詳細画面に遷移する。
    - [x] **お知らせ詳細画面 (`AnnouncementDetailScreen`)**
        - [x] `lib/screens/announcement_detail_screen.dart` を作成する。
        - [x] 選択されたお知らせのタイトルと本文を表示する。
    - [x] **ホーム画面へのボタン設置**
        - [x] `lib/screens/home_screen.dart` の `AppBar` に `IconButton` (例: `Icons.info_outline`) を追加する。
        - [x] ボタンをタップすると `AnnouncementsScreen` に遷移する処理を実装する。

---

## フェーズ2: 未読管理機能

### 目的
ユーザーが新しいお知らせを見逃さないように、未読状態を管理し、通知する仕組みを導入する。

### タスクリスト

- [x] **1. 未読状態の管理**
    - [x] `SharedPreferences` を利用して、ユーザーが最後に確認したお知らせのIDまたは日時を保存する。

- [x] **2. 未読バッジの表示**
    - [x] アプリ起動時に `AnnouncementService` でお知らせデータを読み込み、保存されたIDと比較して未読のお知らせがあるか判定する。
    - [x] 未読がある場合、`HomeScreen` のお知らせアイコンにバッジ（赤い点など）を表示する。
    - [x] お知らせ一覧画面を開いたタイミングで、未読状態をリセット（最後に確認したIDを更新）する。

---

## フェーズ3: 外部データソースへの移行 (オプション)

### 目的
アプリのアップデートなしで、動的にお知らせを更新できるようにする。

### タスクリスト

- [ ] **1. バックエンドの準備**
    - [ ] Supabaseに `announcements` テーブルを作成する。

- [ ] **2. データ取得ロジックの変更**
    - [ ] `AnnouncementService` を修正し、ローカルのJSONファイルではなく、Supabaseからデータを取得するように変更する。

---

## 開発ログ

- **2025-10-11:**
    - お知らせ機能のロードマップを作成。
    - お知らせのダミーデータソースとして `assets/announcements.json` を作成。
    - `pubspec.yaml` にアセットパスを登録。
    - お知らせのデータモデル `Announcement` を作成。
    - お知らせデータを読み込む `AnnouncementService` を作成。
    - お知らせ一覧画面・詳細画面を実装。
    - ホーム画面にお知らせ画面への導線を設置。
    - お知らせの未読管理機能（バッジ表示）を実装。
