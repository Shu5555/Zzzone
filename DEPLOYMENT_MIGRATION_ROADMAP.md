# Netlify から GitHub Pages への移行ロードマップ (詳細版)

## はじめに

このロードマップは、Zzzone Flutter Webアプリケーションのデプロイ環境をNetlifyからGitHub Pagesへ移行するための、より詳細な手順と考慮事項を提供します。移行の目的は、デプロイプロセスの簡素化、GitHubエコシステムとの統合強化、および長期的な運用コストの最適化です。
ここに記載されているロードマップは、別の開発環境をもとに作成されています。必要に応じて、現在の開発環境をもとにロードマップの再構築を行ってください。

もし、変更履歴に書いてあるが、実際には変更されていない場合は、その内容を実行する。
また、変更内容はその都度、正確かつ詳細にこのテキストファイルに追加記述しなければならない。

## フェーズ1: 現状把握と準備

### 1.1 Netlify設定の確認とバックアップ

*   **目的**: 現在のNetlifyデプロイ環境の情報を完全に把握し、必要な設定をバックアップする。
*   **詳細**:
    *   **環境変数**:
        *   Netlifyのプロジェクト設定（`Site settings` -> `Build & deploy` -> `Environment variables`）に設定されているすべての環境変数（例: `SUPABASE_URL`, `SUPABASE_ANON_KEY`など）をリストアップし、安全な場所に記録します。これらはGitHub ActionsのSecretsとして再設定が必要になります。
        *   Netlify CLIを使用している場合は、`netlify env:list`コマンドで確認できます。
    *   **カスタムドメイン**:
        *   現在Netlifyで使用しているカスタムドメイン設定（`Site settings` -> `Domain management`）を確認します。
        *   DNSレコードの種類（Aレコード、CNAMEレコード）と現在の値、TTL（Time To Live）を記録します。
    *   **ビルド設定**:
        *   Netlifyのビルドコマンド（`Build & deploy` -> `Continuous Deployment` -> `Build settings`）を確認します。通常は`flutter build web`または`flutter build web --release`です。
        *   公開ディレクトリ（`Publish directory`）が`build/web`であることを確認します。
    *   **リダイレクトルール**:
        *   `netlify.toml`ファイル、またはNetlifyのUIで設定されているリダイレクトルール（例: SPAのルーティングのための`/* /index.html 200`）やヘッダー設定を確認します。
        *   これらはGitHub Pagesの`_config.yml`（Jekyllを使用する場合）や`404.html`、またはGitHub Actionsのデプロイ後の処理で再現可能か検討します。Flutter Webアプリの場合、通常は`index.html`のルーティングで対応可能です。
    *   **Netlify Functions**:
        *   もしNetlify Functionsを使用している場合、その機能がGitHub Pages移行後も必要か、またはSupabase Edge Functions、Vercel Functions、Cloudflare Workersなど他のサーバーレスサービスで代替可能か検討します。このロードマップでは、Netlify Functionsを使用していない前提で進めます。

### 1.2 GitHubリポジトリの準備

*   **目的**: GitHub Pagesデプロイの準備として、リポジトリの構成を確認・調整する。
*   **詳細**:
    *   **リポジトリの確認**: アプリケーションのソースコードがGitHubリポジトリに存在し、最新の状態であることを確認します。
    *   **ブランチ戦略の決定**:
        *   GitHub Pagesのデプロイ元として、`gh-pages`ブランチを使用するか、`main`ブランチの`/docs`フォルダを使用するかを決定します。
        *   **推奨**: `gh-pages`ブランチを使用する方法が一般的で、ソースコードとデプロイ成果物を分離できるため管理が容易です。
        *   `gh-pages`ブランチを使用する場合、以下のコマンドで`main`ブランチから`gh-pages`ブランチを作成し、GitHubにプッシュします（初回のみ）。
            ```bash
            git checkout -b gh-pages
            git push -u origin gh-pages
            git checkout main # 作業ブランチに戻る
            ```

## フェーズ2: GitHub Pagesへのデプロイ設定

### 2.1 Flutter Webアプリのビルド設定調整

*   **目的**: GitHub PagesのURL構造に合わせて、Flutter Webアプリが正しく動作するようにビルド設定を調整する。
*   **詳細**:
    *   **`base-href`の設定**:
        *   GitHub PagesのURLは通常 `https://<username>.github.io/<repository-name>/` の形式となります。Flutterアプリがアセット（画像、フォント、JavaScriptファイルなど）を正しく読み込めるように、ビルド時にベースURLを指定する必要があります。
        *   `flutter build web`コマンドに `--base-href /<repository-name>/` オプションを追加します。`<repository-name>`は、GitHubリポジトリの名前（例: `Zzzone`）に置き換えてください。
        *   例: `flutter build web --release --base-href /Zzzone/`
    *   **`index.html`の確認**:
        *   ビルド後、生成された`build/web/index.html`ファイルを開き、`<head>`セクション内の`<base href="...">`タグが正しく設定されていることを確認します。
        *   例: `<base href="/Zzzone/">`

### 2.2 GitHub Actionsワークフローの作成

*   **目的**: コードがプッシュされるたびに自動的にFlutter Webアプリをビルドし、GitHub PagesにデプロイするCI/CDパイプラインを構築する。
*   **詳細**:
    *   リポジトリのルートディレクトリに`.github/workflows/`ディレクトリを作成し、その中に新しいYAMLファイル（例: `deploy-gh-pages.yml`）を作成します。
    *   以下のYAMLコード例を参考に、ワークフローを設定します。

    ```yaml
    name: Deploy Flutter Web to GitHub Pages

    on:
      push:
        branches:
          - main # mainブランチへのプッシュでトリガー
      workflow_dispatch: # 手動実行を可能にする

    jobs:
      build_and_deploy:
        runs-on: ubuntu-latest # ビルド環境を指定

        steps:
          - name: Checkout repository
            uses: actions/checkout@v4 # リポジトリをチェックアウト

          - name: Set up Flutter SDK
            uses: subosito/flutter-action@v2 # Flutter SDKをセットアップ
            with:
              channel: 'stable' # Flutterの安定版を使用

          - name: Get Flutter dependencies
            run: flutter pub get # 依存関係を取得

          - name: Create .env file
            run: |
              echo "SUPABASE_URL=${{ secrets.SUPABASE_URL }}" >> .env
              echo "SUPABASE_ANON_KEY=${{ secrets.SUPABASE_ANON_KEY }}" >> .env
              echo "GEMINI_API_KEY=${{ secrets.GEMINI_API_KEY }}" >> .env
            env:
              SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
              SUPABASE_ANON_KEY: ${{ secrets.SUPABASE_ANON_KEY }}
              GEMINI_API_KEY: ${{ secrets.GEMINI_API_KEY }}
            # 注意: GitHub ActionsのSecretsは環境変数として直接参照できないため、
            # .envファイルを生成してFlutterアプリが読み込めるようにします。
            # 実際のアプリケーションでは、ビルド時にDart定義として渡すなど、
            # よりセキュアな方法を検討してください。

          - name: Build Flutter Web
            run: flutter build web --release --base-href /Zzzone/ # GitHub Pages向けにビルド
            # ここで /Zzzone/ はリポジトリ名に置き換えてください

          - name: Deploy to GitHub Pages
            uses: peaceiris/actions-gh-pages@v3 # GitHub Pagesへのデプロイアクション
            with:
              github_token: ${{ secrets.GITHUB_TOKEN }} # GitHubが提供するトークン
              publish_dir: ./build/web # デプロイするディレクトリ
              publish_branch: gh-pages # デプロイ先のブランチ (事前に作成しておく)
              # cname: your-custom-domain.com # カスタムドメインを使用する場合にコメント解除
    ```
    *   **Secretsの設定**:
        *   Netlifyから移行した環境変数（`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GEMINI_API_KEY`など）をGitHubリポジトリの「Settings」->「Secrets and variables」->「Actions」に登録します。
        *   `New repository secret`をクリックし、`Name`と`Value`を入力して追加します。これらのSecretsはワークフロー内で安全に参照されます。

### 2.3 初回デプロイと動作確認

*   **目的**: GitHub Actionsワークフローが正しく機能し、アプリがGitHub Pagesで動作することを確認する。
*   **詳細**:
    *   作成したワークフローファイル（`deploy-gh-pages.yml`）をGitHubリポジトリにプッシュします。
    *   GitHubリポジトリの「Actions」タブに移動し、ワークフローの実行状況を監視します。デプロイが成功したことを確認します。
    *   GitHub PagesのURL（例: `https://<username>.github.io/<repository-name>/`）にアクセスし、アプリが正常に表示され、すべての機能（特にSupabase連携、AI分析）が動作することを確認します。
    *   ブラウザの開発者ツール（F12）を開き、コンソールにエラーがないか、ネットワークタブでアセットが正しく読み込まれているかを確認します。

## フェーズ3: ドメイン設定と最終確認

### 3.1 カスタムドメインの設定

*   **目的**: 現在Netlifyで使用しているカスタムドメインをGitHub Pagesに移行する。
*   **詳細**:
    *   **GitHub Pagesでの設定**:
        *   GitHubリポジトリの「Settings」->「Pages」に移動します。
        *   「Custom domain」セクションに、使用したいカスタムドメイン（例: `zzzone.example.com`）を入力し、「Save」をクリックします。
        *   GitHub PagesがCNAMEファイルを自動的に生成し、`gh-pages`ブランチにコミットします。
    *   **DNSプロバイダーでの設定**:
        *   ドメインを管理しているDNSプロバイダー（例: Cloudflare, お名前.com, Google Domainsなど）の管理画面にログインします。
        *   既存のNetlifyに関連するDNSレコード（特にAレコードやCNAMEレコード）を削除します。
        *   GitHub Pagesが指定するDNSレコード（通常はCNAMEレコードを`your-username.github.io`に向けるか、GitHub PagesのIPアドレスを指すAレコード）を設定します。
        *   例（CNAMEの場合）:
            ```
            Type: CNAME
            Name: zzzone.example.com (またはサブドメイン名)
            Value: <your-username>.github.io
            TTL: Auto (または短い時間)
            ```
        *   DNSの変更がインターネット全体に反映されるまでには時間がかかる場合があります（数分から数時間）。

### 3.2 Netlifyの無効化

*   **目的**: 移行が完了し、GitHub Pagesが安定稼働していることを確認した後、Netlifyでのデプロイを停止する。
*   **詳細**:
    *   GitHub Pagesでのカスタムドメイン設定が完全に反映され、アプリが安定してアクセスできることを十分に確認します。
    *   Netlifyのプロジェクト設定に移動し、ビルドを無効にするか、プロジェクト自体を削除します。これにより、誤って古いバージョンがデプロイされたり、リソースが無駄に消費されたりするのを防ぎます。

### 3.3 最終テストと監視

*   **目的**: 移行後のシステムが完全に安定していることを確認し、継続的に監視する。
*   **詳細**:
    *   カスタムドメイン経由でのアクセスを含め、すべての機能が正常に動作することを確認します。
    *   Google Analyticsなどのトラッキングツールを設定している場合、データが正しく収集されていることを確認します。
    *   定期的にGitHub Actionsのデプロイログを監視し、問題が発生していないか確認します。
    *   UptimeRobotなどの外部監視サービスを利用して、サイトの稼働状況を継続的に監視することを検討します。

    ## 4. 変更履歴
//ここに追記していく

---