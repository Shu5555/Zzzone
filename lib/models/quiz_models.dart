class Quiz {
  final String title;
  final String category;
  final String question;
  final String? hint;

  Quiz({
    required this.title,
    required this.category,
    required this.question,
    this.hint,
  });

  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      title: json['title'] ?? 'クイズ',
      category: json['category'] ?? '睡眠知識',
      question: json['question'] ?? '',
      hint: json['hint'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'category': category,
      'question': question,
      'hint': hint,
    };
  }
}

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
