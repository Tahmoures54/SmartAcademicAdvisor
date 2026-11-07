import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/exam.dart';
import '../models/planner_snapshot.dart';
import '../models/review_card.dart';
import '../models/study_session.dart';

/// Loads and persists planner data with the same preference keys as before.
///
/// Defensive design:
///   • A corrupt JSON value under any single key is silently dropped and
///     replaced with an empty default, so one bad write cannot wipe the
///     entire planner on the next launch.
///   • Per-item model parsing uses `tryFromJson` so a single malformed exam,
///     session, or flashcard does not fail the whole list.
///   • [clear] removes only this store's keys; it does NOT call
///     `SharedPreferences.clear()`, which would also wipe unrelated app and
///     plugin state (session tokens, theme, onboarding flags, etc.).
class LocalStore {
  static const stageKey = 'profile_stage';
  static const goalKey = 'profile_goal';
  static const tasksKey = 'study_tasks';
  static const completedKey = 'completed_tasks';
  static const dueDatesKey = 'study_task_due_dates';
  static const notesKey = 'study_notes';
  static const examsKey = 'study_exams';
  static const sessionsKey = 'study_sessions';
  static const reviewCardsKey = 'study_review_cards';

  /// All keys owned by this store. Used by [clear] to avoid the nuclear
  /// option of `SharedPreferences.clear()`.
  static const List<String> _ourKeys = <String>[
    stageKey,
    goalKey,
    tasksKey,
    completedKey,
    dueDatesKey,
    notesKey,
    examsKey,
    sessionsKey,
    reviewCardsKey,
  ];

  // ── Load ─────────────────────────────────────────────────────────
  Future<PlannerSnapshot> load() async {
    final prefs = await SharedPreferences.getInstance();
    // Empty/invalid stage and goal are normalized by PlannerSnapshot's
    // constructor, so we no longer duplicate the default values here.
    return PlannerSnapshot(
      stage: prefs.getString(stageKey) ?? '',
      goal: prefs.getString(goalKey) ?? '',
      studyTasks: List<String>.from(prefs.getStringList(tasksKey) ?? const <String>[]),
      completedTasks: (prefs.getStringList(completedKey) ?? const <String>[])
          .map(int.tryParse)
          .whereType<int>()
          .toSet(),
      taskDueDates: _decodeStringMap(prefs.getString(dueDatesKey)),
      notes: prefs.getString(notesKey) ?? '',
      exams: _decodeList<Exam>(prefs.getString(examsKey), Exam.tryFromJson),
      studySessions: _decodeList<StudySession>(
        prefs.getString(sessionsKey),
        StudySession.tryFromJson,
      ),
      reviewCards: _decodeList<ReviewCard>(
        prefs.getString(reviewCardsKey),
        ReviewCard.tryFromJson,
      ),
    );
  }

  // ── Save ─────────────────────────────────────────────────────────
  /// Writes all keys. Fails loudly if any individual write reports a failure
  /// (SharedPreferences can return `false` on disk errors) so the caller can
  /// surface a "could not save" message.
  Future<void> save(PlannerSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    final results = await Future.wait<bool>(<Future<bool>>[
      prefs.setString(stageKey, snapshot.stage),
      prefs.setString(goalKey, snapshot.goal),
      prefs.setStringList(tasksKey, snapshot.studyTasks),
      prefs.setStringList(
        completedKey,
        snapshot.completedTasks.map((index) => index.toString()).toList(),
      ),
      prefs.setString(dueDatesKey, jsonEncode(snapshot.taskDueDates)),
      prefs.setString(notesKey, snapshot.notes),
      prefs.setString(
        examsKey,
        jsonEncode(snapshot.exams.map((e) => e.toJson()).toList()),
      ),
      prefs.setString(
        sessionsKey,
        jsonEncode(snapshot.studySessions.map((e) => e.toJson()).toList()),
      ),
      prefs.setString(
        reviewCardsKey,
        jsonEncode(snapshot.reviewCards.map((e) => e.toJson()).toList()),
      ),
    ]);
    if (results.any((ok) => !ok)) {
      throw StateError('One or more preferences failed to save');
    }
  }

  // ── Clear ────────────────────────────────────────────────────────
  /// Removes only this store's keys. Other app/plugin preferences are
  /// preserved.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait<bool>(_ourKeys.map(prefs.remove));
  }

  // ── Decoding helpers ─────────────────────────────────────────────
  Map<String, String> _decodeStringMap(String? raw) {
    if (raw == null || raw.isEmpty) return <String, String>{};
    final decoded = _tryDecode(raw);
    if (decoded is! Map) return <String, String>{};
    final out = <String, String>{};
    decoded.forEach((key, value) {
      if (key == null || value == null) return;
      out[key.toString()] = value.toString();
    });
    return out;
  }

  /// Parses a JSON array of model objects, silently skipping any entry that
  /// fails to parse. A corrupt record cannot wipe the whole list.
  List<T> _decodeList<T>(
    String? raw,
    T? Function(Map<String, dynamic> json) tryFromJson,
  ) {
    if (raw == null || raw.isEmpty) return <T>[];
    final decoded = _tryDecode(raw);
    if (decoded is! List) return <T>[];
    final out = <T>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final parsed = tryFromJson(Map<String, dynamic>.from(item));
      if (parsed != null) out.add(parsed);
    }
    return out;
  }

  /// Wraps [jsonDecode] in a try/catch so a corrupted value under one key
  /// cannot abort the entire load. Returns `null` on malformed JSON.
  dynamic _tryDecode(String raw) {
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }
}
