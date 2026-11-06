import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/exam.dart';
import '../models/planner_snapshot.dart';
import '../models/review_card.dart';
import '../models/study_session.dart';

/// Loads and persists planner data with the same preference keys as before.
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

  Future<PlannerSnapshot> load() async {
    final prefs = await SharedPreferences.getInstance();
    final snapshot = PlannerSnapshot(
      stage: prefs.getString(stageKey) ?? 'متوسطه اول',
      goal: prefs.getString(goalKey) ?? 'برنامه‌ریزی درسی',
      studyTasks: List<String>.from(prefs.getStringList(tasksKey) ?? const []),
      completedTasks: (prefs.getStringList(completedKey) ?? const [])
          .map(int.tryParse)
          .whereType<int>()
          .toSet(),
      taskDueDates: _decodeStringMap(prefs.getString(dueDatesKey)),
      notes: prefs.getString(notesKey) ?? '',
      exams: _decodeList(prefs.getString(examsKey), Exam.fromJson),
      studySessions:
          _decodeList(prefs.getString(sessionsKey), StudySession.fromJson),
      reviewCards:
          _decodeList(prefs.getString(reviewCardsKey), ReviewCard.fromJson),
    );
    return snapshot;
  }

  Future<void> save(PlannerSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(stageKey, snapshot.stage);
    await prefs.setString(goalKey, snapshot.goal);
    await prefs.setStringList(tasksKey, snapshot.studyTasks);
    await prefs.setStringList(
      completedKey,
      snapshot.completedTasks.map((index) => index.toString()).toList(),
    );
    await prefs.setString(dueDatesKey, jsonEncode(snapshot.taskDueDates));
    await prefs.setString(notesKey, snapshot.notes);
    await prefs.setString(
      examsKey,
      jsonEncode(snapshot.exams.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      sessionsKey,
      jsonEncode(snapshot.studySessions.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      reviewCardsKey,
      jsonEncode(snapshot.reviewCards.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Map<String, String> _decodeStringMap(String? raw) {
    final decoded = jsonDecode(raw ?? '{}');
    if (decoded is! Map) return {};
    return decoded.map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );
  }

  List<T> _decodeList<T>(
    String? raw,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    final decoded = jsonDecode(raw ?? '[]');
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((item) => fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ))
        .toList();
  }
}
