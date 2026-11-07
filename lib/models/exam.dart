/// A locally stored exam or school test entry.
///
/// The [date] is normalized to local midnight so two exams on the same
/// calendar day compare equal regardless of the time component, and so
/// [daysUntil] / [isToday] / [isPast] behave intuitively.
class Exam {
  Exam({
    required String subject,
    required DateTime date,
    String score = '',
  })  : subject = subject.trim(),
        date = _dateOnly(date),
        score = score.trim();

  final String subject;
  final DateTime date;
  final String score;

  // ── JSON ──────────────────────────────────────────────────────────
  factory Exam.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date'];
    if (rawDate == null) {
      throw const FormatException('Exam.date is missing');
    }
    final parsed = DateTime.tryParse(rawDate.toString());
    if (parsed == null) {
      throw FormatException('Exam.date is not a valid ISO-8601 string: $rawDate');
    }
    return Exam(
      subject: (json['subject'] ?? '').toString(),
      date: parsed,
      score: (json['score'] ?? '').toString(),
    );
  }

  /// Best-effort parse used when loading persisted data. Returns `null`
  /// for malformed entries instead of throwing, so one bad record cannot
  /// wipe the whole list.
  static Exam? tryFromJson(Map<String, dynamic> json) {
    try {
      return Exam.fromJson(json);
    } on FormatException {
      return null;
    } on Object {
      return null;
    }
  }

  Map<String, String> toJson() => <String, String>{
        'subject': subject,
        'date': date.toIso8601String(),
        'score': score,
      };

  // ── Copy ──────────────────────────────────────────────────────────
  /// Returns a new [Exam]. Pass `score: ''` to clear the score; passing
  /// `null` (the default) keeps the current value.
  Exam copyWith({String? subject, DateTime? date, String? score}) {
    return Exam(
      subject: subject ?? this.subject,
      date: date ?? this.date,
      score: score ?? this.score,
    );
  }

  // ── Derived state ─────────────────────────────────────────────────
  bool get hasScore => score.isNotEmpty;

  /// Numeric value of [score] when it parses as a number.
  ///
  /// Accepts Latin, Persian (`۰-۹`), and Arabic-Indic (`٠-٩`) digits, plus
  /// the Arabic decimal separator `٫`. Returns `null` for non-numeric
  /// labels such as "غایب" or "حاضر".
  num? get numericScore {
    final normalized = _normalizeDigits(score).replaceAll('٫', '.');
    if (normalized.isEmpty) return null;
    return num.tryParse(normalized);
  }

  bool get isToday => _isSameDay(date, DateTime.now());

  /// True when the exam date is strictly before today (local time).
  bool get isPast => date.isBefore(_dateOnly(DateTime.now()));

  /// True when the exam is scheduled for a future calendar day.
  bool get isUpcoming => !isPast && !isToday;

  /// Signed day difference between today and the exam.
  /// `0` = today, positive = future, negative = past.
  int get daysUntil =>
      date.difference(_dateOnly(DateTime.now())).inDays;

  // ── Equality ──────────────────────────────────────────────────────
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Exam &&
          other.subject == subject &&
          other.date == date &&
          other.score == score;

  @override
  int get hashCode => Object.hash(subject, date, score);

  @override
  String toString() =>
      'Exam(subject: "$subject", date: ${date.toIso8601String()}, '
      'score: "$score")';

  // ── Helpers ───────────────────────────────────────────────────────
  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _normalizeDigits(String input) {
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      final p = persian.indexOf(ch);
      if (p >= 0) {
        buffer.write(p);
        continue;
      }
      final a = arabic.indexOf(ch);
      if (a >= 0) {
        buffer.write(a);
        continue;
      }
      buffer.write(ch);
    }
    return buffer.toString();
  }
}
