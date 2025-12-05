class QuizResult {
  final bool isCorrect;
  final String explanation;

  QuizResult({required this.isCorrect, required this.explanation});

  factory QuizResult.fromJson(Map<String, dynamic> json) {
    return QuizResult(
      isCorrect: json['isCorrect'] ?? false,
      explanation: json['explanation'] ?? '解説の取得に失敗しました。',
    );
  }
}
