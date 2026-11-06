/// A locally stored exam or school test entry.
class Exam {
  Exam({
    required this.subject,
    required this.date,
    this.score = '',
  });

  final String subject;
  final DateTime date;
  final String score;

  factory Exam.fromJson(Map<String, dynamic> json) {
    return Exam(
      subject: (json['subject'] ?? '').toString(),
      date: DateTime.parse(json['date'].toString()),
      score: (json['score'] ?? '').toString(),
    );
  }

  Map<String, String> toJson() => {
        'subject': subject,
        'date': date.toIso8601String(),
        'score': score,
      };

  Exam copyWith({String? subject, DateTime? date, String? score}) {
    return Exam(
      subject: subject ?? this.subject,
      date: date ?? this.date,
      score: score ?? this.score,
    );
  }
}
