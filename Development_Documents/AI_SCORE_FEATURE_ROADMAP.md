# AI総合得点ランキング機能 実装ロードマップ

## 概要
既存の睡眠時間ランキングに加え、AIによる睡眠分析の「総合得点」に基づいた新しい全国ランキング機能を実装する。これにより、ユーザーは睡眠の「量」だけでなく「質」も他のユーザーと競い合えるようになり、より深いエンゲージメントを促進する。

---

## フェーズ1: バックエンド基盤の構築 (Supabase)

### タスク1.1: データベース設計とテーブル作成
- **目的:** AIの総合得点を永続化し、ランキング集計の元データとする。
- **作業内容:**
  1. Supabaseプロジェクト内に、新しいテーブル `ai_score_ranking` を作成する。
  2. **テーブルスキーマ:**
     - `id`: `bigint` (Primary Key)
     - `created_at`: `timestamp with time zone` (デフォルト: `now()`)
     - `user_id`: `uuid` (Foreign Key to `profiles.id`, On Delete Cascade)
     - `score`: `integer` (AIによる総合得点, 0-100)
     - `recorded_date`: `date` (スコアが記録された日付)
  3. **インデックス作成:** `user_id` と `recorded_date` の組み合わせ、および `score` カラムにインデックスを作成し、パフォーマンスを最適化する。
  4. **RLS (Row Level Security) ポリシー設定:**
     - ユーザーは自身のスコアデータのみ `SELECT`, `INSERT`, `UPDATE`, `DELETE` できるように設定する。
     - ランキング取得のための読み取り専用アクセスを許可するポリシーを別途定義する。

### タスク1.2: ランキング取得用APIの作成
- **目的:** アプリケーションから安全かつ効率的にランキングデータを取得するためのAPIを準備する。
- **作業内容:**
  1. Supabaseの `Database Functions` を使用して、`get_ai_score_ranking` という名前のRPC (Remote Procedure Call) 関数を作成する。
  2. **関数の仕様:**
     - `user_id` をキーとして、最新のスコアのみを取得するように重複を排除する (`DISTINCT ON (user_id)` を利用)。
     - `profiles` テーブルとJOINし、ユーザー名 (`username`) を取得する。
     - `score` の降順で上位100件を返す。
     - 返り値は `user_id`, `username`, `score` を含むオブジェクトの配列とする。

---

## フェーズ2: アプリケーションロジックの改修 (Flutter)

### タスク2.1: AIスコアの保存処理実装
- **目的:** AI分析完了時に、算出された総合得点をSupabaseに保存する。
- **作業内容:**
  1. `lib/services/analysis_service.dart` を修正する。
  2. `gemini.generateContent()` でAIの応答から総合得点をパースした後、Supabaseクライアント (`Supabase.instance.client`) を呼び出す処理を追加する。
  3. `ai_score_ranking` テーブルに、現在のユーザーID (`user_id`)、総合得点 (`score`)、今日の日付 (`recorded_date`) をINSERTする。
     - 既に同日にスコアが記録されている場合は、UPDATEで上書きするロジックを実装する (`upsert`)。

### タスク2.2: ランキング取得サービスの拡張
- **目的:** 新しく作成したSupabaseのRPC関数を呼び出し、AIスコアランキングをアプリ内に取り込む。
- **作業内容:**
  1. `lib/services/supabase_ranking_service.dart` を修正する。
  2. `getAiScoreRanking` という非同期関数を新たに追加する。
  3. この関数内で、Supabaseクライアントの `rpc()` メソッドを使い、フェーズ1.2で作成した `get_ai_score_ranking` を呼び出す。
  4. 取得したデータを、アプリケーション内で利用しやすいように型付けされたモデルオブジェクトのリストに変換する。
  5. エラーハンドリングを実装する。

---

## フェーズ3: UI/UXの構築 (Flutter)

### タスク3.1: ランキング画面のUI改修
- **目的:** 既存のランキング画面で、「睡眠時間」と「AIスコア」の2つのランキングを切り替えられるようにする。
- **作業内容:**
  1. `lib/screens/ranking_screen.dart` を修正する。
  2. `DefaultTabController` と `TabBar` ウィジェットを導入し、画面上部に「睡眠時間」「AIスコア」の2つのタブを設置する。
  3. `TabBarView` を使用し、各タブに対応するランキング表示エリアを構築する。

### タスク3.2: AIスコアランキング表示ウィジェットの実装
- **目的:** AIスコアランキングのデータを画面にリスト表示する。
- **作業内容:**
  1. `ranking_screen.dart` 内、または新しいウィジェットファイルとして、`AiScoreRankingView` を作成する。
  2. `FutureBuilder` または `StreamBuilder` を使用し、`supabase_ranking_service.dart` の `getAiScoreRanking` 関数を呼び出す。
  3. 取得したランキングデータを `ListView.builder` で表示する。
     - 各リストアイテムには、順位、ユーザー名、AIスコアを表示する。
     - 既存の睡眠時間ランキングのデザインと統一感を持たせる。
  4. データのロード中には `CircularProgressIndicator` を、エラー発生時にはエラーメッセージを表示する処理を実装する。

---

## フェーズ4: テストとドキュメント

### タスク4.1: 動作確認とテスト
- **目的:** 実装した機能が仕様通りに動作することを保証する。
- **作業内容:**
  1. AI分析を実行し、スコアがSupabaseに正しく保存されることを確認する。
  2. ランキング画面でAIスコアタブに切り替え、ランキングが正しく表示されることを確認する。
  3. 複数のテストユーザーでスコアを登録し、順位が正しく変動することを確認する。
  4. エラーケース（通信失敗時など）のテストを行う。

### タスク4.2: ドキュメントの更新
- **目的:** プロジェクトのドキュメントを最新の状態に保つ。
- **作業内容:**
  1. `README.md` の「主な機能」セクションに、「AI総合得点ランキング」の項目を追加する。
