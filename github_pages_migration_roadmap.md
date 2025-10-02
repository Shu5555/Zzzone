# Netlify から GitHub Pages への移行ロードマップ (Zzzone)

このロードマップは、Zzzone アプリケーションのデプロイ先を Netlify から GitHub Pages へ移行するための詳細な手順を提供します。

## 1. プロジェクトの理解

Zzzone は Flutter (Dart) で開発された睡眠管理モバイルアプリケーションであり、Web 版も提供されています。

*   **主要機能:** 睡眠記録、評価、履歴分析、AIによる睡眠分析、全国ランキング、Web版での計測持続、ホーム画面での名言・アドバイス表示。
*   **クライアントサイド:** Flutter (Dart) を使用し、`sqflite`、`path_provider`、`intl`、`fl_chart`、`shared_preferences`、`table_calendar`、`uuid`、`http`、`flutter_dotenv`、`share_plus` などのパッケージを利用。
*   **バックエンド:** ランキング機能は Netlify Functions / Supabase、AI分析機能は Google Gemini API を利用。
*   **Web版:** Flutter for Web で実行され、ブラウザを閉じても計測が継続される機能を持つ。
*   **環境変数:** `GEMINI_API_KEY` は Netlify の環境変数から `.env` ファイルとして生成され、`flutter_dotenv` パッケージで読み込まれる。

## 2. 現状の確認 (Netlify 固有設定)

現在の Netlify デプロイ設定は以下の通りです。

*   **ビルドコマンド:** `sh ./netlify_build.sh`
*   **公開ディレクトリ:** `build/web`
*   **Netlify Functions:** `netlify/functions` ディレクトリに配置されています。
*   **ビルドスクリプト (`netlify_build.sh`) の詳細:**
    *   Netlify のビルド環境で Flutter SDK をクローンし、パスを設定しています。
    *   `flutter pub get` を実行しています。
    *   `GEMINI_API_KEY` 環境変数を読み込み、`.env` ファイルを生成しています。
    *   `flutter build web` を実行しています。

## 3. GitHub Pages への移行ロードマップ

### 3.1. GitHub Pages の有効化

1.  **GitHub リポジトリの設定:**
    *   GitHub リポジトリにアクセスし、「Settings」タブをクリックします。
    *   左サイドバーの「Pages」をクリックします。
    *   「Source」セクションで、デプロイ元となるブランチ（通常は `main` ブランチ）を選択し、フォルダを `/ (root)` または `/docs` に設定します。Flutter Web のビルド出力は `build/web` に生成されるため、GitHub Actions で `gh-pages` ブランチにデプロイするのが一般的です。
    *   **推奨:** GitHub Actions を使用して `gh-pages` ブランチにビルド成果物をデプロイするように設定します。

### 3.2. ビルドプロセスの調整と GitHub Actions の導入

Netlify の `netlify_build.sh` の内容を GitHub Actions のワークフローに移行し、GitHub Pages への自動デプロイを設定します。

1.  **`flutter build web` コマンドの調整:**
    *   GitHub Pages はサブディレクトリでホストされるため、Flutter Web アプリケーションのベース URL を設定する必要があります。
    *   `flutter build web --base-href /<your-repo-name>/` のように `--base-href` オプションを追加します。
        *   例: リポジトリ名が `Zzzone` の場合、`--base-href /Zzzone/` となります。
    *   `index.html` の `<base href="/">` を `<base href="/<your-repo-name>/">` に変更する必要があるかもしれません。これは `--base-href` オプションで自動的に処理されるはずですが、念のため確認してください。

2.  **GitHub Actions ワークフローの作成:**
    *   リポジトリのルートに `.github/workflows/` ディレクトリを作成します。
    *   その中に `deploy.yml` (または任意の名前) ファイルを作成し、以下の内容を記述します。

    ```yaml
    name: Deploy Flutter Web to GitHub Pages

    on:
      push:
        branches:
          - main # main ブランチへのプッシュ時に実行

    jobs:
      build_and_deploy:
        runs-on: ubuntu-latest

        steps:
          - name: Checkout code
            uses: actions/checkout@v4

          - name: Setup Flutter
            uses: subosito/flutter-action@v2
            with:
              flutter-version: '3.x' # pubspec.yaml の SDK バージョンに合わせて調整 (例: 3.9.2)
              channel: 'stable'

          - name: Get Flutter dependencies
            run: flutter pub get

          - name: Create .env file for GEMINI_API_KEY
            run: echo "GEMINI_API_KEY=${{ secrets.GEMINI_API_KEY }}" > .env
            env:
              GEMINI_API_KEY: ${{ secrets.GEMINI_API_KEY }} # GitHub Secrets から API キーを取得

          - name: Build Flutter Web
            run: flutter build web --release --base-href /Zzzone/ # リポジトリ名に合わせて変更

          - name: Deploy to GitHub Pages
            uses: peaceiris/actions-gh-pages@v3
            if: github.ref == 'refs/heads/main'
            with:
              github_token: ${{ secrets.GITHUB_TOKEN }}
              publish_dir: ./build/web
              publish_branch: gh-pages # デプロイ先のブランチ (通常は gh-pages)
              # CNAME ファイルを使用する場合 (カスタムドメイン設定時)
              # cname: your-custom-domain.com
    ```

3.  **GitHub Secrets の設定:**
    *   `GEMINI_API_KEY` を GitHub Actions で安全に利用するため、リポジトリの「Settings」→「Secrets and variables」→「Actions」で `GEMINI_API_KEY` という名前の新しいシークレットを追加し、API キーの値を設定します。

### 3.3. Netlify 固有設定の削除

1.  **`netlify.toml` の削除:**
    *   このファイルは Netlify 固有の設定なので、リポジトリから削除します。
2.  **`netlify_build.sh` の削除:**
    *   このスクリプトの内容は GitHub Actions ワークフローに移行されたため、リポジトリから削除します。
3.  **`netlify/functions` ディレクトリの扱い:**
    *   Netlify Functions は GitHub Pages では直接ホストできません。
    *   もしランキング機能のバックエンドを GitHub Pages に移行したい場合、別のサーバーレスプラットフォーム（例: Vercel Functions, AWS Lambda, Google Cloud Functions）への移行を検討するか、Supabase の直接利用に切り替える必要があります。
    *   現状、`README.md` によるとランキング機能は Netlify Functions / Supabase を利用しているため、GitHub Pages 移行後も Supabase を直接利用するか、別のサーバーレスプラットフォームに移行する必要があります。このロードマップでは、Netlify Functions の部分は GitHub Pages のスコープ外とします。

### 3.4. ドメイン設定の移行 (カスタムドメインを使用している場合)

カスタムドメインを使用している場合は、以下の手順で移行します。

1.  **CNAME ファイルの作成:**
    *   `build/web` ディレクトリ（GitHub Actions でデプロイされるディレクトリ）のルートに `CNAME` という名前のファイルを作成し、その中にカスタムドメイン名（例: `your-custom-domain.com`）を記述します。
    *   GitHub Actions の `peaceiris/actions-gh-pages` アクションを使用する場合、`cname` オプションでドメインを指定することも可能です。
2.  **DNS レコードの更新:**
    *   ドメインレジストラ（お名前.com, Cloudflareなど）の管理画面で、DNS レコードを GitHub Pages の設定に合わせて更新します。
    *   通常、`A` レコードを GitHub Pages の IP アドレスに、または `CNAME` レコードを `your-github-username.github.io` に設定します。

### 3.5. テストと検証

1.  **GitHub Pages の URL にアクセス:**
    *   デプロイが完了したら、GitHub Pages の URL (`https://<your-github-username>.github.io/<your-repo-name>/`) にアクセスし、アプリケーションが正しく表示されるか確認します。
2.  **機能テスト:**
    *   アプリケーションのすべての機能（睡眠記録、分析、ランキング、AI分析など）が期待通りに動作するかをテストします。
    *   特に、`GEMINI_API_KEY` を使用する AI 分析機能が正しく動作するか確認してください。
3.  **SPA ルーティングの確認:**
    *   Flutter Web は SPA (Single Page Application) であるため、直接 URL にアクセスした場合やリロード時に 404 エラーが発生する可能性があります。
    *   これを解決するため、`build/web` ディレクトリに `404.html` ファイルを作成し、`index.html` の内容をコピーして配置します。これにより、404 エラー時に `index.html` が表示され、Flutter ルーターがパスを処理できるようになります。

### 3.6. Netlify の停止

GitHub Pages でアプリケーションが完全に動作することを確認した後、Netlify のサイトを停止または削除します。

1.  **Netlify サイトの削除:**
    *   Netlify のダッシュボードにログインし、該当するサイトを削除します。

## 4. 注意事項

*   **キャッシュ:** GitHub Pages は強力なキャッシュを使用する場合があります。変更がすぐに反映されない場合は、ブラウザのキャッシュをクリアするか、シークレットモードでアクセスしてみてください。
*   **SPA ルーティング:** 前述の通り、Flutter Web のルーティングはクライアントサイドで行われるため、GitHub Pages で直接 URL にアクセスすると 404 エラーになることがあります。`404.html` の設定は必須です。
*   **Netlify Functions:** ランキング機能のバックエンドとして利用していた Netlify Functions は GitHub Pages では動作しません。Supabase を直接利用するか、別のサーバーレスサービスへの移行を検討してください。
*   **API キーのセキュリティ:** `GEMINI_API_KEY` は GitHub Secrets で管理されますが、クライアントサイドで利用されるため、ビルドされた JavaScript コード内に含まれることになります。これは完全に安全な方法ではありません。より高いセキュリティが必要な場合は、API キーをプロキシする独自のバックエンドサービスを構築することを検討してください。

---

このロードマップは、Zzzone プロジェクトの GitHub Pages への移行を成功させるための詳細な手順を提供します。各ステップを慎重に実行し、特に履歴の書き換えやカスタムドメインの移行には注意してください。

---

# GitHub Pages と Netlify の仕様差によるコード修正・操作

Zzzone プロジェクトを Netlify から GitHub Pages へ移行する際に必要となる、主な仕様差とそれに対応するコード修正または操作は以下の通りです。

## 1. ベース URL のハンドリング

*   **Netlify の仕様:**
    *   通常、ルートドメインまたはサブドメインにデプロイされ、ベース URL の設定は自動的に処理されるか、リダイレクトルールで柔軟に対応できます。
*   **GitHub Pages の仕様:**
    *   ユーザーページ (`username.github.io`) の場合はルートにデプロイされますが、プロジェクトページ (`username.github.io/repo-name/`) の場合はリポジトリ名がサブディレクトリとして扱われます。このため、アプリケーションがこのサブディレクトリを認識する必要があります。
*   **必要なコード修正/操作:**
    1.  **Flutter ビルドコマンドの変更:**
        *   `flutter build web` コマンドに `--base-href` オプションを追加し、リポジトリ名を指定します。
        *   **例:** `flutter build web --release --base-href /Zzzone/`
        *   これは、GitHub Actions ワークフロー内のビルドステップで適用します。
    2.  **Flutter ルーターの設定確認:**
        *   Flutter アプリケーション内で使用しているルーター（例: `GoRouter` や `Navigator 2.0`）が、このベースパスを正しく処理するように設定されているか確認します。
        *   `GoRouter` の場合、`urlPathStrategy` を `UrlPathStrategy.path` に設定し、ルート定義がベースパスを考慮していることを確認してください。

## 2. 環境変数 (GEMINI_API_KEY) の管理

*   **Netlify の仕様:**
    *   Netlify の環境変数として設定された値を、ビルドスクリプト (`netlify_build.sh`) 内で直接参照し、`.env` ファイルとして出力していました。
*   **GitHub Pages (GitHub Actions 経由) の仕様:**
    *   GitHub Actions のワークフロー内で環境変数を安全に扱うには、GitHub Secrets を使用します。
*   **必要なコード修正/操作:**
    1.  **GitHub Secrets の設定:**
        *   GitHub リポジトリの「Settings」→「Secrets and variables」→「Actions」に移動し、`GEMINI_API_KEY` という名前で Gemini API キーをシークレットとして登録します。
    2.  **GitHub Actions ワークフローの変更:**
        *   ビルドステップの前に、GitHub Secrets から `GEMINI_API_KEY` を取得し、`.env` ファイルを生成するステップを追加します。
        *   **例 (GitHub Actions `deploy.yml` 内):**
            ```yaml
            - name: Create .env file for GEMINI_API_KEY
              run: echo "GEMINI_API_KEY=${{ secrets.GEMINI_API_KEY }}" > .env
              env:
                GEMINI_API_KEY: ${{ secrets.GEMINI_API_KEY }}
            ```
        *   Flutter アプリケーション内の `flutter_dotenv` パッケージによる `.env` ファイルの読み込みは、この変更後も引き続き機能します。

## 3. サーバーサイドロジック (Netlify Functions)

*   **Netlify の仕様:**
    *   `netlify/functions` ディレクトリに配置された JavaScript/TypeScript コードをサーバーレス関数として実行し、ランキング機能のバックエンドとして利用していました。
*   **GitHub Pages の仕様:**
    *   GitHub Pages は静的サイトホスティングサービスであり、サーバーサイドのコード実行環境を提供しません。
*   **必要なコード修正/操作:**
    1.  **Netlify Functions の移行:**
        *   `netlify/functions` 内の `get-ranking.js`, `submit-record.js`, `update-user.js` などの関数は、GitHub Pages では動作しません。
        *   これらの機能を維持するには、以下のいずれかの対応が必要です。
            *   **他のサーバーレスプラットフォームへの移行:** Vercel Functions, AWS Lambda, Google Cloud Functions など、別のサーバーレスサービスにこれらの関数を移行します。
            *   **Supabase の直接利用:** もし Netlify Functions が Supabase のプロキシとして機能していただけであれば、Flutter クライアントから直接 Supabase の API を呼び出すようにコードを修正します。この場合、Supabase の Row-Level Security (RLS) や認証メカニズムを適切に設定し、セキュリティを確保する必要があります。
    2.  **クライアントサイドコードの更新:**
        *   `lib/services/api_service.dart` など、Netlify Functions を呼び出していたクライアントサイドのコードを、新しいバックエンドのエンドポイント URL に合わせて更新する必要があります。

## 4. シングルページアプリケーション (SPA) のルーティングと 404 エラーハンドリング

*   **Netlify の仕様:**
    *   `_redirects` ファイルや `netlify.toml` の設定により、存在しないパスへのアクセスを `index.html` にリダイレクトし、SPA のクライアントサイドルーティングをサポートします。
*   **GitHub Pages の仕様:**
    *   デフォルトでは、存在しないパスにアクセスすると標準の 404 エラーページが表示されます。これにより、SPA の直接 URL アクセスやリロード時にルーティングが機能しなくなります。
*   **必要なコード修正/操作:**
    1.  **`404.html` ファイルの作成:**
        *   `build/web` ディレクトリ（デプロイされる静的ファイル群のルート）に `404.html` という名前のファイルを作成し、その内容を `index.html` と同じにします。
        *   これにより、GitHub Pages は 404 エラーが発生した際に `index.html` を提供し、Flutter アプリケーションのルーターがパスを処理できるようになります。
        *   これは GitHub Actions ワークフロー内で、ビルド後に `cp build/web/index.html build/web/404.html` のようなコマンドで実行できます。

## 5. ビルド環境のセットアップ (Flutter SDK)

*   **Netlify の仕様:**
    *   `netlify_build.sh` スクリプト内で、Flutter SDK を手動でクローンし、パスを設定していました。
*   **GitHub Pages (GitHub Actions 経由) の仕様:**
    *   GitHub Actions には、Flutter 環境のセットアップを簡素化する専用のアクションが提供されています。
*   **必要なコード修正/操作:**
    1.  **GitHub Actions ワークフローの変更:**
        *   `subosito/flutter-action@v2` アクションを使用することで、`netlify_build.sh` で行っていた Flutter SDK のクローンとパス設定の手順を置き換えることができます。
        *   **例 (GitHub Actions `deploy.yml` 内):**
            ```yaml
            - name: Setup Flutter
              uses: subosito/flutter-action@v2
              with:
                flutter-version: '3.x' # pubspec.yaml の SDK バージョンに合わせて調整
                channel: 'stable'
            ```

## 6. カスタムドメインの管理

*   **Netlify の仕様:**
    *   Netlify のダッシュボードでカスタムドメインを設定し、DNS レコードの管理も Netlify 側で行うことができました。
*   **GitHub Pages の仕様:**
    *   カスタムドメインを使用する場合、デプロイされるブランチのルートに `CNAME` ファイルを配置し、ドメインレジストラで DNS レコードを GitHub Pages に向ける必要があります。
*   **必要なコード修正/操作:**
    1.  **`CNAME` ファイルの作成:**
        *   カスタムドメインを使用する場合、`build/web` ディレクトリのルートに `CNAME` ファイルを作成し、その中にカスタムドメイン名（例: `your-custom-domain.com`）を記述します。
        *   GitHub Actions の `peaceiris/actions-gh-pages` アクションを使用する場合、`cname` オプションでドメインを指定することも可能です。
    2.  **DNS レコードの更新:**
        *   ドメインレジストラ（お名前.com, Cloudflare など）の管理画面で、DNS レコードを GitHub Pages の設定に合わせて更新します。具体的には、`A` レコードを GitHub Pages の IP アドレスに、または `CNAME` レコードを `your-github-username.github.io` に設定します。
