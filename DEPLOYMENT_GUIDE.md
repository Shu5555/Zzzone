# APIキー流出問題の修正 - デプロイ手順

このガイドでは、Supabase Edge Functionsのデプロイと、既に流出したAPIキーの無効化手順について説明します。

## 前提条件

- Supabaseプロジェクトが作成済み
- Google Cloud Console、OpenWeatherMapのアカウントを持っている
- Node.jsがインストールされている

---

## ステップ1: 既存のAPIキーを無効化

**重要**: 最初に既存のAPIキーを無効化してください。

### 1.1 Gemini API Keyの無効化と再生成

1. [Google Cloud Console](https://console.cloud.google.com/)にアクセス
2. 対象のプロジェクトを選択
3. **APIs & Services** > **Credentials**に移動
4. 既存のGemini API Keyを見つけて**削除**
5. **+ CREATE CREDENTIALS** > **API key**で新しいキーを生成
6. 生成されたキーをコピーして安全な場所に保存

### 1.2 OpenWeatherMap API Keyの無効化と再生成

1. [OpenWeatherMap](https://home.openweathermap.org/api_keys)にログイン
2. 既存のAPIキーを見つけて**Revoke**（削除）
3. **Create key**で新しいキーを生成
4. 生成されたキーをコピーして安全な場所に保存

---

## ステップ2: Supabase CLIのインストールとセットアップ

### 2.1 Supabase CLIのインストール

```bash
npm install -g supabase
```

インストール確認:
```bash
supabase --version
```

### 2.2 Supabaseにログイン

```bash
supabase login
```

ブラウザが開くので、Supabaseアカウントでログインしてください。

### 2.3 プロジェクトとリンク

```bash
cd c:\Users\shoul\sleep_management_app\Zzzone
supabase link --project-ref <your-project-ref>
```

**プロジェクトRefの確認方法**:
1. [Supabaseダッシュボード](https://supabase.com/dashboard)にアクセス
2. プロジェクトを選択
3. **Settings** > **General** > **Reference ID**をコピー

---

## ステップ3: Supabaseにシークレットを設定

新しく生成したAPIキーをSupabaseのシークレットとして設定します。

```bash
# Gemini API Key
supabase secrets set GEMINI_API_KEY=<新しいGemini API Key>

# OpenWeatherMap API Key
supabase secrets set OPENWEATHERMAP_API_KEY=<新しいOpenWeatherMap API Key>
```

設定されたシークレットの確認:
```bash
supabase secrets list
```

---

## ステップ4: Edge Functionsのデプロイ

### 4.1 両方のEdge Functionsをデプロイ

```bash
# gemini-proxyをデプロイ
supabase functions deploy gemini-proxy

# weather-proxyをデプロイ
supabase functions deploy weather-proxy
```

または一括デプロイ:
```bash
supabase functions deploy
```

### 4.2 デプロイの確認

```bash
supabase functions list
```

以下のように表示されればデプロイ成功です：
```
gemini-proxy (DEPLOYED)
weather-proxy (DEPLOYED)
```

---

## ステップ5: GitHub Secretsの更新（オプション）

モバイル版（APK）ビルドでは引き続きAPIキーが必要なため、GitHub Secretsも更新します。

1. GitHubリポジトリの**Settings** > **Secrets and variables** > **Actions**に移動
2. 以下のSecretsを更新:
   - `GEMINI_API_KEY`: 新しいGemini API Key
   - `OPENWEATHERMAP_API_KEY`: 新しいOpenWeatherMap API Key

**注意**: `SUPABASE_URL`と`SUPABASE_ANON_KEY`は変更不要です。

---

## ステップ6: 動作確認

### 6.1 ローカルでの動作確認

```bash
# Flutterのデバッグビルド（Web版）
flutter run -d chrome
```

以下の機能を確認:
- [ ] AI睡眠分析が動作する
- [ ] クイズ機能が動作する
- [ ] 天気予報が表示される
- [ ] ランキング機能が動作する

### 6.2 GitHub Pagesへのデプロイ

コードをmainブランチにプッシュ:
```bash
git add .
git commit -m "Fix API key exposure issue using Supabase Edge Functions"
git push origin main
```

GitHub Actionsが自動的に実行され、gh-pagesブランチにデプロイされます。

### 6.3 デプロイ後の確認

1. GitHub Actionsの実行状況を確認: `https://github.com/<username>/Zzzone/actions`
2. ビルドが成功したら、GitHub Pagesにアクセス: `https://<username>.github.io/Zzzone/`
3. ブラウザのDevToolsを開き、以下を確認:
   - **Network**タブで、Edge Functions（`/functions/v1/gemini-proxy`等）が呼ばれていること
   - **Sources**タブで、`main.dart.js`にAPIキーが含まれていないこと

---

## トラブルシューティング

### Edge Functionsのデプロイに失敗する

**エラー**: `Failed to deploy function`

**解決策**:
1. Supabase CLIが最新版か確認: `npm update -g supabase`
2. プロジェクトリンクを再確認: `supabase link --project-ref <your-ref>`
3. ログを確認: `supabase functions deploy <function-name> --debug`

### Web版でAPI呼び出しが失敗する

**エラー**: `Failed to fetch`、CORSエラー

**解決策**:
1. Edge Functionsが正しくデプロイされているか確認: `supabase functions list`
2. シークレットが設定されているか確認: `supabase secrets list`
3. ブラウザのコンソールでエラーメッセージを確認

### APIキーが見つからないエラー

**エラー**: `GEMINI_API_KEY is not configured`

**解決策**:
```bash
# シークレットを再設定
supabase secrets set GEMINI_API_KEY=<your-key>

# Edge Functionを再デプロイ
supabase functions deploy gemini-proxy
```

---

## セキュリティチェックリスト

デプロイ完了後、以下を確認してください：

- [x] 古いGemini API Keyを削除した
- [x] 古いOpenWeatherMap API Keyを削除した
- [x] 新しいAPIキーをSupabaseシークレットに設定した
- [x] Edge Functionsが正常にデプロイされた
- [x] GitHub Actionsビルドが成功した
- [x] gh-pagesの`main.dart.js`にAPIキーが含まれていない
- [x] Web版で全機能が正常に動作する
- [x] GitHub Secretsを新しいAPIキーに更新した（モバイル版用）

---

## ローカル開発時の注意事項

### デバッグモード

デバッグモード（`flutter run`）では、従来通り`assets/.env`ファイルからAPIキーを読み込みます。

`.env`ファイルの例:
```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
GEMINI_API_KEY=your-local-dev-api-key
OPENWEATHERMAP_API_KEY=your-local-dev-api-key
```

### Web版のローカル開発

Web版でもローカル環境では直接APIを呼び出します（`kDebugMode`のため）。Edge Functionsを使うのはリリースビルドのみです。

---

## 次のステップ

将来的な改善案：

1. **認証の追加**: Supabase Authと統合し、ログインユーザーのみがEdge Functionsを利用できるようにする
2. **レート制限**: Edge Function内でレート制限を実装し、API利用を制御
3. **キャッシュの実装**: 天気予報など、頻繁に変わらないデータをキャッシュしてAPI呼び出し回数を削減
4. **監視とログ**: Supabaseのログ機能でAPI使用状況を監視

---

## サポート

問題が発生した場合:
- [Supabase公式ドキュメント](https://supabase.com/docs/guides/functions)
- [Edge Functions READMEファイル](file:///c:/Users/shoul/sleep_management_app/Zzzone/supabase/functions/README.md)
