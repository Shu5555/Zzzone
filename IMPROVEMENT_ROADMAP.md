# Zzzoneアプリ 改善ロードマップ

## 1. はじめに

このドキュメントは、Zzzoneアプリケーションのコードベースを調査し、発見された潜在的な問題点を修正するための一連の手順をまとめたものです。主な目的は、アプリケーションの堅牢性を向上させ、ユーザー体験を改善することです。

**主な改善項目:**
- **API通信の堅牢性向上:** タイムアウトとエラーハンドリングを強化します。
- **データ整合性の確保:** 手動記録作成時のデータ重複を防止します。
- **タイムゾーン問題の解消:** ランキング機能が全てのタイムゾーンで正しく機能するように修正します。
- **データ送信の最適化:** 冗長なデータ送信処理を削除します。
- **PWA設定の修正:** インストール時のアプリ名を修正します。

---

## 2. Part 1: API通信の堅牢性向上

### 目的
サーバーとの通信時にタイムアウトを設定し、エラー発生時にユーザーへフィードバックを提供できるようにします。

### 手順 1/2: `api_service.dart` の修正

`http`リクエストにタイムアウトを追加し、エラー発生時に例外をスローするように変更します。

**ファイル:** `lib/services/api_service.dart`

```diff
- import 'package:http/http.dart' as http;
- import 'dart:convert';
+ import 'package:http/http.dart' as http;
+ import 'dart:convert';
+ import 'dart:async'; // TimeoutExceptionのため

 class ApiService {
   final String _baseUrl = 'https://zzzone.netlify.app/.netlify/functions';
+  final _timeoutDuration = const Duration(seconds: 10);

   /// ユーザー情報を更新または作成する
   Future<void> updateUser(String id, String username) async {
-    try {
-      final response = await http.post(
-        Uri.parse('$_baseUrl/update-user'),
-        headers: {'Content-Type': 'application/json'},
-        body: jsonEncode({'id': id, 'username': username}),
-      );
-      if (response.statusCode != 200) {
-        // エラーハンドリング（例: ログ出力）
-        print('Failed to update user: ${response.body}');
-      }
-    } catch (e) {
-      print('Error calling updateUser: $e');
+    try {
+      final response = await http.post(
+        Uri.parse('$_baseUrl/update-user'),
+        headers: {'Content-Type': 'application/json'},
+        body: jsonEncode({'id': id, 'username': username}),
+      ).timeout(_timeoutDuration);
+
+      if (response.statusCode != 200) {
+        // エラーハンドリングを強化
+        throw Exception('Failed to update user: ${response.statusCode} ${response.body}');
+      }
+    } on TimeoutException {
+      throw Exception('Connection timed out. Please try again.');
+    } catch (e) {
+      // 呼び出し元で処理できるように再スロー
+      rethrow;
     }
   }

   /// 睡眠記録を送信する
   Future<void> submitRecord(String userId, int sleepDuration, String date) async {
-    try {
-      final response = await http.post(
-        Uri.parse('$_baseUrl/submit-record'),
-        headers: {'Content-Type': 'application/json'},
-        body: jsonEncode({
-          'user_id': userId,
-          'sleep_duration': sleepDuration,
-          'date': date,
-        }),
-      );
-      if (response.statusCode != 201) {
-        print('Failed to submit record: ${response.body}');
-      }
-    } catch (e) {
-      print('Error calling submitRecord: $e');
+    try {
+      final response = await http.post(
+        Uri.parse('$_baseUrl/submit-record'),
+        headers: {'Content-Type': 'application/json'},
+        body: jsonEncode({
+          'user_id': userId,
+          'sleep_duration': sleepDuration,
+          'date': date,
+        }),
+      ).timeout(_timeoutDuration);
+
+      if (response.statusCode != 201) {
+        throw Exception('Failed to submit record: ${response.statusCode} ${response.body}');
+      }
+    } on TimeoutException {
+      throw Exception('Connection timed out. Please try again.');
+    } catch (e) {
+      rethrow;
     }
   }

   /// ランキングデータを取得する
-  Future<List<Map<String, dynamic>>> getRanking() async {
-    try {
-      final response = await http.get(Uri.parse('$_baseUrl/get-ranking'));
-      if (response.statusCode == 200) {
-        // UTF-8でデコードしてからJSONをパースする
-        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
-        return data.cast<Map<String, dynamic>>();
-      } else {
-        print('Failed to get ranking: ${response.body}');
-        return [];
-      }
-    } catch (e) {
-      print('Error calling getRanking: $e');
-      return [];
+  Future<List<Map<String, dynamic>>> getRanking(String date) async {
+    try {
+      final uri = Uri.parse('$_baseUrl/get-ranking?date=$date');
+      final response = await http.get(uri).timeout(_timeoutDuration);
+      if (response.statusCode == 200) {
+        // UTF-8でデコードしてからJSONをパースする
+        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
+        return data.cast<Map<String, dynamic>>();
+      } else {
+        // エラー時は空リストではなく例外をスロー
+        throw Exception('Failed to get ranking: ${response.statusCode} ${response.body}');
+      }
+    } on TimeoutException {
+      throw Exception('Connection timed out. Please try again.');
+    } catch (e) {
+      rethrow;
     }
   }
 }
```

### 手順 2/2: `settings_screen.dart` の修正

`ApiService`からの例外を`try-catch`で捕捉し、ユーザーにエラーメッセージを表示します。

**ファイル:** `lib/screens/settings_screen.dart`

**変更箇所 1: `_updateSettingsOnExit` メソッド**
```diff
   Future<void> _updateSettingsOnExit() async {
     final prefs = await SharedPreferences.getInstance();
     final currentUsername = _userNameController.text;
 
     // Save username locally
     await prefs.setString('userName', currentUsername);
 
     // Sync username with server if it has changed and user is participating
     if (_rankingParticipation && _userId != null && currentUsername != _initialUserName) {
-      await _apiService.updateUser(_userId!, currentUsername);
+      try {
+        await _apiService.updateUser(_userId!, currentUsername);
+      } catch (e) {
+        // Since this happens on exit, we can't easily show a snackbar.
+        // Logging the error is the most practical approach.
+        print('Failed to update username on exit: $e');
+      }
     }
   }
```

**変更箇所 2: `_saveRankingParticipation` メソッド**
```diff
   Future<void> _saveRankingParticipation(bool value) async {
     final prefs = await SharedPreferences.getInstance();
     await prefs.setBool('rankingParticipation', value);
     setState(() {
       _rankingParticipation = value;
     });
 
-    // First time opting in
-    if (value && _userId == null) {
-      final newUserId = const Uuid().v4();
-      await prefs.setString('userId', newUserId);
-      setState(() {
-        _userId = newUserId;
-      });
-      // Register user on the server
-      await _apiService.updateUser(newUserId, _userNameController.text);
-
-      if (mounted) {
-        ScaffoldMessenger.of(context).showSnackBar(
-          const SnackBar(content: Text('ランキング用のIDを生成し、ユーザー情報を登録しました')),
-        );
-      }
-    } else if (value && _userId != null) {
-      // Re-opting in, just sync the current state
-      await _apiService.updateUser(_userId!, _userNameController.text);
+    // Wrap API calls in try-catch
+    try {
+      // First time opting in
+      if (value && _userId == null) {
+        final newUserId = const Uuid().v4();
+        await prefs.setString('userId', newUserId);
+        setState(() {
+          _userId = newUserId;
+        });
+        // Register user on the server
+        await _apiService.updateUser(newUserId, _userNameController.text);
+
+        if (mounted) {
+          ScaffoldMessenger.of(context).showSnackBar(
+            const SnackBar(content: Text('ランキング用のIDを生成し、ユーザー情報を登録しました')),
+          );
+        }
+      } else if (value && _userId != null) {
+        // Re-opting in, just sync the current state
+        await _apiService.updateUser(_userId!, _userNameController.text);
+      }
+    } catch (e) {
+      if (mounted) {
+        ScaffoldMessenger.of(context).showSnackBar(
+          SnackBar(content: Text('エラー: ユーザー情報の更新に失敗しました。\n${e.toString()}')),
+        );
+        // Revert the switch state on failure
+        setState(() {
+          _rankingParticipation = !value;
+        });
+        await prefs.setBool('rankingParticipation', !value);
+      }
     }
   }
```

### 動作確認テスト
1.  **正常系:** アプリを通常通りオンラインで操作し、設定画面でユーザー名を変更したり、ランキングへの参加スイッチを切り替えたりしてもエラーが表示されないことを確認します。
2.  **異常系（オフライン）:** デバイスのWi-Fiやモバイルデータをオフにします。
3.  その状態で、設定画面を開き「ランキングに参加する」スイッチをONにしようとします。
4.  画面下部に「Connection timed out...」または「ネットワークに接続できません...」といった内容のエラーメッセージがSnackBarで表示され、スイッチがONにならず元の状態に戻ることを確認します。

---

## 3. Part 2: 手動記録の重複防止

### 目的
手動記録画面で、既に記録が存在する日付に新しい記録を保存できないようにします。

### 手順 1/1: `manual_sleep_entry_screen.dart` の修正

保存処理の前に、選択された日付にデータが存在するかをチェックするロジックを追加します。

**ファイル:** `lib/screens/manual_sleep_entry_screen.dart`

```diff
   Future<void> _saveRecord() async {
+    // Check for duplicates before saving
+    final logicalDateToSave = getLogicalDate(_selectedDate);
+    final allRecords = await DatabaseHelper.instance.readAllRecords();
+    final isDuplicate = allRecords.any((record) => getLogicalDate(record.sleepTime) == logicalDateToSave);
+
+    if (isDuplicate) {
+      if (mounted) {
+        ScaffoldMessenger.of(context).showSnackBar(
+          const SnackBar(content: Text('この日付の記録は既に存在します。履歴画面から編集してください。')),
+        );
+      }
+      return;
+    }
+
     final totalMinutes = _selectedHours * 60 + _selectedMinutes;
     if (totalMinutes <= 0) {
-      ScaffoldMessenger.of(context).showSnackBar(
-        const SnackBar(content: Text('睡眠時間は0より大きくしてください。')),
-      );
+      if (mounted) {
+        ScaffoldMessenger.of(context).showSnackBar(
+          const SnackBar(content: Text('睡眠時間は0より大きくしてください。')),
+        );
+      }
       return;
     }
 
     final sleepTime = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 0, 0);
     final wakeUpTime = sleepTime.add(Duration(minutes: totalMinutes));
 
-    // ▼▼▼ 入力値を使ってSleepRecordを生成 ▼▼▼
     final newRecord = SleepRecord(
       sleepTime: sleepTime,
       wakeUpTime: wakeUpTime,
       score: _score.round(),
       performance: _performance,
-      hadDaytimeDrowsiness: false, // この項目は手動入力画面にないためデフォルト値
-      hasAchievedGoal: false, // 目標達成は自動計算されないためデフォルト値
+      hadDaytimeDrowsiness: false, 
+      hasAchievedGoal: false, 
       memo: _memoController.text,
       didNotOversleep: _didNotOversleep,
     );
 
     await DatabaseHelper.instance.create(newRecord);
 
+    // Submit to ranking if the date is today
     final logicalTodayString = getLogicalDateString(DateTime.now());
     final selectedDateString = getLogicalDateString(_selectedDate);
 
     if (logicalTodayString == selectedDateString) {
-      final prefs = await SharedPreferences.getInstance();
-      final userId = prefs.getString('userId');
-      if (userId != null && userId.isNotEmpty) {
-        ApiService().submitRecord(userId, totalMinutes, selectedDateString);
+      try {
+        final prefs = await SharedPreferences.getInstance();
+        final userId = prefs.getString('userId');
+        if (userId != null && userId.isNotEmpty) {
+          await ApiService().submitRecord(userId, totalMinutes, selectedDateString);
+        }
+      } catch (e) {
+        print('Failed to submit manual record to ranking: $e');
+        // Do not show error to user as it is not critical
       }
     }
 
     if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('記録を保存しました')),
       );
       Navigator.of(context).pop();
     }
   }
```

### 動作確認テスト
1.  **重複なしの場合:** 履歴画面にまだ記録がない日付を選び、手動記録画面から睡眠を記録します。正常に保存され、履歴画面に反映されることを確認します。
2.  **重複ありの場合:** 既に記録が存在する日付（例: 昨日）を再度選択し、手動記録画面から保存を試みます。
3.  画面下部に「この日付の記録は既に存在します。履歴画面から編集してください。」というメッセージがSnackBarで表示され、記録が追加作成されないことを確認します。

---

## 4. Part 3: タイムゾーン問題の解消

### 目的
ランキング機能がJST（日本標準時）に固定されている問題を解消し、全てのユーザーが自身のタイムゾーンに基づいた「今日」のランキングを閲覧できるようにします。

### 手順 1/3: `get-ranking.js` の修正 (サーバーサイド)

APIがクライアントから日付をクエリパラメータで受け取れるようにします。

**ファイル:** `netlify/functions/get-ranking.js`

```diff
-
-const { createClient } = require('@supabase/supabase-js');
-
-// JST基準で「論理的な日付」を取得するヘルパー関数
-function getLogicalDateInJST() {
-  const now = new Date();
-  // タイムゾーンオフセットを考慮してJSTに変換 (UTC+9)
-  const jstNow = new Date(now.getTime() + (9 * 60 * 60 * 1000));
-
-  // JSTの午前4時より前なら、日付を1日前に設定
-  if (jstNow.getUTCHours() < 4) {
-    jstNow.setUTCDate(jstNow.getUTCDate() - 1);
-  }
-
-  // YYYY-MM-DD形式で日付を返す
-  return jstNow.toISOString().slice(0, 10);
-}
+const { createClient } = require('@supabase/supabase-js');
+
+// フォールバックとしてJST基準の「論理的な日付」を取得するヘルパー関数
+function getFallbackDateInJST() {
+  const now = new Date();
+  // タイムゾーンオフセットを考慮してJSTに変換 (UTC+9)
+  const jstNow = new Date(now.getTime() + (9 * 60 * 60 * 1000));
+
+  // JSTの午前4時より前なら、日付を1日前に設定
+  if (jstNow.getUTCHours() < 4) {
+    jstNow.setUTCDate(jstNow.getUTCDate() - 1);
+  }
+
+  // YYYY-MM-DD形式で日付を返す
+  return jstNow.toISOString().slice(0, 10);
+}
 
 exports.handler = async function(event, context) {
   const supabase = createClient(process.env.SUPABASE_URL, process.env.ANON_KEY);
-  const today = getLogicalDateInJST(); // <--- ヘルパー関数を呼び出す
-
-  // 1. 今日のレコードをすべて、作成時刻の新しい順に取得する
+  
+  let targetDate;
+  const clientDate = event.queryStringParameters?.date;
+  const dateFormat = /^\d{4}-\d{2}-\d{2}$/;
+
+  if (clientDate && dateFormat.test(clientDate)) {
+    targetDate = clientDate;
+  } else {
+    // クライアントから日付が指定されない場合はJSTをフォールバックとして使用
+    targetDate = getFallbackDateInJST();
+  }
+
+  // 1. 対象日のレコードをすべて、作成時刻の新しい順に取得する
   const { data: records, error } = await supabase
     .from('sleep_records')
     .select(`
       sleep_duration,
       created_at,
       users!left ( id, username )
     `)
-    .eq('date', today)
+    .eq('date', targetDate)
     .order('created_at', { ascending: false });
 
   if (error) {
     return { statusCode: 500, body: JSON.stringify({ message: error.message }) };
   }
...
```

### 手順 2/3: `api_service.dart` の修正

`getRanking`メソッドが日付を引数に取り、APIリクエストに含めるようにします。（この修正はPart 1で実施済みのため、コードは最終形を再掲）

**ファイル:** `lib/services/api_service.dart`

```dart
// ... (省略) ...
  /// ランキングデータを取得する
  Future<List<Map<String, dynamic>>> getRanking(String date) async {
    try {
      final uri = Uri.parse('$_baseUrl/get-ranking?date=$date');
      final response = await http.get(uri).timeout(_timeoutDuration);
      if (response.statusCode == 200) {
        // UTF-8でデコードしてからJSONをパースする
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.cast<Map<String, dynamic>>();
      } else {
        // エラー時は空リストではなく例外をスロー
        throw Exception('Failed to get ranking: ${response.statusCode} ${response.body}');
      }
    } on TimeoutException {
      throw Exception('Connection timed out. Please try again.');
    } catch (e) {
      rethrow;
    }
  }
}
```

### 手順 3/3: `ranking_screen.dart` の修正

ランキング画面を開く際に、デバイスの「今日」の日付を`getRanking`メソッドに渡します。

**ファイル:** `lib/screens/ranking_screen.dart`

```diff
-import 'package:flutter/material.dart';
-import '../services/api_service.dart';
+import 'package:flutter/material.dart';
+import '../services/api_service.dart';
+import '../utils/date_helper.dart'; // Import the date helper

 class RankingScreen extends StatefulWidget {
   const RankingScreen({super.key});

   @override
   State<RankingScreen> createState() => _RankingScreenState();
 }

 class _RankingScreenState extends State<RankingScreen> {
   late Future<List<Map<String, dynamic>>> _rankingFuture;

   @override
   void initState() {
     super.initState();
-    _rankingFuture = ApiService().getRanking();
+    // Pass today's logical date to the getRanking method
+    _rankingFuture = ApiService().getRanking(getLogicalDateString(DateTime.now()));
   }
...
```

### 動作確認テスト
1.  **UI確認:** ランキング画面を開き、エラーが表示されずに正常に画面が表示されること（データがない場合は「ランキングデータがまだありません」と表示されること）を確認します。
2.  **サーバーログ確認（推奨）:** Netlifyの管理画面から、`get-ranking`関数のログを監視します。
3.  アプリのランキング画面を開いた際に、ログに `.../?date=YYYY-MM-DD` のように、アプリを実行しているデバイスの現在日付がクエリパラメータとして渡されていることを確認します。

---

## 5. Part 4: データ二重送信問題の修正

### 目的
睡眠記録を保存する際に、データがサーバーへ2回送信される冗長な処理を修正し、通信を1回に統一します。

### 原因
データ保存時、UIスクリーン（`post_sleep_input_screen.dart` と `manual_sleep_entry_screen.dart`）と、その内部で呼び出される `DatabaseHelper` クラスの両方から、同じデータ送信APIが呼び出されていました。

### 手順 1/2: `post_sleep_input_screen.dart` の修正

UIスクリーンからの直接的なAPI呼び出しを削除し、データ送信を `DatabaseHelper` の責務に一本化します。

**ファイル:** `lib/screens/post_sleep_input_screen.dart`

```diff
// ... (inside _saveRecord method)
      if (isEditing) {
        recordToSave = SleepRecord(
          id: widget.initialRecord!.id,
          sleepTime: widget.initialRecord!.sleepTime,
          wakeUpTime: widget.initialRecord!.wakeUpTime,
          score: _score.round(),
          performance: _performance,
          hadDaytimeDrowsiness: widget.initialRecord!.hadDaytimeDrowsiness,
          hasAchievedGoal: achieved,
          memo: _memoController.text,
          didNotOversleep: _didNotOversleep,
        );
        await DatabaseHelper.instance.update(recordToSave);
      } else {
        recordToSave = SleepRecord(
          sleepTime: widget.sleepTime!,
          wakeUpTime: widget.wakeUpTime!,
          score: _score.round(),
          performance: _performance,
          hadDaytimeDrowsiness: false,
          hasAchievedGoal: achieved,
          memo: _memoController.text,
          didNotOversleep: _didNotOversleep,
        );
        recordToSave = await DatabaseHelper.instance.create(recordToSave);
      }

-      final userId = prefs.getString('userId');
-      if (userId != null && userId.isNotEmpty) {
-        final sleepDuration = wakeUpTime.difference(sleepTime).inMinutes;
-        final dateString = getLogicalDateString(sleepTime);
-
-        // ランキングサーバーに記録を送信（エラーはUIには影響させない）
-        ApiService().submitRecord(userId, sleepDuration, dateString);
-      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('記録を保存しました')));
// ...
```

### 手順 2/2: `manual_sleep_entry_screen.dart` の修正

同様に、手動入力画面からの直接的なAPI呼び出しも削除します。

**ファイル:** `lib/screens/manual_sleep_entry_screen.dart`

```diff
// ... (inside _saveRecord method)
    await DatabaseHelper.instance.create(newRecord);

-    // Submit to ranking if the date is today
-    final logicalTodayString = getLogicalDateString(DateTime.now());
-    final selectedDateString = getLogicalDateString(_selectedDate);
-
-    if (logicalTodayString == selectedDateString) {
-      try {
-        final prefs = await SharedPreferences.getInstance();
-        final userId = prefs.getString('userId');
-        if (userId != null && userId.isNotEmpty) {
-          await ApiService().submitRecord(userId, totalMinutes, selectedDateString);
-        }
-      } catch (e) {
-        print('Failed to submit manual record to ranking: $e');
-        // Do not show error to user as it is not critical
-      }
-    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
// ...
```

### 動作確認テスト
1.  **サーバーログ確認の準備:** Netlifyの管理画面から、`submit-record`関数のログをリアルタイムで監視できる状態にします。
2.  **自動計測での確認:**
    a. アプリで「睡眠を開始」し、数秒後に「起床する」をタップします。
    b. 評価入力画面で内容を入力し、「記録を保存」をタップします。
    c. サーバーログを確認し、`submit-record`関数が **1回だけ** 呼び出されていることを確認します。
3.  **手動記録での確認:**
    a. 手動入力画面から記録を作成し、「この内容で保存」をタップします。
    b. サーバーログを確認し、`submit-record`関数が **1回だけ** 呼び出されていることを確認します。

---

## 6. Part 5: PWAのアプリ名修正

### 目的
WebアプリをPWA（Progressive Web App）としてデバイスにインストールした際に、アプリ名がデフォルトの `sleep_management_app` ではなく「Zzzone」と正しく表示されるように修正します。

### 原因
Webアプリのマニフェストファイル `web/manifest.json` に設定されているアプリ名が、Flutterプロジェクト作成時のデフォルト名のままになっているためです。

### 手順 1/1: `manifest.json` の修正

`name` および `short_name` プロパティを `Zzzone` に変更します。

**ファイル:** `web/manifest.json`

**修正後の内容:**
```json
{
    "name": "Zzzone",
    "short_name": "Zzzone",
    "start_url": ".",
    "display": "standalone",
    "background_color": "#0175C2",
    "theme_color": "#0175C2",
    "description": "A new Flutter project.",
    "orientation": "portrait-primary",
    "prefer_related_applications": false,
    "icons": [
        {
            "src": "icons/Icon-192.png",
            "sizes": "192x192",
            "type": "image/png"
        },
        {
            "src": "icons/Icon-512.png",
            "sizes": "512x512",
            "type": "image/png"
        },
        {
            "src": "icons/Icon-maskable-192.png",
            "sizes": "192x192",
            "type": "image/png",
            "purpose": "maskable"
        },
        {
            "src": "icons/Icon-maskable-512.png",
            "sizes": "512x512",
            "type": "image/png",
            "purpose": "maskable"
        }
    ]
}
```

### 動作確認テスト
1.  `flutter build web` コマンドを実行して、Webアプリケーションをビルドします。
2.  ビルドされた資材（`build/web` ディレクトリ）をWebサーバーにデプロイします。
3.  スマートフォンのブラウザ（Chrome on Android, Safari on iOS）でデプロイされたURLにアクセスします。
4.  ブラウザのメニューから「ホーム画面に追加」または「Appをインストール」といった項目を選択します。
5.  インストール確認のダイアログ、およびスマートフォンのホーム画面に表示されるアプリアイコンの名称が、`sleep_management_app` ではなく **「Zzzone」** になっていることを確認します。

---

## 7. まとめ

以上の手順を実行することで、アプリケーションの信頼性が向上し、より多くのユーザーにとって快適に利用できる状態になります。各修正は独立していますが、順番に適用することを推奨します。