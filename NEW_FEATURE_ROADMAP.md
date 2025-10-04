## 新機能開発ロードマップ: プロフィール背景設定 (詳細版)

ユーザーからの提案に基づき、以下の新機能開発を計画します。

### 目的
ランキング画面において、ユーザーが自身の背景を設定できるようにすることで、自己表現の幅を広げ、アプリ利用の楽しみを深める。

---

### 開発ロードマップ

#### ステップ1: バックエンドの準備 (Supabase)

`users` テーブルに、選択された背景の識別子を保存するためのカラムを追加します。この作業はSupabaseの管理画面の "SQL Editor" から実行します。

- **実行するSQL:**
  ```sql
  -- 背景設定を保存するカラムを追加 (例: 'bg_pattern_01', 'color_blue' など)
  -- デフォルト値を設定しておくと、既存ユーザーに対するNullハンドリングが楽になります
  ALTER TABLE public.users
  ADD COLUMN background_preference TEXT DEFAULT 'default';
  ```

---

#### ステップ2: フロントエンドの準備 (Flutter)

背景として使用する画像アセットをプロジェクトに追加し、アプリが認識できるように設定します。

1.  **ディレクトリ作成:**
    - `assets` フォルダ内に `images` を作成し、さらにその中に `backgrounds` ディレクトリを作成します。
    - パス: `assets/images/backgrounds/`

2.  **アセット配置:**
    - 作成したディレクトリに、背景用の画像ファイル（例: `pattern_01.png`, `pattern_02.png`）を配置します。
    - 同時に、背景選択UIで使うためのサムネイル画像も用意すると、よりリッチなUIになります。

3.  **`pubspec.yaml` の更新:**
    - `flutter` セクションに、作成したアセットディレクトリへのパスを追記します。

    ```yaml
    flutter:
      uses-material-design: true
      assets:
        - assets/data/quotes.json
        - .env
        - assets/images/backgrounds/ # <-- この行を追記
    ```

---

#### ステップ3: APIサービスの拡張 (`lib/services/supabase_ranking_service.dart`)

Supabaseと通信する処理を拡張し、背景設定の取得と更新に対応します。

1.  **ランキング取得処理の修正:**
    - `getRanking` メソッド内の `select` 文を修正し、`users` テーブルから `background_preference` を取得できるようにします。

    ```dart
    // 変更前
    .select('sleep_duration, created_at, users!inner(id, username)')

    // 変更後
    .select('sleep_duration, created_at, users!inner(id, username, background_preference)')
    ```

2.  **ユーザー情報更新処理の拡張:**
    - `updateUser` メソッドに `backgroundPreference` というオプショナルな引数を追加し、`upsert` するデータに含めます。

    ```dart
    // lib/services/supabase_ranking_service.dart

    Future<void> updateUser({required String id, required String username, String? backgroundPreference}) async {
      if (username.length > 20) {
        throw Exception('Username cannot be longer than 20 characters');
      }
      try {
        final updateData = {
          'id': id,
          'username': username,
        };

        if (backgroundPreference != null) {
          updateData['background_preference'] = backgroundPreference;
        }

        await _supabase.from('users').upsert(
          updateData,
          onConflict: 'id',
        );
      } on PostgrestException catch (e) {
        if (e.code == '23505') { // unique_violation
          throw Exception('このユーザー名は既に使用されています。');
        }
        rethrow;
      }
    }
    ```

---

#### ステップ4: プロフィール画面の実装 (`lib/screens/profile_screen.dart`)

ユーザーが背景を選択・保存できるUIを実装します。

1.  **状態変数の追加:**
    - 選択されている背景IDを管理するための状態変数を `_ProfileScreenState` に追加します。

    ```dart
    String _selectedBackground = 'default';
    ```

2.  **UIの追加:**
    - `build` メソッド内の `Column` に、背景設定用の `ListTile` を追加します。

    ```dart
    // lib/screens/profile_screen.dart -> build() -> Column

    const Divider(),
    ListTile(
      leading: const Icon(Icons.palette_outlined),
      title: const Text('ランキングの背景'),
      subtitle: const Text('全国ランキングに表示される背景を選択'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        // TODO: 背景選択ダイアログを表示する処理を実装
      },
    ),
    const Divider(),
    ```

3.  **保存処理の修正:**
    - `_saveProfile` メソッドを修正し、`updateUser` を呼び出す際に選択した背景ID (`_selectedBackground`) を渡すようにします。

    ```dart
    // lib/screens/profile_screen.dart -> _saveProfile()

    await _supabaseService.updateUser(
      id: currentUserId,
      username: _usernameController.text,
      backgroundPreference: _selectedBackground, // <-- この引数を追加
    );
    ```

---

#### ステップ5: ランキング画面の実装 (`lib/screens/ranking_screen.dart`)

各ユーザーの背景をランキングリストに描画します。

1.  **データ取得:**
    - `itemBuilder` 内で、`background_preference` の値を取得します。

    ```dart
    // lib/screens/ranking_screen.dart -> itemBuilder

    final entry = rankingData[index];
    final username = entry['users']?['username'] ?? '名無しさん';
    final backgroundId = entry['users']?['background_preference'] as String? ?? 'default';
    ```

2.  **UIの修正:**
    - `Card` を `Container` でラップし、`decoration` プロパティで背景画像を設定します。
    - 可読性確保のため、`foregroundDecoration` でグラデーションをかけます。

    ```dart
    // lib/screens/ranking_screen.dart -> itemBuilder

    return Card(
      elevation: rank <= 3 ? 4.0 : 1.0,
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      clipBehavior: Clip.antiAlias, // decorationを適用するために必要
      child: Container( // <-- Cardの子をContainerに
        decoration: BoxDecoration(
          image: DecorationImage(
            // backgroundIdに応じて画像パスを動的に変更
            image: AssetImage('assets/images/backgrounds/$backgroundId.png'), 
            fit: BoxFit.cover,
          ),
        ),
        foregroundDecoration: BoxDecoration(
          // 文字を読みやすくするための黒いグラデーション
          gradient: LinearGradient(
            colors: [Colors.black.withOpacity(0.6), Colors.transparent],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            stops: const [0.0, 0.7],
          ),
        ),
        child: ListTile(
          // ... (既存のListTileの内容)
          // 文字色を白系統にすると見やすくなります
          title: Text(username, style: titleStyle?.copyWith(color: Colors.white) ?? const TextStyle(color: Colors.white)),
          // ...
        ),
      ),
    );
    ```

---

以上が、より詳細な実装ロードマップです。