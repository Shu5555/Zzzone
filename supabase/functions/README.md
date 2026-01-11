# Supabase Edge Functions

このディレクトリには、APIキーを安全に管理するためのSupabase Edge Functionsが含まれています。

## Functions

### gemini-proxy
Gemini APIへのプロキシ。Flutter WebアプリからAPIキーを隠蔽します。

**エンドポイント**: `https://<your-project>.supabase.co/functions/v1/gemini-proxy`

**使用モデル**: `gemini-3-flash-preview`（統一モデル）

**リクエスト**:
```json
{
  "prompt": "プロンプトテキスト"
}
```

**レスポンス**: Gemini APIのレスポンスをそのまま返却

### weather-proxy
OpenWeatherMap APIへのプロキシ。Flutter WebアプリからAPIキーを隠蔽します。

**エンドポイント**: `https://<your-project>.supabase.co/functions/v1/weather-proxy?city=東京`

**クエリパラメータ**:
- `city`: 都市名（日本語可）

**レスポンス**: OpenWeatherMapの天気予報データ + 都市情報

## デプロイ方法

### 1. Supabase CLIのインストール

```bash
npm install -g supabase
```

### 2. Supabaseにログイン

```bash
supabase login
```

### 3. プロジェクトとリンク

```bash
supabase link --project-ref <your-project-ref>
```

プロジェクトRefは、SupabaseダッシュボードのProject Settings > General > Reference IDで確認できます。

### 4. シークレットの設定

```bash
supabase secrets set GEMINI_API_KEY=<your-new-gemini-api-key>
supabase secrets set OPENWEATHERMAP_API_KEY=<your-new-openweathermap-api-key>
```

**重要**: 既に流出したAPIキーは使用せず、新しいAPIキーを生成してください。

### 5. Edge Functionsのデプロイ

```bash
# 両方のFunctionをまとめてデプロイ
supabase functions deploy gemini-proxy
supabase functions deploy weather-proxy
```

または、一度にデプロイ:
```bash
supabase functions deploy
```

### 6. デプロイ確認

```bash
# デプロイされたFunctionsの一覧を確認
supabase functions list
```

## ローカルでのテスト

### 1. ローカル環境の起動

```bash
# Supabaseのローカル環境を起動（初回）
supabase start

# Edge Functionsをローカルで起動
supabase functions serve
```

### 2. 環境変数の設定

`.env.local`ファイルを作成:
```
GEMINI_API_KEY=your-api-key
OPENWEATHERMAP_API_KEY=your-api-key
```

### 3. curlでテスト

```bash
# Gemini Proxyのテスト
curl -i --location --request POST 'http://localhost:54321/functions/v1/gemini-proxy' \
  --header 'Content-Type: application/json' \
  --data '{
    "prompt": "こんにちは"
  }'

# Weather Proxyのテスト
curl -i --location --request GET 'http://localhost:54321/functions/v1/weather-proxy?city=東京'
```

## トラブルシューティング

### シークレットが設定されていない

エラー: `GEMINI_API_KEY is not configured`

**解決策**: `supabase secrets set`コマンドでシークレットを設定してください。

### CORSエラー

Edge FunctionsではCORSヘッダーを自動的に設定していますが、問題がある場合は`corsHeaders`の設定を確認してください。

### デプロイが失敗する

- Supabase CLIのバージョンを確認: `supabase --version`
- 最新版にアップデート: `npm update -g supabase`
- プロジェクトリンクを確認: `supabase link --project-ref <your-ref>`

## セキュリティノート

- APIキーはSupabaseのシークレットとして管理され、クライアントには公開されません
- Edge Functionsは認証なしで呼び出し可能ですが、必要に応じてSupabase Authと統合できます
- 本番環境ではレート制限の実装を推奨します
