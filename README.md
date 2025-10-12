# Zzzone - 睡眠管理アプリ

## 概要
Zzzoneは、日々の睡眠を記録・可視化し、さらに全国のユーザーと睡眠時間を競い合うことで、健康的で楽しい睡眠習慣をサポートするモバイルアプリケーションです。新たに、偉人たちの「名言」を集めるガチャ機能や、アプリ内のお知らせ機能が追加され、コレクションとカスタマイズの楽しみが広がりました。

## 主な機能

### 1. 睡眠記録と評価
- **自動計測・手動記録:** 日々の睡眠を手軽に、または詳細に記録できます。
- **睡眠評価:** 睡眠スコア、体感パフォーマンス、二度寝の有無など、多角的に睡眠を評価します。
- **目標達成:** 設定した目標入眠時刻を守ることで、ゲーム感覚で睡眠習慣の改善を目指せます。

### 2. ガチャ機能と名言コレクション
- **名言ガチャ:** 睡眠時間に応じて獲得できる「スリープコイン」を使い、古今東西の偉人たちの「名言」を獲得できるガチャを引くことができます。
- **名言の検索:** 名言一覧画面では、キーワードで名言や著者名を検索できます（ひらがな・カタカナの区別なし）。
- **名言のコピー:** 名言一覧で、好きな名言を長押しすると、そのテキストをクリップボードにコピーできます。
- **レアリティ:** 名言には「コモン」「レア」「激レア」などのレアリティが設定されており、確率に基づいた抽選が行われます。
- **10連ガチャ:** 1回分お得に、一度に10個の名言を獲得できる10連ガチャも搭載しています。
- **ガチャ履歴:** これまで引いたガチャの結果をすべて時系列で確認できます。
- **演出:** ガチャを引く際には、獲得した名言の最高レアリティに応じたアニメーション演出が再生されます。
- **ポイント:** ガチャを1回引くごとに1ポイントが貯まります。
- **新着表示:** ガチャで初めて獲得した名言には「NEW!」マークが表示されます。
- **超激レア確定ガチャチケット:**
  - ショップの「ポイント」タブで100ポイントと交換できるチケットです。
  - このチケットを使用すると、必ず「超激レア」レアリティの名言を獲得できます。（「OWN_CHIN」レアリティは対象外です）
  - チケットを所持している場合のみ、ガチャ画面に専用のボタンが表示されます。

### 3. ホーム画面のカスタマイズ
- **お気に入り名言:** 「名言一覧」画面から、獲得した名言の中から好きなものを「お気に入り」に設定できます。設定した名言はホーム画面に常に表示されます。
- **ランダムモード:** 「お気に入り」を設定せず、「ランダムモード」をONにすると、獲得した名言の中から日替わりで異なる名言がホーム画面に表示されます。

### 4. 履歴と分析
- **睡眠履歴:** グラフやカレンダー形式で、過去の睡眠記録を直感的に振り返ることができます。記録を長押しすることで、内容の編集も可能です。
- **AIによる睡眠分析:** 5件以上の睡眠記録を元に、AI(Google Gemini)があなたの睡眠傾向を分析し、「総評」「良い点」「改善点」を提案します。

### 5. ショップ
- **タブ切り替え:** ショップは「背景色」と「ガチャ」の2つのタブで構成されています。
- **背景色の購入:** スリープコインを使い、ランキング画面で利用できる背景色を購入できます。

### 6. プロフィールと睡眠時間ランキング
- **プロフィール画面:** ユーザー名、ランキングへの参加設定、ランキングで表示される背景色などを一元管理できます。
- **全国ランキング:** 全ユーザーのその日の睡眠時間を集計し、ランキング形式で表示します。
- **名言ランキング:** ランキング画面右上のボタンから、各ランカーが設定している「お気に入り名言」をランキング順に見ることができます。

### 7. 天気予報
- **ホーム画面での表示:** ホーム画面の下部に、設定した地点の現在の天気、気温、今後の雨の予報（例：「晴れ、のち雨」）が表示されます。
- **地点の設定:** 「設定」画面から、天気予報を表示したい地点を「都道府県」と「市区町村」に分けて設定できます。日本語での入力に対応しており、市区町村を空欄にした場合は、その都道府県の県庁所在地の天気が表示されます。

### 8. ギフトコード機能
- **コード入力:** 管理者から配布されるギフトコードを入力することで、スリープコインや「超激レア確定ガチャチケット」などの特別なアイテムを獲得できます。
- **利用方法:** プロフィール画面の「ギフトコード」メニューから入力画面にアクセスできます。

### 9. ぐっすりサタデー
- **スリープコイン2倍:** 金曜日の午前4:00から土曜日の午前3:59までの間に睡眠を記録すると、獲得できるスリープコインが通常の2倍になります。
- **ホーム画面表示:** 対象期間中、ホーム画面の名言の上に大きな黄色の「S」が表示され、特別な日であることをお知らせします。

### 10. お知らせ機能
- **更新情報:** ホーム画面右上のアイコンから、アプリの更新情報や開発からのお知らせを確認できます。
- **未読バッジ:** 未読のお知らせがある場合、アイコンに赤い点が表示され、新しい情報があることを知らせます。
- **更新方法 (v5時点):**
  1. プロジェクト内の `assets/announcements.json` ファイルを開きます。
  2. 既存の形式に倣い、新しいお知らせ情報をJSONオブジェクトとして配列の先頭に追加します。
     - `id`は他と重複しないユニークな文字列にしてください。
     - `createdAt`は現在時刻などを `YYYY-MM-DDTHH:MM:SS+09:00` の形式で記述してください。
  3. ファイルを保存した後、アプリを再ビルドすると、新しいお知らせが反映されます。
  
  > **Note:** 現在の仕様では、お知らせの更新にアプリ自体のアップデートが必要です。将来的には、アプリのアップデートなしで更新できる仕組み（フェーズ3）への移行を計画しています。

---

## アーキテクチャ (v5)

### クライアントサイド
- **フレームワーク:** Flutter (Dart)
- **ローカルデータベース:** SQLite (`sqflite`) / Web向けインメモリ + `shared_preferences`
  - **保存データ:** 睡眠記録、獲得した名言リスト、ガチャの履歴、**お知らせの未読状態**
- **状態管理/設定保存:** `shared_preferences`
- **お知らせデータ:** `assets/announcements.json` (ローカル)
- **APIクライアント:** `http`
- **環境変数管理:** 
  - **デバッグモード:** `.env` ファイル (`flutter_dotenv`)
  - **リリースモード:** コンパイル時環境変数 (`--dart-define`)

### バックエンド
- **ランキング・通貨・ギフトコード管理:** Supabase (PostgreSQL)
- **AI分析機能:** Google Gemini API
- **天気予報:** OpenWeatherMap API

---

## 開発環境のセットアップ

### 1. クライアントのセットアップ
(変更なし)

### 2. APIキーと環境変数の設定

本プロジェクトは、APIキーなどの機密情報を環境変数経由でアプリに渡します。開発時とリリース時で方法が異なります。

#### 2.1. ローカルでの開発（デバッグモード）

ローカル環境での開発を容易にするため、`.env` ファイルを使用します。

1.  プロジェクトのルートディレクトリ（`pubspec.yaml` と同じ階層）に `.env` という名前のファイルを作成します。
2.  以下の内容を `.env` ファイルに記述し、`YOUR_..._KEY` の部分をご自身のAPIキーに置き換えてください。

    ```
    SUPABASE_URL=YOUR_SUPABASE_URL
    SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
    GEMINI_API_KEY=YOUR_GEMINI_API_KEY
    OPENWEATHERMAP_API_KEY=YOUR_OPENWEATHERMAP_API_KEY
    ```

3.  `.env` ファイルは `.gitignore` に登録されているため、Gitリポジトリにはコミットされません。
4.  上記の設定が完了すれば、`flutter run` コマンドだけでアプリを実行できます。

#### 2.2. リリースビルド（GitHub Actions）

リリースビルド（モバイル/Web）では、`--dart-define` オプションを使用して、GitHub SecretsからAPIキーを安全に受け取ります。

-   詳細は `.github/workflows/` 内の `release_apk.yml` および `deploy.yml` を参照してください。
-   ビルドコマンドに、以下のように `--dart-define` フラグが追加されています。

    ```yaml
    run: flutter build apk --release \
      --dart-define=SUPABASE_URL=${{ secrets.SUPABASE_URL }} \
      --dart-define=SUPABASE_ANON_KEY=${{ secrets.SUPABASE_ANON_KEY }} \
      --dart-define=GEMINI_API_KEY=${{ secrets.GEMINI_API_KEY }} \
      --dart-define=OPENWEATHERMAP_API_KEY=${{ secrets.OPENWEATHERMAP_API_KEY }}
    ```

### 3. バックエンドのセットアップ

1.  **Supabaseプロジェクトを作成**
2.  **テーブルとカラムのスキーマを設定:**
    - SupabaseプロジェクトのSQL Editorから、以下のSQLを実行します。
    - **`users`テーブル:** 
      ```sql
      -- 基本スキーマ (初回セットアップ時)
      CREATE TABLE public.users (
        id UUID NOT NULL PRIMARY KEY,
        username CHARACTER VARYING(20) NOT NULL UNIQUE,
        background_preference TEXT DEFAULT 'default',
        sleep_coins INTEGER NOT NULL DEFAULT 0,
        favorite_quote_id TEXT
      );

      -- 既存テーブルへの追加カラム
      ALTER TABLE public.users ADD COLUMN IF NOT EXISTS gacha_pull_count INTEGER NOT NULL DEFAULT 0;
      ALTER TABLE public.users ADD COLUMN IF NOT EXISTS gacha_points INTEGER NOT NULL DEFAULT 0;
      ALTER TABLE public.users ADD COLUMN IF NOT EXISTS ultra_rare_tickets INTEGER NOT NULL DEFAULT 0;
      ```
    - **`sleep_records`テーブル:** 
      ```sql
      CREATE TABLE public.sleep_records (
        id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
        user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
        date DATE NOT NULL,
        sleep_duration INTEGER NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
        data_id UUID,
        UNIQUE (user_id, date)
      );
      ```
    - **`gift_codes`テーブル (ギフトコード機能で必要):** 
      ```sql
      CREATE TABLE IF NOT EXISTS public.gift_codes (
          id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
          code TEXT NOT NULL UNIQUE,
          reward_type TEXT NOT NULL,
          reward_value TEXT NOT NULL,
          expires_at TIMESTAMPTZ,
          max_uses INT DEFAULT 1,
          use_count INT DEFAULT 0,
          created_at TIMESTAMPTZ DEFAULT now(),
          code_type TEXT
      );
      ```
    - **`user_redeemed_codes`テーブル (ギフトコード機能で必要):** 
      ```sql
      CREATE TABLE IF NOT EXISTS public.user_redeemed_codes (
          id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
          user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
          code_id BIGINT NOT NULL REFERENCES public.gift_codes(id) ON DELETE CASCADE,
          redeemed_at TIMESTAMPTZ DEFAULT now(),
          UNIQUE (user_id, code_id)
      );
      ```

3.  **RPC関数の設定:**
    - 以下のSQLを実行し、安全なサーバーサイド関数を作成します。
    - **`redeem_gift_code`関数:** 
      ```sql
      CREATE OR REPLACE FUNCTION redeem_gift_code(p_user_id UUID, p_code TEXT)
      RETURNS TABLE(success BOOLEAN, message TEXT, reward_type TEXT, reward_value TEXT) AS $$
      -- ... (内容は変更なし)
      $$ LANGUAGE plpgsql SECURITY DEFINER;
      ```
    - **`get_daily_ranking_with_quotes`関数 (名言ランキングで必要):** 
      ```sql
      CREATE OR REPLACE FUNCTION get_daily_ranking_with_quotes(p_date TEXT)
      RETURNS TABLE(
          user_id UUID,
          username TEXT,
          sleep_duration INTEGER,
          background_preference TEXT,
          favorite_quote_id TEXT
      ) AS $$
      BEGIN
          RETURN QUERY
          WITH latest_records AS (
              SELECT
                  sr.user_id,
                  sr.sleep_duration,
                  ROW_NUMBER() OVER(PARTITION BY sr.user_id ORDER BY sr.created_at DESC) as rn
              FROM
                  public.sleep_records sr
              WHERE
                  sr.date = p_date::DATE
          )
          SELECT
              u.id AS user_id,
              u.username::TEXT,
              lr.sleep_duration,
              u.background_preference,
              u.favorite_quote_id
          FROM
              latest_records lr
          JOIN
              public.users u ON lr.user_id = u.id
          WHERE
              lr.rn = 1
          ORDER BY
              lr.sleep_duration DESC
          LIMIT 20;
      END;
      $$ LANGUAGE plpgsql;
      ```

---

## 開発者情報
- **アプリ名:** Zzzone（ズォーン）
- **制作者名:** kou09427,syuu55
- **共同編集:** Gemini-1.5-pro
