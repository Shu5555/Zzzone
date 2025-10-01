# LLM活用・睡眠分析機能 実装ロードマップ (Ver 3.0)

## 1. 概要

本ドキュメントは、睡眠管理アプリ「Zzzone」に、LLMを活用した新しい睡眠分析機能を実装するための最終版ロードマップです。
ここに記載されているロードマップは、別の開発環境をもとに作成されています。必要に応じて、現在の開発環境をもとにロードマップの再構築を行ってください。

もし、変更履歴に書いてあるが、実際には変更されていない場合は、その内容を実行する。
また、変更内容はその都度、正確かつ詳細にこのテキストファイルに追加記述しなければならない。

### 1.1. V3.0での最終仕様

-   **自動表示:** 睡眠記録が5件以上ある場合、分析レポート画面を開くと**自動で**分析結果が表示されます。
-   **ボタンの廃止:** ユーザーによる「分析」「再分析」ボタン操作は不要です。
-   **スマート自動分析:** LLMによる再分析は、**睡眠データに更新があった場合のみ**自動で実行されます。データに変更がなければ、前回保存した結果を即座に表示することで、表示速度とコスト効率を最大化します。

### 1.2. アーキテクチャ概要

-   **フロントエンド (Flutter):**
    -   **ローカルキャッシュ:** 最新の分析結果、分析日時、そして**分析の元となった最新の睡眠記録ID**を端末に保存します。
    -   **UI:** 画面初期化時に、条件（記録数、データ更新）に応じて「分析結果」「ローディング表示」「案内メッセージ」のいずれかを自動で表示します。
-   **バックエンド (Netlify Functions):** (V1.0から変更なし)
-   **LLMサービス (Google Geminiなど):** (V1.0から変更なし)

---

## 2. 事前準備

-   **LLM APIキーの取得**と**Netlify環境変数への設定**を完了させてください。
    -   **Key:** `GEMINI_API_KEY`

---

## 3. 実装ステップ

### 3.1. バックエンド編 (Netlify Function)

**(V1.0, V2.0から変更なし)**

-   `netlify/functions/analyze-sleep.js` は、POSTされた睡眠データ群をLLMで分析し、結果をJSONで返す責務を担います。こちらの仕様に変更はありません。

### 3.2. フロントエンド編 (Flutter)

**目標:** 画面表示時に、記録数とデータ更新の有無をチェックし、表示内容（キャッシュ/新規分析/案内）を自動で決定するロジックを実装する。

1.  **依存関係の確認:**
    -   `pubspec.yaml` に `http`, `shared_preferences`, `intl` が含まれていることを確認します。

2.  **データモデルの更新 (`lib/models/analysis_cache.dart`):**
    -   キャッシュに、分析の元となったデータセットを識別するため `latestRecordId` を追加します。
        ```dart
        class AnalysisCache {
          final Map<String, dynamic> analysisResult;
          final DateTime timestamp;
          final int latestRecordId; // 分析対象のうち、最も新しい睡眠記録のID

          AnalysisCache({
            required this.analysisResult,
            required this.timestamp,
            required this.latestRecordId, // 追加
          });

          // fromJson, toJson も latestRecordId を含めるように更新
          factory AnalysisCache.fromJson(Map<String, dynamic> json) {
            return AnalysisCache(
              analysisResult: json['analysisResult'],
              timestamp: DateTime.parse(json['timestamp']),
              latestRecordId: json['latestRecordId'], // 追加
            );
          }

          Map<String, dynamic> toJson() {
            return {
              'analysisResult': analysisResult,
              'timestamp': timestamp.toIso8601String(),
              'latestRecordId': latestRecordId, // 追加
            };
          }
        }
        ```

3.  **キャッシュ管理サービスの更新 (`lib/services/cache_service.dart`):**
    -   `saveAnalysis` メソッドが `latestRecordId` を受け取れるように変更します。
        ```dart
        class CacheService {
          // ...
          Future<void> saveAnalysis(Map<String, dynamic> result, int latestRecordId) async {
            final prefs = await SharedPreferences.getInstance();
            final cache = AnalysisCache(
              analysisResult: result,
              timestamp: DateTime.now(),
              latestRecordId: latestRecordId,
            );
            await prefs.setString(_key, jsonEncode(cache.toJson()));
          }
          // loadAnalysisは変更なし
        }
        ```

4.  **分析レポート画面の全面改修 (`lib/screens/analysis_report_screen.dart`):**
    -   `AnalysisReportView` を `StatefulWidget` にします。
    -   `initState` で、すべてのロジックをキックオフします。
        ```dart
        @override
        void initState() {
          super.initState();
          _triggerAnalysisCheck();
        }
        ```
    -   画面の状態を管理する変数を定義します。
        ```dart
        enum ReportState { loading, success, error }
        ReportState _state = ReportState.loading;
        Map<String, dynamic>? _analysisResult;
        String _message = ''; // エラーや案内メッセージ用
        ```
    -   中核ロジック `_triggerAnalysisCheck` を実装します。
        ```dart
        Future<void> _triggerAnalysisCheck() async {
          // 1. 記録件数をチェック
          final records = await DatabaseHelper.instance.getLatestRecords(limit: 100); // 分析対象件数を適宜設定
          if (records.length < 5) {
            setState(() {
              _state = ReportState.error;
              _message = '分析には5件以上の睡眠記録が必要です。';
            });
            return;
          }

          // 2. キャッシュと最新記録IDを比較
          final cachedData = await CacheService().loadAnalysis();
          final currentLatestRecordId = records.first.id!;

          if (cachedData != null && cachedData.latestRecordId == currentLatestRecordId) {
            // 3a. キャッシュが有効な場合：キャッシュから表示
            setState(() {
              _analysisResult = cachedData.analysisResult;
              _state = ReportState.success;
            });
          } else {
            // 3b. キャッシュがない、またはデータが古い場合：再分析を実行
            try {
              final newResult = await AnalysisService().fetchSleepAnalysis(records);
              await CacheService().saveAnalysis(newResult, currentLatestRecordId);
              setState(() {
                _analysisResult = newResult;
                _state = ReportState.success;
              });
            } catch (e) {
              setState(() {
                _state = ReportState.error;
                _message = '分析データの取得に失敗しました。\n時間をおいて再度お試しください。';
              });
            }
          }
        }
        ```
    -   `build` メソッドで、`_state` の値に応じてUIを切り替えます。
        ```dart
        @override
        Widget build(BuildContext context) {
          switch (_state) {
            case ReportState.loading:
              return const Center(child: CircularProgressIndicator());
            case ReportState.error:
              return Center(child: Text(_message));
            case ReportState.success:
              if (_analysisResult == null) return const Center(child: Text('予期せぬエラーが発生しました。'));
              // _analysisResult を使って分析結果(総評、改善案)を
              // Cardなどを使ってきれいに表示するUIをここに記述
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ... 総評表示 ...
                    // ... 改善案表示 ...
                  ],
                ),
              );
          }
        }
        ```

---

以上が、ご要望をすべて反映した最終版のロードマップです。この実装により、ユーザーは何も意識することなく、常に適切で最新の分析結果を閲覧できるようになります。

### 4. 変更履歴
- 2025-10-01:
  - `lib/services/analysis_service.dart`: Gemini APIを直接呼び出すようにサービスを書き換え、APIキーをハードコード。（非推奨の構成）
  - `lib/models/analysis_cache.dart`: 分析結果をキャッシュするためのデータモデルを新規作成。
  - `lib/services/cache_service.dart`: キャッシュの保存・読込を行うサービスを新規作成。
  - `lib/models/sleep_record.dart`: `toMapForAnalysis`メソッドを追加。
  - `lib/screens/analysis_report_screen.dart`: LLMによる自動分析とキャッシュ表示を行うようにUIとロジックを全面改修。
  - `netlify/functions/analyze-sleep.js`, `netlify/functions/package.json`: 上記変更に伴い、関連するバックエンドファイルを削除。