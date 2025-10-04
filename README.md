# Zzzone - 睡眠管理アプリ

## 概要
Zzzoneは、日々の睡眠を記録・可視化し、さらに全国のユーザーと睡眠時間を競い合うことで、健康的で楽しい睡眠習慣をサポートするモバイルアプリケーションです。記録を忘れた日のために、後から手動で記録を追加する機能も備えています。夜更かしをしても前日分に記録が入るように、一日の区切りを午前4時に設定しています。

## 主な機能

### 1. 睡眠記録と評価
- **自動計測:** 入眠・起床時刻を記録し、睡眠時間を自動計算します。
- **手動での記録追加・編集:** 過去の日付を選択して睡眠時間を手動で入力したり、既存の記録を編集したりできます。
- **統一された入力画面:** 自動記録後、手動追加、編集のすべてが、単一の使いやすい画面で完結します。
- **詳細な睡眠評価:** 
  - 10段階の睡眠スコア
  - 日中の体感パフォーマンス（良い/普通/悪い）
  - 昼間の眠気の有無（後から記録可能）
  - 二度寝の有無
  - 自由なメモ機能
- **目標入眠時刻設定:** 設定した時刻の90分前から30分後までに入眠すると「目標達成」となります。

### 2. 履歴と分析
- **履歴表示:** 週表示・月表示での記録の確認、グラフでの睡眠時間推移の可視化ができます。
- **統計表示:** 目標達成率や、条件別の平均スコアなどを分析・表示します。
- **AIによる睡眠分析:** 5件以上の睡眠記録があると、AI(Google Gemini)があなたの睡眠傾向を分析し、「総評」「良い点」「改善点」を提案します。この分析は、睡眠データが更新された場合にのみ自動で実行され、結果はキャッシュされるため、効率的に最新の分析を確認できます。
- **カレンダー履歴:** 月ごとのカレンダー形式で、各日の睡眠時間を直感的に確認できます。

### 3. ショップ機能とスリープコイン
- **ショップ:** ホーム画面の店舗アイコンからアクセスできます。
- **スリープコイン:** アプリ内通貨です。（今後のアップデートで獲得手段が追加されます）
- **背景色の購入:** スリープコインを使い、ランキング画面で利用できる背景色を購入できます。各色の価格は1,000コインです。

### 4. プロフィールと睡眠時間ランキング
- **プロフィール画面:** ユーザー名、ランキングへの参加設定、そしてランキングで表示される**背景色**などを一元管理できます。
- **背景色の設定:** プロフィール画面では、基本色である「Default」「White」およびショップで購入済みの色の中から、好きな背景を選択して設定できます。
- **全国ランキング:** 全ユーザーのその日の睡眠時間を集計し、ランキング形式で表示します。ユーザー名は20文字までの制限があり、他のユーザーと重複しないものを設定する必要があります。
- **UIの装飾:** 上位3位のユーザーは、ランキング上で特別なカラーリングで強調表示されます。
- **オプトイン方式:** プライバシーに配慮し、ユーザーが自らの意思でランキングに参加するかを選択できます。
- **最新記録の反映:** ランキングには、各ユーザーがその日に記録した最新の睡眠記録のみが反映されます。

### 5. 設定とデータ管理
- **目標入眠時刻:** 睡眠目標達成の基準となる時刻を自由に設定できます。
- **データ管理:** アプリ内に保存されているすべての睡眠記録の削除や、サーバー上の全ランキングデータの削除が可能です。

### 6. Web版での計測持続
- Flutter for Webで実行中、ブラウザのタブを閉じたり再起動したりしても、進行中の睡眠計測が失われることはありません。再訪問すると、計測が継続された状態でアプリが復元します。

## アーキテクチャ (v2)

### クライアントサイド
- **フレームワーク:** Flutter (Dart)
- **データモデル:**
  - **タイムゾーン:** JST（日本標準時）を基準として日時を扱います。
  - **ID:** 記録の主キーとして、`int`の連番に代わり、`String`型のUUID (`dataId`) を採用しました。
  - **記録日:** どの日の睡眠記録かを明確にするため、起床時刻を基準とした `recordDate` を新たに導入しました。
- **ローカルデータベース:** SQLite (`sqflite`) / Web向けインメモリ + `shared_preferences`
- **状態管理/設定保存:** `shared_preferences`
- **グラフ描画:** `fl_chart`
- **カレンダーUI:** `table_calendar`

### バックエンド
- **ランキング・ショップ機能:** Supabase (PostgreSQL)
- **AI分析機能:** Google Gemini API

### データ移行
- v1からv2へのアップデート時に、既存のユーザーデータ（ローカルDB/Webストレージ）は、新しいデータモデルへ自動的に変換されます。

## 開発環境のセットアップ

### 1. クライアントのセットアップ
(変更なし)

### 2. バックエンドのセットアップ (ランキング・ショップ機能)
ランキングやショップ機能などを完全に動作させるには、バックエンドの設定が必要です。

1.  **Supabaseのセットアップ:**
    - Supabaseで新規プロジェクトを作成します。
    - `users`と`sleep_records`テーブルを作成します。
    - 作成したテーブルの**Row-Level Security (RLS)は無効に設定**してください。

2.  **データベースのスキーマ設定（必須）:**
    - SupabaseプロジェクトのSQL Editorから、以下のSQLを**すべて**実行し、テーブルスキーマを正しく設定します。
    - **`users`テーブル:**
      ```sql
      -- ユーザー名の文字数制限
      ALTER TABLE public.users
      ALTER COLUMN username TYPE character varying(20);

      -- ユーザー名の重複を許さないUNIQUE制約
      ALTER TABLE public.users
      ADD CONSTRAINT users_username_key UNIQUE (username);
      
      -- スリープコインを管理するカラム
      ALTER TABLE public.users
      ADD COLUMN sleep_coins INTEGER NOT NULL DEFAULT 0;
      ```
    - **`sleep_records`テーブル:**
      ```sql
      -- ランキングのUpsert処理とデータ整合性のためのUNIQUE制約
      ALTER TABLE public.sleep_records
      ADD CONSTRAINT sleep_records_user_id_date_key UNIQUE (user_id, date);

      -- v2で導入されたdataIdを格納するカラムを追加
      ALTER TABLE public.sleep_records
      ADD COLUMN data_id UUID;

      -- usersテーブルの行削除時に、関連する睡眠記録も自動で削除する設定
      ALTER TABLE public.sleep_records
      DROP CONSTRAINT IF EXISTS sleep_records_user_id_fkey;

      ALTER TABLE public.sleep_records
      ADD CONSTRAINT sleep_records_user_id_fkey
      FOREIGN KEY (user_id)
      REFERENCES public.users (id)
      ON DELETE CASCADE;
      ```
    - **`user_unlocked_backgrounds`テーブル (新規):**
      ```sql
      -- 購入済み背景を記録するテーブル
      CREATE TABLE public.user_unlocked_backgrounds (
        user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
        background_id TEXT NOT NULL,
        purchased_at TIMESTAMPTZ NOT NULL DEFAULT now(),
        PRIMARY KEY (user_id, background_id)
      );
      ```

## APKファイルのビルド方法
(変更なし)

## 開発者情報
- **アプリ名:** Zzzone（ズォーン）
- **制作者名:** kou09427,syuu55
- **共同編集:** Gemini-2.5-pro
- **アイコン制作:** syuu55
- **対応端末:** Android, Web

---

**謝辞:**
本アプリの開発にご協力いただいた皆様に深く感謝いたします。