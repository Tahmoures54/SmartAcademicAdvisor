/// A self-reported study session with confidence rating.
class StudySession {
  StudySession({
    required this.subject,
    required this.minutes,
    required this.confidence,
    required this.date,
  });

  final String subject;
  final int minutes;
  final int confidence;
  final DateTime date;

  factory StudySession.fromJson(Map<String, dynamic> json) {
    return StudySession(
      subject: (json['subject'] ?? '').toString(),
      minutes: int.tryParse((json['minutes'] ?? '0').toString()) ?? 0,
      confidence: int.tryParse((json['confidence'] ?? '3').toString()) ?? 3,
      date: DateTime.tryParse((json['date'] ?? '').toString()) ?? DateTime.now(),
    );
  }

  Map<String, String> toJson() => {
        'subject': subject,
        'minutes': minutes.toString(),
        'confidence': confidence.toString(),
        'date': date.toIso8601String(),
      };
}
