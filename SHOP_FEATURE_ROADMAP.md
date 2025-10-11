
# 10連ガチャ結果画面での名言全文表示機能 実装ロードマップ

## 概要
10連ガチャの結果画面（`SequentialGachaFlowScreen`）で表示される名言をタップした際に、その名言の全文を詳細に表示するダイアログを追加します。

## ロードマップ

### ステップ 1: `SequentialGachaFlowScreen` の変更
*   **目的:** 名言表示部分をタップ可能にし、タップ時に全文表示ダイアログを表示する。
*   **ファイル:** `lib/gacha/screens/sequential_gacha_flow_screen.dart`
*   **変更内容:**
    1.  `build` メソッド内で、名言のテキスト (`item.text`) を囲む `Text` ウィジェットを `GestureDetector` でラップします。
    2.  `GestureDetector` の `onTap` プロパティで、`_showFullQuoteDialog(item)` のような新しいメソッドを呼び出します。
    3.  `_showFullQuoteDialog(GachaItem item)` メソッドを `_SequentialGachaFlowScreenState` クラスに追加します。このメソッドは `showDialog` を使用して、名言の全文と著者を表示する `AlertDialog` を表示します。

### ステップ 2: テストと検証
*   **目的:** 新機能が正しく動作し、既存機能に影響がないことを確認する。
*   **内容:**
    1.  10連ガチャを回します。
    2.  `SequentialGachaFlowScreen` で各名言が表示された際に、名言のテキスト部分をタップします。
    3.  タップした名言の全文と著者が表示されるダイアログが表示されることを確認します。
    4.  ダイアログを閉じると、元の `SequentialGachaFlowScreen` に戻ることを確認します。
    5.  既存のガチャ機能、ショップ機能、ぐっすりサタデー機能が引き続き正しく動作することを確認します。
