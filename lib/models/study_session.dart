/// A self-reported study session with confidence rating.
///
/// [confidence] is a subjective self-rating on a 1–5 scale
/// (1 = very low, 5 = very high). Out-of-range values are clamped.
/// [minutes] is the session duration in minutes, clamped to
/// `[0, maxMinutesPerDay]`.
///
/// [date] is stored as the exact timestamp at which the session was logged;
/// use [isToday] / [isWithin] for calendar comparisons rather than
/// comparing raw [DateTime]s.
class StudySession {
  StudySession({
    required String subject,
    required int minutes,
    required int confidence,
    required DateTime date,
  })  : subject = subject.trim(),
        minutes = _clampInt(minutes, 0, maxMinutesPerDay),
        confidence = _clampInt(confidence, minConfidence, maxConfidence),
        date = date;

  final String subject;
  final int minutes;
  final int confidence;
  final DateTime date;

  // ── Bounds ────────────────────────────────────────────────────────
  static const int minConfidence = 1;
  static const int maxConfidence = 5;
  static const int maxMinutesPerDay = 24 * 60;

  // ── Derived state ─────────────────────────────────────────────────
  /// Session duration as a [Duration].
  Duration get duration => Duration(minutes: minutes);

  /// Session duration in whole hours (truncated).
  int get hours => minutes ~/ 60;

  /// True when the session was logged on today's calendar date.
  bool get isToday => _sameDay(date, DateTime.now());

  /// True when [date] falls within `[start, end]`.
  bool isWithin(DateTime start, DateTime end) =>
      !date.isBefore(start) && !date.isAfter(end);

  /// Heuristic: a session is "productive" when it lasted at least 20
  /// minutes AND the user reported confidence ≥ 4. Not a substitute for
  /// real analytics; exposed for UI hints only.
  bool get isProductive => minutes >= 20 && confidence >= 4;

  /// Effective study weight: `minutes × confidence`. Useful for ranking
  /// sessions and aggregating weekly effort.
  int get minutesPerConfidence => minutes * confidence;

  // ── Copy ──────────────────────────────────────────────────────────
  StudySession copyWith({
    String? subject,
    int? minutes,
    int? confidence,
    DateTime? date,
  }) {
    return StudySession(
      subject: subject ?? this.subject,
      minutes: minutes ?? this.minutes,
      confidence: confidence ?? this.confidence,
      date: date ?? this.date,
    );
  }

  // ── JSON ──────────────────────────────────────────────────────────
  /// Emits native JSON types (ints, ISO-8601 string for `date`).
  ///
  /// ⚠️ The previous version emitted `Map<String, String>` with stringified
  /// integers. [fromJson] accepts both encodings, so persisted data round-
  /// trips cleanly. Any test that asserted `json['minutes'] == '30'` (string)
  /// must be updated to expect the int `30`.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'subject': subject,
        'minutes': minutes,
        'confidence': confidence,
        'date': date.toIso8601String(),
      };

  factory StudySession.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date'];
    final parsed = rawDate == null ? null : DateTime.tryParse(rawDate.toString());
    return StudySession(
      subject: (json['subject'] ?? '').toString(),
      minutes: _parseInt(json['minutes']),
      confidence: _parseInt(json['confidence'], fallback: 3),
      // Preserve the historical behavior: a missing/unparseable date
      // becomes "now" rather than failing the record.
      date: parsed ?? DateTime.now(),
    );
  }

  /// Best-effort parse that returns `null` for malformed entries instead
  /// of throwing, so one bad record cannot wipe the whole list.
  static StudySession? tryFromJson(Map<String, dynamic> json) {
    try {
      return StudySession.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  // ── Equality ──────────────────────────────────────────────────────
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudySession &&
          other.subject == subject &&
          other.minutes == minutes &&
          other.confidence == confidence &&
          other.date == date;

  @override
  int get hashCode => Object.hash(subject, minutes, confidence, date);

  @override
  String toString() => 'StudySession('
      'subject: "$subject", '
      'minutes: $minutes, '
      'confidence: $confidence, '
      'date: ${date.toIso8601String()})';

  // ── Helpers ───────────────────────────────────────────────────────
  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static int _clampInt(int value, int min, int max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  /// Accepts `int`, `double`/`num`, `String` (integer or decimal form), or
  /// `null`. Returns [fallback] for anything that cannot be coerced.
  static int _parseInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();
    final text = value.toString().trim();
    if (text.isEmpty) return fallback;
    final asInt = int.tryParse(text);
    if (asInt != null) return asInt;
    final asDouble = double.tryParse(text);
    if (asDouble != null) return asDouble.toInt();
    return fallback;
  }
}
