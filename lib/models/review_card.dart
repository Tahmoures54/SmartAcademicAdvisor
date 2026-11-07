import 'dart:math' as math;

/// Spaced-repetition flashcard stored on device.
///
/// Interval progression for consecutive "known" answers:
///   `0 → 1 → 3 → 6 → 12 → 24 → 48 → 60` (capped at [maxIntervalDays]).
/// Any "unknown" answer resets [interval] to 1 and increments [wrong].
/// [correct] and [wrong] are lifetime counters and are never reset.
///
/// [due] holds an exact timestamp (not midnight), so "is it due?" respects
/// the time-of-day the review was applied. Use [isDueToday] for a
/// calendar-day check.
class ReviewCard {
  ReviewCard({
    required String subject,
    required String prompt,
    required String answer,
    int interval = 0,
    DateTime? due,
    int correct = 0,
    int wrong = 0,
  })  : subject = subject.trim(),
        prompt = prompt.trim(),
        answer = answer.trim(),
        interval = _sanitizeNonNegative(interval),
        due = due ?? DateTime.now(),
        correct = _sanitizeNonNegative(correct),
        wrong = _sanitizeNonNegative(wrong);

  final String subject;
  final String prompt;
  final String answer;
  int interval;
  DateTime due;
  int correct;
  int wrong;

  /// Upper bound on [interval] in days.
  static const int maxIntervalDays = 60;

  // ── Derived state ─────────────────────────────────────────────────
  /// True when this card has never been reviewed.
  bool get isNew => interval == 0;

  /// True when [due] has been reached (now or earlier, to the microsecond).
  bool get isDue => !due.isAfter(DateTime.now());

  /// True when the due date falls strictly before today (local calendar).
  bool get isOverdue {
    final now = DateTime.now();
    return due.isBefore(DateTime(now.year, now.month, now.day));
  }

  /// True when [due] falls on today's calendar date.
  bool get isDueToday => _sameDay(due, DateTime.now());

  /// Lifetime review count.
  int get totalReviews => correct + wrong;

  /// Fraction of reviews answered correctly, in `[0.0, 1.0]`.
  /// Zero for a card that has never been reviewed.
  double get accuracy =>
      totalReviews == 0 ? 0.0 : correct / totalReviews;

  /// The interval the next review would produce, without mutating state.
  int previewNextInterval({required bool known}) =>
      nextIntervalFor(interval, known: known);

  // ── Spaced-repetition math (pure) ─────────────────────────────────
  /// Computes the next interval from [currentInterval]. Pure function;
  /// safe to call for previews and tests.
  static int nextIntervalFor(int currentInterval, {required bool known}) {
    if (!known) return 1;
    if (currentInterval <= 0) return 1;
    if (currentInterval == 1) return 3;
    return math.min(currentInterval * 2, maxIntervalDays);
  }

  /// Applies a review outcome and updates [interval], [due], and counters.
  ///
  /// Pass [at] to inject a deterministic clock in tests; omit it to use
  /// [DateTime.now].
  void applyReview({required bool known, DateTime? at}) {
    interval = nextIntervalFor(interval, known: known);
    due = (at ?? DateTime.now()).add(Duration(days: interval));
    if (known) {
      correct += 1;
    } else {
      wrong += 1;
    }
  }

  // ── Copy ──────────────────────────────────────────────────────────
  ReviewCard copyWith({
    String? subject,
    String? prompt,
    String? answer,
    int? interval,
    DateTime? due,
    int? correct,
    int? wrong,
  }) {
    return ReviewCard(
      subject: subject ?? this.subject,
      prompt: prompt ?? this.prompt,
      answer: answer ?? this.answer,
      interval: interval ?? this.interval,
      due: due ?? this.due,
      correct: correct ?? this.correct,
      wrong: wrong ?? this.wrong,
    );
  }

  // ── JSON ──────────────────────────────────────────────────────────
  /// Emits native JSON types (ints, ISO-8601 string for `due`).
  ///
  /// ⚠️ The previous version emitted `Map<String, String>` with stringified
  /// integers. [fromJson] accepts both encodings, so persisted data round-
  /// trips cleanly. Any test that asserted `json['interval'] == '3'` (string)
  /// must be updated to expect the int `3`.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'subject': subject,
        'prompt': prompt,
        'answer': answer,
        'interval': interval,
        'due': due.toIso8601String(),
        'correct': correct,
        'wrong': wrong,
      };

  factory ReviewCard.fromJson(Map<String, dynamic> json) {
    return ReviewCard(
      subject: (json['subject'] ?? '').toString(),
      prompt: (json['prompt'] ?? '').toString(),
      answer: (json['answer'] ?? '').toString(),
      interval: _parseInt(json['interval']),
      due: _parseDate(json['due']),
      correct: _parseInt(json['correct']),
      wrong: _parseInt(json['wrong']),
    );
  }

  /// Best-effort parse that returns `null` for malformed entries instead of
  /// throwing, so one bad record cannot wipe the whole list.
  static ReviewCard? tryFromJson(Map<String, dynamic> json) {
    try {
      return ReviewCard.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  // ── Equality ──────────────────────────────────────────────────────
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReviewCard &&
          other.subject == subject &&
          other.prompt == prompt &&
          other.answer == answer &&
          other.interval == interval &&
          other.due == due &&
          other.correct == correct &&
          other.wrong == wrong;

  @override
  int get hashCode => Object.hash(
        subject,
        prompt,
        answer,
        interval,
        due,
        correct,
        wrong,
      );

  @override
  String toString() => 'ReviewCard('
      'subject: "$subject", '
      'prompt: ${prompt.length} chars, '
      'interval: ${interval}d, '
      'due: ${due.toIso8601String()}, '
      'correct: $correct, wrong: $wrong)';

  // ── Helpers ───────────────────────────────────────────────────────
  static int _sanitizeNonNegative(int value) => value < 0 ? 0 : value;

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Accepts `int`, `double`/`num`, `String` (integer or decimal form), or
  /// `null`. Returns `0` for anything that cannot be coerced.
  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    final text = value.toString().trim();
    if (text.isEmpty) return 0;
    final asInt = int.tryParse(text);
    if (asInt != null) return asInt;
    final asDouble = double.tryParse(text);
    if (asDouble != null) return asDouble.toInt();
    return 0;
  }

  /// Accepts `DateTime`, ISO-8601 string, or `null`. Returns `null` for
  /// anything unparseable so the constructor can fall back to `now`.
  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}
