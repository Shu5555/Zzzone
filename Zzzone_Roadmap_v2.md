
# Zzzone v2.0 実装ロードマップ

このドキュメントは、新仕様書に基づき、Zzzoneアプリケーションの次期バージョン開発に向けた詳細な作業計画を定義します。

---

## Phase 1: 基盤整備 (データ層の刷新)

**目標:** 新しいデータ構造に対応するためのモデルとデータベースの基盤を構築する。後続のすべての作業の前提条件となる。

### 1.1. データモデルの更新
- **対象ファイル:** `lib/models/sleep_record.dart`
- **作業内容:**
    - [ ] `id` (int) を `dataId` (String) に変更し、UUIDを格納できるようにする。
    - [ ] `recordDate` (DateTime) フィールドを追加し、記録が属する日付（起床日に基づく）を保持する。
    - [ ] `spec_version` (int) フィールドを追加し、データの仕様バージョンを管理する。
    - [ ] `copyWith`, `toMap`, `fromMap` の各メソッドを、上記の変更に合わせて更新する。`DateTime`はISO8601形式の文字列として永続化する。

### 1.2. データベースヘルパーの改修
- **対象ファイル:** `lib/services/database_helper_mobile.dart`
- **作業内容:**
    - [ ] `_createDb` メソッド内の `CREATE TABLE` 文を新データモデルに合わせて修正する (`dataId TEXT PRIMARY KEY`, `recordDate TEXT NOT NULL`, `spec_version INTEGER NOT NULL DEFAULT 2`)。
    - [ ] `create`, `readAllRecords`, `update`, `delete` 等のCRUDメソッドを、新しい主キー `dataId` と追加フィールドを正しく扱えるように全面的に修正する。

---

## Phase 2: UI/UXの刷新 (記録・編集機能の統合)

**目標:** 分離していた記録・編集画面を単一の画面に統合し、ユーザー体験を向上させる。

### 2.1. 統合UI画面の新規作成
- **対象ファイル:** `lib/screens/sleep_edit_screen.dart` (新規作成)
- **作業内容:**
    - [ ] 新規作成、編集、自動記録後の評価という3つのモードを単一画面で扱えるように設計する。
    - [ ] コンストラクタ引数によってモードを判別するロジックを実装する（例: `SleepRecord` を受け取れば編集モード）。
    - [ ] 日付選択 (`DatePicker`)、時間選択 (`TimePicker`)、評価スライダー、メモ欄など、必要なUIコンポーネントをすべて配置する。

### 2.2. 新UIへの画面遷移の統合
- **対象ファイル:** `lib/screens/home_screen.dart`, `lib/screens/history_screen.dart`
- **作業内容:**
    - [ ] `home_screen.dart`: 「起床する」ボタン押下後の遷移先を、新しい `SleepEditScreen` に変更する。
    - [ ] `history_screen.dart`: 記録タップ時の遷移先を `SleepEditScreen` の編集モードに変更する。
    - [ ] `history_screen.dart`: 「手動で記録を追加」ボタンの遷移先を `SleepEditScreen` の手動記録モードに変更する。

### 2.3. 保存・更新ロジックの実装
- **対象ファイル:** `lib/screens/sleep_edit_screen.dart`
- **作業内容:**
    - [ ] 「保存」ボタン押下時に、モード（新規/編集）に応じて `DatabaseHelper` の `create` または `update` を呼び出す処理を実装する。
    - [ ] 保存前に `recordDate` や `hasAchievedGoal` を計算するロジックを実装する。
    - [ ] 新規作成モードの場合、`recordDate` の重複チェックを行う。

---

## Phase 3: 新機能の実装 (プロフィールとランキング)

**目標:** 新設されるプロフィール機能と、仕様が変更されたランキング機能を実装する。

### 3.1. プロフィール画面の新規作成
- **対象ファイル:** `lib/screens/profile_screen.dart` (新規作成)
- **作業内容:**
    - [ ] ユーザー名、ランキング参加有無、Sleep Coin、userIdなどを表示・編集するためのUIを構築する。
    - [ ] `settings_screen.dart` から既存のランキング関連機能を移植・拡張する。
    - [ ] 値の変更時にのみ「保存」ボタンが有効になる状態管理を実装する。
    - [ ] アプリのメインナビゲーション（AppBarなど）から `ProfileScreen` へ遷移できるようにする。

### 3.2. プロフィール機能のロジック実装
- **対象ファイル:** `lib/services/supabase_ranking_service.dart`, `lib/screens/profile_screen.dart`
- **作業内容:**
    - [ ] `supabase_ranking_service.dart`: ユーザー名などを更新するための `updateUser` メソッドを実装する。
    - [ ] `profile_screen.dart`: 「保存」ボタン押下時に `updateUser` を呼び出し、サーバーとローカル(`SharedPreferences`)の情報を更新する処理を実装する。

### 3.3. ランキング連携機能の修正
- **対象ファイル:** `lib/services/supabase_ranking_service.dart`, `lib/screens/sleep_edit_screen.dart`
- **作業内容:**
    - [ ] `supabase_ranking_service.dart`: `submitRecord` メソッドを、Supabaseの `upsert` を使うように改修する。
    - [ ] `sleep_edit_screen.dart`: 保存処理の中で、記録の `recordDate` が今日の日付であり、かつランキング参加が有効な場合にのみ `submitRecord` を呼び出す条件分岐を追加する。
    - [ ] **【外部依存】**: Supabase側の `sleep_records` テーブルに `data_id` カラムを追加し、`(user_id, date)` にUNIQUE制約を設定する作業が必要。

---

## Phase 4: データ移行処理

**目標:** 既存ユーザーがアプリをアップデートした際に、旧データを新仕様のデータへ安全に移行する。

### 4.1. データベーススキーマのアップグレード対応
- **対象ファイル:** `lib/services/database_helper_mobile.dart`
- **作業内容:**
    - [ ] `sqflite` の `onUpgrade` コールバックを利用して、既存テーブルに `spec_version` などの新しいカラムを追加するマイグレーション処理を実装する。

### 4.2. 移行ロジックの実装
- **対象ファイル:** `main.dart` (または専用の移行サービスクラス)
- **作業内容:**
    - [ ] アプリ起動時に `SharedPreferences` のフラグをチェックし、移行処理が未実行の場合のみ処理を開始する。
    - [ ] `spec_version` が `1` (または `NULL`) のレコードを全て取得する。
    - [ ] レコードごとに、時刻のUTCからJSTへの変換、`recordDate` の決定、`dataId` の生成を行う。
    - [ ] 変換したデータを `spec_version = 2` として更新、または新テーブルに挿入する。
    - [ ] 全ての移行が完了したら、`SharedPreferences` のフラグを更新し、次回以降は実行されないようにする。

---

## Phase 5: 最終調整とクリーンアップ

**目標:** 不要になったコードを削除し、アプリケーション全体の一貫性を保つ。

### 5.1. 不要なファイルの削除
- **対象ファイル:** `lib/screens/post_sleep_input_screen.dart`, `lib/screens/manual_sleep_entry_screen.dart`
- **作業内容:**
    - [ ] `SleepEditScreen` に機能が統合されたため、上記2ファイルをプロジェクトから削除する。

### 5.2. 設定画面の整理
- **対象ファイル:** `lib/screens/settings_screen.dart`
- **作業内容:**
    - [ ] `ProfileScreen` に移動した機能を削除し、それ以外の設定項目（目標時刻設定など）のみが残るように整理する。

### 5.3. 総合テスト
- **作業内容:**
    - [ ] 全ての機能（データ移行、記録の自動/手動/編集、ランキング連携、プロフィール更新）が仕様通りに動作することを網羅的にテストする。
