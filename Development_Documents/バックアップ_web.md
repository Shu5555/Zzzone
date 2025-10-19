# Zzzone Web版 - Dropboxバックアップ機能 (In-Memory) 実装ロードマップ

## 概要
Webブラウザの制約（ローカルファイルアクセス不可、DBがインメモリ）に対応するため、モバイル版の「ファイル（.db）をZIP化する」方式とは異なる、「**DBデータをJSONとしてメモリ上で送受信する**」方式のバックアップ機能を実装します。

このロードマップは、既存のDropbox認証基盤（フェーズA）およびAPIクライアント（フェーズB）が実装済みであることを前提としています。
また、このロードマップは現在の開発環境と異なる環境で作成されました。そのため、自身の環境に合わせて変更してください。

---

## フェーズ1: Web認証のセットアップ

WebブラウザからのOAuth 2.0認証を許可するための設定を行います。

### タスク1.1: Dropbox App Console に Web用URIを登録
-   Dropbox App Console (`https://www.dropbox.com/developers/apps`) を開きます。
-   Zzzoneアプリの「Settings」タブにある「OAuth 2」セクションの「**Redirect URIs**」を編集します。
-   **以下2つのURIを追加します:**
    1.  **開発用URI:** `http://localhost:[ポート番号]/` (例: `http://localhost:5000/`) ※Flutter Webのデバッグ実行ポートに合わせてください。
    2.  **本番用URI:** `https://[あなたのWebアプリのドメイン]/` (例: `https://zzzone.app/`)

### タスク1.2: 既存の認証ロジックの調整（`flutter_web_auth`）
-   `flutter_web_auth` を使用している場合、`authenticate` メソッドの `callbackUrlScheme` はWebでは無視されます。
-   `redirect_uri` パラメータに、`kIsWeb` 定数（FlutterのWeb判定）で分岐させたURIを指定するようにします。

```dart
// 認証呼び出し部分のイメージ
import 'package:flutter/foundation.dart' show kIsWeb;

// ...

final String mobileRedirectUri = 'zzzoneauth://callback';
final String webRedirectUri = kDebugMode ? 'http://localhost:5000/' : '[https://zzzone.app/](https://zzzone.app/)';

final String redirectUri = kIsWeb ? webRedirectUri : mobileRedirectUri;

final String url = '[https://www.dropbox.com/oauth2/authorize](https://www.dropbox.com/oauth2/authorize)'
    '?client_id=YOUR_APP_KEY'
    '&response_type=code'
    '&redirect_uri=$redirectUri'
    '&code_challenge=...' // PKCEチャレンジ
    '&code_challenge_method=S256';

final result = await FlutterWebAuth.authenticate(
  url: url,
  callbackUrlScheme: kIsWeb ? '' : 'zzzoneauth', // Webではスキーム不要
);