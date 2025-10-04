# ショップ機能 開発ロードマップ (詳細版)

## 1. 機能概要

- **目的:** スリープコインを使用して、ランキング画面の背景色を購入できる「ショップ機能」を実装する。
- **通貨:** 既存のスリープコインを利用する。
- **商品:** ランキング背景色。購入済みのものだけがプロフィール画面で設定可能になる。
- **価格:** 一律 1,000 スリープコイン。

---

## 2. 開発上の提案

1.  **スリープコインのサーバー管理:** 現在ローカル (`SharedPreferences`) に保存されているスリープコインを、Supabaseの`users`テーブルに移行し、データの永続性と安全性を確保する。
2.  **購入処理のトランザクション化:** SupabaseのEdge Function (RPC) を利用して、コインの増減とアイテムのアンロックを単一の安全なトランザクションとして実行することを推奨する。
3.  **デバッグ対応:** 新規ユーザー登録時、または特定のデバッグ操作により、初期スリープコインを10,000に設定する。

---

## 3. 詳細開発ロードマップ

### フェーズ1: バックエンドとデータモデルの変更 (Supabase)

*これらの作業はSupabase管理画面の "SQL Editor" から実行します。*

#### ステップ1.1: `users` テーブルの拡張

- **目的:** スリープコインをサーバーで管理するため、`users`テーブルに`sleep_coins`カラムを追加します。
- **SQL実行:**
  ```sql
  ALTER TABLE public.users
  ADD COLUMN sleep_coins INTEGER NOT NULL DEFAULT 0;
  ```

#### ステップ1.2: `user_unlocked_backgrounds` テーブルの新規作成

- **目的:** ユーザーが購入した背景を記録するための新しいテーブルを作成します。
- **SQL実行:**
  ```sql
  CREATE TABLE public.user_unlocked_backgrounds (
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    background_id TEXT NOT NULL,
    purchased_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, background_id)
  );
  ```

#### ステップ1.3: 購入処理用RPC関数の作成 (推奨)

- **目的:** 「コインを減らす」「アイテムをアンロックする」という2つの処理を、失敗が許されない単一の処理（トランザクション）としてまとめるため、安全な購入処理をサーバーサイドに実装します。
- **SQL実行:**
  ```sql
  CREATE OR REPLACE FUNCTION purchase_background(
    p_user_id UUID,
    p_background_id TEXT,
    p_cost INTEGER
  )
  RETURNS void AS $$
  DECLARE
    current_coins INTEGER;
  BEGIN
    -- ユーザーの現在のコイン残高を取得
    SELECT sleep_coins INTO current_coins FROM public.users WHERE id = p_user_id;

    -- 残高が足りるかチェック
    IF current_coins < p_cost THEN
      RAISE EXCEPTION 'insufficient_funds';
    END IF;

    -- コインを減算
    UPDATE public.users SET sleep_coins = current_coins - p_cost WHERE id = p_user_id;

    -- アンロック済みアイテムとして記録
    INSERT INTO public.user_unlocked_backgrounds (user_id, background_id) VALUES (p_user_id, p_background_id);

  END;
  $$ LANGUAGE plpgsql SECURITY DEFINER;
  ```

---

### フェーズ2: APIサービス層の拡張 (`lib/services/supabase_ranking_service.dart`)

#### ステップ2.1: `getUser` の拡張

- **目的:** ユーザー情報を取得する際に、コイン残高も取得できるようにします。
- **変更箇所:** `getUser`メソッド内の`select`文。
- **変更前:** `.select()`
- **変更後:** `.select('*, sleep_coins')` （`*`だけでも良いが、明示的に指定）

#### ステップ2.2: `getUnlockedBackgrounds` の新規作成

- **目的:** ユーザーが購入済みの背景IDリストを取得するメソッドを新設します。
- **コード追加:** `SupabaseRankingService`クラス内に以下のメソッドを追加します。

  ```dart
  Future<List<String>> getUnlockedBackgrounds(String userId) async {
    try {
      final response = await _supabase
          .from('user_unlocked_backgrounds')
          .select('background_id')
          .eq('user_id', userId);
      return response.map((item) => item['background_id'] as String).toList();
    } catch (e) {
      return []; // エラーの場合は空リストを返す
    }
  }
  ```

#### ステップ2.3: `purchaseBackground` の新規作成

- **目的:** フェーズ1.3で作成したRPC関数を呼び出すためのクライアント側メソッドを新設します。
- **コード追加:** `SupabaseRankingService`クラス内に以下のメソッドを追加します。

  ```dart
  Future<void> purchaseBackground(String backgroundId, int cost) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not logged in');
    }
    await _supabase.rpc('purchase_background', params: {
      'p_user_id': userId,
      'p_background_id': backgroundId,
      'p_cost': cost,
    });
  }
  ```

---

### フェーズ3: UIとロジックの実装

#### ステップ3.1: 商品カタログの定義

- **目的:** ショップで販売する商品を一元管理するため、モデルクラスとカタログリストを定義します。
- **新規ファイル作成:** `lib/models/shop_item.dart`

  ```dart
  import 'package:flutter/material.dart';

  class ShopItem {
    final String id;
    final String name;
    final int cost;
    final Color previewColor;

    const ShopItem({
      required this.id,
      required this.name,
      required this.cost,
      required this.previewColor,
    });
  }

  // 商品カタログ
  final List<ShopItem> backgroundShopCatalog = [
    const ShopItem(id: 'color_#ef5350', name: 'Red', cost: 1000, previewColor: Color(0xffef5350)),
    const ShopItem(id: 'color_#ec407a', name: 'Pink', cost: 1000, previewColor: Color(0xffec407a)),
    const ShopItem(id: 'color_#ff7043', name: 'Coral', cost: 1000, previewColor: Color(0xffff7043)),
    const ShopItem(id: 'color_#ffa726', name: 'Orange', cost: 1000, previewColor: Color(0xffffa726)),
    const ShopItem(id: 'color_#ffca28', name: 'Amber', cost: 1000, previewColor: Color(0xffffca28)),
    const ShopItem(id: 'color_#d4e157', name: 'Lime', cost: 1000, previewColor: Color(0xffd4e157)),
    const ShopItem(id: 'color_#9ccc65', name: 'Light Green', cost: 1000, previewColor: Color(0xff9ccc65)),
    const ShopItem(id: 'color_#66bb6a', name: 'Green', cost: 1000, previewColor: Color(0xff66bb6a)),
    const ShopItem(id: 'color_#26a69a', name: 'Teal', cost: 1000, previewColor: Color(0xff26a69a)),
    const ShopItem(id: 'color_#26c6da', name: 'Cyan', cost: 1000, previewColor: Color(0xff26c6da)),
    const ShopItem(id: 'color_#29b6f6', name: 'Light Blue', cost: 1000, previewColor: Color(0xff29b6f6)),
    const ShopItem(id: 'color_#5c6bc0', name: 'Indigo', cost: 1000, previewColor: Color(0xff5c6bc0)),
    const ShopItem(id: 'color_#7e57c2', name: 'Deep Purple', cost: 1000, previewColor: Color(0xff7e57c2)),
    const ShopItem(id: 'color_#8d6e63', name: 'Brown', cost: 1000, previewColor: Color(0xff8d6e63)),
  ];
  ```

#### ステップ3.2: ショップ画面の新規作成

- **目的:** 商品を一覧表示し、購入処理を行うための新しい画面を作成します。
- **新規ファイル作成:** `lib/screens/shop_screen.dart`
- **コード:** （長いため、骨子のみ。実際にはローディングやエラー処理を追加）

  ```dart
  import 'package:flutter/material.dart';
  import '../models/shop_item.dart';
  import '../services/supabase_ranking_service.dart';

  class ShopScreen extends StatefulWidget {
    const ShopScreen({super.key});
    @override
    State<ShopScreen> createState() => _ShopScreenState();
  }

  class _ShopScreenState extends State<ShopScreen> {
    final _supabaseService = SupabaseRankingService();
    late Future<List<String>> _unlockedItemsFuture;

    @override
    void initState() {
      super.initState();
      final userId = _supabaseService.getCurrentUserId(); // 仮のメソッド
      if (userId != null) {
        _unlockedItemsFuture = _supabaseService.getUnlockedBackgrounds(userId);
      } else {
        _unlockedItemsFuture = Future.value([]);
      }
    }

    void _buyItem(ShopItem item) async {
      // 購入処理とUI更新
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(title: const Text('ショップ')),
        body: FutureBuilder<List<String>>(
          future: _unlockedItemsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final unlockedIds = snapshot.data ?? [];
            return ListView.builder(
              itemCount: backgroundShopCatalog.length,
              itemBuilder: (context, index) {
                final item = backgroundShopCatalog[index];
                final isUnlocked = unlockedIds.contains(item.id);
                return ListTile(
                  leading: CircleAvatar(backgroundColor: item.previewColor),
                  title: Text(item.name),
                  subtitle: Text('${item.cost} C'),
                  trailing: isUnlocked
                      ? const Icon(Icons.check, color: Colors.green)
                      : ElevatedButton(onPressed: () => _buyItem(item), child: const Text('購入')),
                );
              },
            );
          },
        ),
      );
    }
  }
  ```

#### ステップ3.3: ホーム画面の修正 (`lib/screens/home_screen.dart`)

- **目的:** ホーム画面からショップ画面へ遷移するボタンを設置します。
- **変更箇所:** `build`メソッド内の`AppBar`の`actions`リスト。
- **コード追加:** `actions`の先頭に以下の`IconButton`を追加します。

  ```dart
  actions: [
    IconButton(
      icon: const Icon(Icons.store_outlined),
      onPressed: () {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ShopScreen()));
      },
    ),
    // ... existing icons
  ],
  ```

#### ステップ3.4: プロフィール画面の修正 (`lib/screens/profile_screen.dart`)

- **目的:** コイン残高をサーバーと同期し、購入済みの背景のみを選択できるようにします。
- **`_loadProfileData`の修正:** ローカルのコイン(`prefs.getInt`)を削除し、`getUser`で取得したサーバー上の`sleep_coins`を`_sleepCoins`にセットします。
- **`onTap`背景選択の修正:** `showModalBottomSheet`を呼び出す前に、`getUnlockedBackgrounds`で取得したIDリストを使い、`backgroundOptions`をフィルタリングします。`default`と`white`は購入不要なため、常に選択肢に含めます。

#### ステップ3.5: デバッグ機能の実装 (`profile_screen.dart`)

- **目的:** 新規ユーザー登録時に、**開発環境（デバッグモード）でのみ**テスト用の初期コインを付与します。
- **必要なimport:** `import 'package:flutter/foundation.dart';` をファイルの先頭に追加します。
- **変更箇所:** `profile_screen.dart`の`_saveProfile`メソッド内の、`userId`を新規生成するブロック。
- **コード追加:** `updateUser`を呼び出す際に、`kDebugMode`をチェックして初期コインの額を決定します。

  ```dart
  // profile_screen.dart -> _saveProfile()

  if (_isRankingEnabled && currentUserId == null) {
    currentUserId = const Uuid().v4();
    await prefs.setString('userId', currentUserId);
    setState(() => _userId = currentUserId);

    // ★デバッグモードの場合のみ、初期コインを10,000付与
    int initialCoins = 0;
    if (kDebugMode) {
      initialCoins = 10000;
    }

    await _supabaseService.updateUser(
      id: currentUserId,
      username: _usernameController.text,
      sleepCoins: initialCoins, // 決定した初期コイン額を渡す
    );
  } else if (_isRankingEnabled && currentUserId != null) {
    // ... 既存の更新処理
  }
  ```

---

### フェーズ4: テストと検証

1.  新規ユーザーでアプリを起動し、プロフィール画面でスリープコインが10,000になっていることを確認する。
2.  ホーム画面のショップアイコンからショップ画面に遷移できることを確認する。
3.  ショップで背景アイテムを購入し、コインが減算されること、およびアイテムが「購入済み」になることを確認する。
4.  プロフィール画面に戻り、背景選択肢に購入したアイテムが追加されていることを確認する。
5.  購入した背景を設定し、ランキング画面で正しく表示されることを確認する。
6.  コインが足りない状態でアイテムを購入しようとし、エラーメッセージが表示されることを確認する。

---

## 開発実行ログ

### 2025年10月4日

- **フェーズ1: バックエンドとデータモデルの変更**
  - **状態:** 完了 ✅
  - **詳細:** `users`テーブルに`sleep_coins`カラムを追加。`user_unlocked_backgrounds`テーブルを新規作成。`purchase_background` RPC関数を作成。ユーザーによりSupabaseコンソールでのSQL実行が確認された。

- **フェーズ2: APIサービス層の拡張**
  - **状態:** 完了 ✅
  - **詳細:** `supabase_ranking_service.dart`に、ショップ機能に必要な`getCurrentUserId`, `getUnlockedBackgrounds`, `purchaseBackground`の3メソッドを追加した。`getUser`は既存の`select()`で全カラム取得可能だったため、修正は不要と判断。

- **フェーズ3: UIとロジックの実装**
  - **ステップ3.1: 商品カタログの定義:** 完了 ✅
    - **詳細:** `lib/models/shop_item.dart`を作成し、`ShopItem`クラスと販売対象となる背景色のリスト`backgroundShopCatalog`を定義した。

  - **ステップ3.2: ショップ画面の新規作成:** 完了 ✅
    - **詳細:** `lib/screens/shop_screen.dart`を作成。コイン残高の表示、商品リストの表示、購入済みかどうかの判定、購入ボタンのロジックを含む画面の雛形を実装した。

  - **ステップ3.3: ホーム画面の修正:** 完了 ✅
    - **詳細:** `home_screen.dart`のAppBarに、ショップ画面へ遷移するための`IconButton` (`Icons.store_outlined`) を追加した。

  - **ステップ3.4: プロフィール画面の修正:** 完了 ✅
    - **詳細:** `_loadProfileData`を修正し、コイン残高をローカルではなくサーバーから取得するように変更。また、背景選択モーダルには`default`と`white`に加えて購入済みの背景のみが表示されるようにロジックを修正した。

  - **ステップ3.5: デバッグ機能の実装:** 完了 ✅
    - **詳細:** `profile_screen.dart`の`_saveProfile`メソッドを修正。`kDebugMode`を使い、新規ユーザー登録がデバッグモードで行われた場合に限り、初期コイン10,000を付与するロジックを実装した。これに伴い、`supabase_ranking_service.dart`の`updateUser`メソッドも`sleepCoins`を更新できるように拡張した。
    - **補足:** `updateUser`メソッドの実装中に、Dartの型推論によるコンパイルエラーが発生したため、`updateData`の型を`Map<String, dynamic>`と明示的に宣言して修正した。

- **フェーズ3(改善): ショップ画面のUI改善**
  - **状態:** 完了 ✅
  - **詳細:** `shop_screen.dart`のレイアウトを、縦一列の`ListView`から、画面サイズに応じて列数が変わるレスポンシブな`GridView`に変更した。これにより、視認性と操作性が向上した。

  - **追加改善:** ショップ画面に`TabBar`を導入し、「背景色」タブを設置。将来的な商品カテゴリ追加に対応できる拡張性を持たせつつ、現在の商品の内容を明確化した。

  - **追加改善:** 購入ボタンタップ時に確認ダイアログを表示するように修正。誤操作による意図しない購入を防ぐようにした。

  - **コンテンツ追加:** ショップに販売する背景色として、新たにパステルカラー5色を追加した。
