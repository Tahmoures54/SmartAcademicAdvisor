/// Spaced-repetition flashcard stored on device.
class ReviewCard {
  ReviewCard({
    required this.subject,
    required this.prompt,
    required this.answer,
    this.interval = 0,
    DateTime? due,
    this.correct = 0,
    this.wrong = 0,
  }) : due = due ?? DateTime.now();

  final String subject;
  final String prompt;
  final String answer;
  int interval;
  DateTime due;
  int correct;
  int wrong;

  factory ReviewCard.fromJson(Map<String, dynamic> json) {
    return ReviewCard(
      subject: (json['subject'] ?? '').toString(),
      prompt: (json['prompt'] ?? '').toString(),
      answer: (json['answer'] ?? '').toString(),
      interval: int.tryParse((json['interval'] ?? '0').toString()) ?? 0,
      due: DateTime.tryParse((json['due'] ?? '').toString()) ?? DateTime.now(),
      correct: int.tryParse((json['correct'] ?? '0').toString()) ?? 0,
      wrong: int.tryParse((json['wrong'] ?? '0').toString()) ?? 0,
    );
  }

  Map<String, String> toJson() => {
        'subject': subject,
        'prompt': prompt,
        'answer': answer,
        'interval': interval.toString(),
        'due': due.toIso8601String(),
        'correct': correct.toString(),
        'wrong': wrong.toString(),
      };

  void applyReview({required bool known}) {
    final previous = interval;
    interval = known
        ? (previous == 0
            ? 1
            : previous == 1
                ? 3
                : (previous * 2).clamp(1, 60))
        : 1;
    due = DateTime.now().add(Duration(days: interval));
    if (known) {
      correct += 1;
    } else {
      wrong += 1;
    }
  }
}
