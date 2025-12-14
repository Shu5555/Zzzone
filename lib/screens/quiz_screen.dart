import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart'; // Import flutter_markdown_plus
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/quiz_models.dart';
import '../services/quiz_service.dart';
import '../services/supabase_ranking_service.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final QuizService _quizService = QuizService();
  final SupabaseRankingService _rankingService = SupabaseRankingService();
  final TextEditingController _answerController = TextEditingController();

  bool _isLoading = false;
  String? _quizQuestion;
  QuizResult? _quizResult;
  String? _error;
  bool _isSubmitting = false;

  static const String _quizQuestionKey = 'daily_quiz_question';
  static const String _quizDateKey = 'daily_quiz_date';
  static const String _quizUserAnswerKey = 'daily_quiz_user_answer';
  static const String _quizResultIsCorrectKey = 'daily_quiz_result_is_correct';
  static const String _quizResultExplanationKey = 'daily_quiz_result_explanation';

  @override
  void initState() {
    super.initState();
    _checkTodaysQuiz();
  }

  /// Check if a quiz has already been fetched for today and display it.
  Future<void> _checkTodaysQuiz() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final storedDate = prefs.getString(_quizDateKey);

    if (storedDate == today) {
      final storedQuestion = prefs.getString(_quizQuestionKey);
      final storedAnswer = prefs.getString(_quizUserAnswerKey);
      final storedResultIsCorrect = prefs.getBool(_quizResultIsCorrectKey);
      final storedResultExplanation = prefs.getString(_quizResultExplanationKey);

      setState(() {
        _quizQuestion = storedQuestion;
        if (storedAnswer != null) {
          _answerController.text = storedAnswer;
        }
        if (storedResultIsCorrect != null && storedResultExplanation != null) {
          _quizResult = QuizResult(
            isCorrect: storedResultIsCorrect,
            explanation: storedResultExplanation,
          );
        }
      });
    }
  }

  Future<void> _fetchQuiz() async {
    setState(() {
      _isLoading = true; // Show loading indicator when fetching
      _error = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final storedDate = prefs.getString(_quizDateKey);

    // Check again in case the button is pressed on a new day without restarting the app
    if (storedDate == today) {
      setState(() {
        _quizQuestion = prefs.getString(_quizQuestionKey);
        _isLoading = false;
      });
      return;
    }

    if (!_quizService.isModelReady()) {
      setState(() {
        _error = 'クイズ機能は現在利用できません。\nAIモデルが準備されているか、APIキーが設定されているか確認してください。';
        _isLoading = false;
      });
      return;
    }
    try {
      // Clear old data when fetching a new quiz for a new day
      await prefs.remove(_quizUserAnswerKey);
      await prefs.remove(_quizResultIsCorrectKey);
      await prefs.remove(_quizResultExplanationKey);

      final question = await _quizService.getDailyQuiz();
      await prefs.setString(_quizQuestionKey, question);
      await prefs.setString(_quizDateKey, today);
      setState(() {
        _quizQuestion = question;
        _quizResult = null; // Reset result
        _answerController.clear(); // Clear old answer
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _submitAnswer() async {
    if (_answerController.text.isEmpty || _quizQuestion == null) {
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final result = await _quizService.submitAnswer(_quizQuestion!, _answerController.text);
      
      // Save the answer and result to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_quizUserAnswerKey, _answerController.text);
      await prefs.setBool(_quizResultIsCorrectKey, result.isCorrect);
      await prefs.setString(_quizResultExplanationKey, result.explanation);

      setState(() {
        _quizResult = result;
      });

      if (result.isCorrect) {
        try {
          String? userId = Supabase.instance.client.auth.currentUser?.id;

          if (userId == null) {
             final prefs = await SharedPreferences.getInstance();
             userId = prefs.getString('userId');
          }
          
          if (userId != null) {
            await _rankingService.updateSleepCoins(userId: userId, coinsToAdd: 100);
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('正解！ 100 スリープコインを獲得しました！')),
              );
            }
          }
        } catch (e) {
          debugPrint('Error awarding coins: $e');
          // Optionally show an error message to the user, but keep quiz flow intact
        }
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zzzoneクイズ'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _error!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _fetchQuiz,
              child: const Text('再試行'),
            )
          ],
        ),
      );
    }
    
    // If quiz is not loaded yet, show "Ask Quiz" button
    if (_quizQuestion == null) {
      return Center(
        child: ElevatedButton(
          onPressed: _fetchQuiz,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            textStyle: const TextStyle(fontSize: 20),
          ),
          child: const Text('クイズを出題'),
        ),
      );
    }

    // If quiz is loaded, show the quiz UI
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('今日のクイズ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(_quizQuestion!, style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _answerController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'あなたの回答',
            ),
            enabled: _quizResult == null, // Disable after submitting
          ),
          const SizedBox(height: 24),
          if (_isSubmitting)
            const Center(child: CircularProgressIndicator())
          else
            ElevatedButton(
              onPressed: _quizResult == null ? _submitAnswer : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
              ),
              child: const Text('回答を提出する'),
            ),
          const SizedBox(height: 24),
          if (_quizResult != null) _buildResultView(),
        ],
      ),
    );
  }

  Widget _buildResultView() {
    if (_quizResult == null) {
      return const SizedBox.shrink();
    }
    return Card(
      color: Colors.black, // Changed to black
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _quizResult!.isCorrect ? '正解！' : '不正解',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _quizResult!.isCorrect ? Colors.greenAccent[400] : Colors.redAccent[400], // Lighter colors for contrast
              ),
            ),
            const Divider(height: 24, color: Colors.white54), // Add color to divider
            const Text('解説', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)), // Text color to white
            const SizedBox(height: 8),
            Markdown(
              data: _quizResult!.explanation,
              shrinkWrap: true, // Add this to constrain the height
              physics: const NeverScrollableScrollPhysics(), // Prevent nested scrolling
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(fontSize: 16, height: 1.5, color: Colors.white70),
                strong: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                // Add more styles if needed for other markdown elements (e.g., em, h1, etc.)
                // Inherit from current context's TextTheme where appropriate
              ),
              // To handle links, if any
              onTapLink: (text, href, title) {
                // Handle link tap, e.g., launch URL
              },
            ),
          ],
        ),
      ),
    );
  }
}