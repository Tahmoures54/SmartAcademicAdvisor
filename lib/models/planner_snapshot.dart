import '../config/app_config.dart';
import 'exam.dart';
import 'review_card.dart';
import 'study_session.dart';

/// Aggregate of all on-device planner data.
///
/// ⚠️ Index coupling: [completedTasks] holds indices into [studyTasks].
/// Any reorder/remove of [studyTasks] MUST go through this class (see
/// [removeTaskAt], [moveTask], [addTask]) so completed flags stay aligned.
/// [sanitize] is called automatically on construction and drops stale
/// indices / orphaned due-date keys, but it cannot recover a corrupted
/// mapping — prefer the helpers.
///
/// Fields are mutable for in-place UI updates; collections are exposed
/// directly for compatibility with existing call sites. Use the provided
/// helpers when you can.
class PlannerSnapshot {
  PlannerSnapshot({
    String stage = AcademicStages.defaultStage,
    String goal = AcademicGoals.defaultGoal,
    List<String>? studyTasks,
    Set<int>? completedTasks,
    Map<String, String>? taskDueDates,
    this.notes = '',
    List<Exam>? exams,
    List<StudySession>? studySessions,
    List<ReviewCard>? reviewCards,
  })  : stage = _validStage(stage),
        goal = _validGoal(goal),
        studyTasks = List<String>.of(studyTasks ?? const <String>[]),
        completedTasks = Set<int>.of(completedTasks ?? const <int>{}),
        taskDueDates =
            Map<String, String>.of(taskDueDates ?? const <String, String>{}),
        exams = List<Exam>.of(exams ?? const <Exam>[]),
        studySessions =
            List<StudySession>.of(studySessions ?? const <StudySession>[]),
        reviewCards =
            List<ReviewCard>.of(reviewCards ?? const <ReviewCard>[]) {
    sanitize();
  }

  // ── Scalar state ────────────────────────────────────────────────────
  String stage;
  String goal;
  String notes;

  // ── Collections ─────────────────────────────────────────────────────
  final List<String> studyTasks;
  final Set<int> completedTasks;
  final Map<String, String> taskDueDates;
  final List<Exam> exams;
  final List<StudySession> studySessions;
  final List<ReviewCard> reviewCards;

  // ── Convenience getters ─────────────────────────────────────────────
  int get taskCount => studyTasks.length;

  int get completedCount =>
      completedTasks.where((i) => i >= 0 && i < studyTasks.length).length;

  /// Fraction of tasks completed, in [0.0, 1.0]. Zero when there are no tasks.
  double get progress => taskCount == 0 ? 0.0 : completedCount / taskCount;

  bool get hasTasks => studyTasks.isNotEmpty;
  bool get hasExams => exams.isNotEmpty;
  bool get hasStudySessions => studySessions.isNotEmpty;
  bool get hasReviewCards => reviewCards.isNotEmpty;

  bool get isEmpty =>
      studyTasks.isEmpty &&
      notes.trim().isEmpty &&
      exams.isEmpty &&
      studySessions.isEmpty &&
      reviewCards.isEmpty;

  bool get isNotEmpty => !isEmpty;

  // ── Task helpers (index-safe) ───────────────────────────────────────
  void addTask(String task) {
    final value = task.trim();
    if (value.isEmpty) return;
    studyTasks.add(value);
  }

  /// Removes the task at [index], shifts every later index in
  /// [completedTasks] down by one, and drops any due date keyed by the
  /// removed task's text.
  void removeTaskAt(int index) {
    if (index < 0 || index >= studyTasks.length) return;
    final removed = studyTasks.removeAt(index);
    taskDueDates.remove(removed);
    completedTasks.remove(index);
    final shifted = <int>{};
    for (final i in completedTasks) {
      shifted.add(i > index ? i - 1 : i);
    }
    completedTasks
      ..clear()
      ..addAll(shifted);
    sanitize();
  }

  void toggleTaskComplete(int index) {
    if (index < 0 || index >= studyTasks.length) return;
    if (!completedTasks.remove(index)) {
      completedTasks.add(index);
    }
  }

  /// Moves a task from [from] to [to] and remaps completed indices so the
  /// same tasks remain marked as done.
  void moveTask(int from, int to) {
    if (from == to) return;
    if (from < 0 || from >= studyTasks.length) return;
    if (to < 0 || to >= studyTasks.length) return;
    final task = studyTasks.removeAt(from);
    studyTasks.insert(to, task);
    final remapped = <int>{};
    for (final i in completedTasks) {
      remapped.add(_shift(i, from, to));
    }
    completedTasks
      ..clear()
      ..addAll(remapped);
  }

  static int _shift(int index, int from, int to) {
    if (index == from) return to;
    if (from < to) {
      if (index > from && index <= to) return index - 1;
    } else {
      if (index >= to && index < from) return index + 1;
    }
    return index;
  }

  /// Sets a due date for [task] (matched by trimmed text) or clears it when
  /// [date] is null.
  void setTaskDueDate(String task, DateTime? date) {
    final key = task.trim();
    if (key.isEmpty) return;
    if (date == null) {
      taskDueDates.remove(key);
    } else {
      taskDueDates[key] =
          DateTime(date.year, date.month, date.day).toIso8601String();
    }
  }

  DateTime? dueDateFor(String task) {
    final raw = taskDueDates[task];
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  // ── Section clears ──────────────────────────────────────────────────
  void clearTasks() {
    studyTasks.clear();
    completedTasks.clear();
    taskDueDates.clear();
  }

  void clearExams() => exams.clear();
  void clearStudySessions() => studySessions.clear();
  void clearReviewCards() => reviewCards.clear();

  /// Full reset to defaults.
  void clearAll() {
    stage = AcademicStages.defaultStage;
    goal = AcademicGoals.defaultGoal;
    notes = '';
    clearTasks();
    clearExams();
    clearStudySessions();
    clearReviewCards();
  }

  // ── Integrity ───────────────────────────────────────────────────────
  /// Drops completed indices outside `[0, studyTasks.length)` and
  /// due-date entries whose task text is no longer present.
  void sanitize() {
    completedTasks.removeWhere((i) => i < 0 || i >= studyTasks.length);
    if (taskDueDates.isNotEmpty) {
      final present = studyTasks.toSet();
      taskDueDates.removeWhere((key, _) => !present.contains(key));
    }
  }

  // ── JSON ────────────────────────────────────────────────────────────
  Map<String, dynamic> toJson() => <String, dynamic>{
        'stage': stage,
        'goal': goal,
        'studyTasks': studyTasks,
        'completedTasks': (completedTasks.toList()..sort()),
        'taskDueDates': taskDueDates,
        'notes': notes,
        'exams': exams.map((e) => e.toJson()).toList(),
        'studySessions': studySessions.map((s) => s.toJson()).toList(),
        'reviewCards': reviewCards.map((c) => c.toJson()).toList(),
      };

  factory PlannerSnapshot.fromJson(Map<String, dynamic> json) {
    return PlannerSnapshot(
      stage: (json['stage'] ?? AcademicStages.defaultStage).toString(),
      goal: (json['goal'] ?? AcademicGoals.defaultGoal).toString(),
      studyTasks: _stringList(json['studyTasks']),
      completedTasks: _intSet(json['completedTasks']),
      taskDueDates: _stringMap(json['taskDueDates']),
      notes: (json['notes'] ?? '').toString(),
      exams: _parseList<Exam>(json['exams'], Exam.fromJson),
      studySessions:
          _parseList<StudySession>(json['studySessions'], StudySession.fromJson),
      reviewCards:
          _parseList<ReviewCard>(json['reviewCards'], ReviewCard.fromJson),
    );
  }

  // ── Equality ────────────────────────────────────────────────────────
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlannerSnapshot &&
          other.stage == stage &&
          other.goal == goal &&
          other.notes == notes &&
          _listEq(other.studyTasks, studyTasks) &&
          _setEq(other.completedTasks, completedTasks) &&
          _mapEq(other.taskDueDates, taskDueDates) &&
          _listEq(other.exams, exams) &&
          _listEq(other.studySessions, studySessions) &&
          _listEq(other.reviewCards, reviewCards);

  @override
  int get hashCode => Object.hash(
        stage,
        goal,
        notes,
        Object.hashAll(studyTasks),
        Object.hashAll(completedTasks.toList()..sort()),
        Object.hashAll(
            taskDueDates.entries.map((e) => '${e.key}=${e.value}')),
        Object.hashAll(exams),
        Object.hashAll(studySessions),
        Object.hashAll(reviewCards),
      );

  @override
  String toString() => 'PlannerSnapshot('
      'stage: "$stage", goal: "$goal", '
      'tasks: $taskCount ($completedCount done), '
      'exams: ${exams.length}, '
      'sessions: ${studySessions.length}, '
      'cards: ${reviewCards.length}, '
      'notes: ${notes.length} chars)';

  // ── Validation ──────────────────────────────────────────────────────
  static String _validStage(String value) {
    final v = value.trim();
    return AcademicStages.contains(v) ? v : AcademicStages.defaultStage;
  }

  static String _validGoal(String value) {
    final v = value.trim();
    return AcademicGoals.contains(v) ? v : AcademicGoals.defaultGoal;
  }

  // ── JSON helpers ────────────────────────────────────────────────────
  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return <String>[];
    return raw
        .where((e) => e != null)
        .map((e) => e.toString())
        .toList(growable: true);
  }

  static Set<int> _intSet(dynamic raw) {
    if (raw is! List) return <int>{};
    return raw.whereType<num>().map((n) => n.toInt()).toSet();
  }

  static Map<String, String> _stringMap(dynamic raw) {
    if (raw is! Map) return <String, String>{};
    final out = <String, String>{};
    raw.forEach((k, v) {
      if (k == null || v == null) return;
      out[k.toString()] = v.toString();
    });
    return out;
  }

  /// Parses a JSON list of model objects, skipping any entry that fails.
  static List<T> _parseList<T>(
    dynamic raw,
    T Function(Map<String, dynamic>) parse,
  ) {
    if (raw is! List) return <T>[];
    final out = <T>[];
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        out.add(parse(Map<String, dynamic>.from(item)));
      } catch (_) {
        // Skip malformed records instead of failing the whole snapshot.
      }
    }
    return out;
  }

  // ── Generic equality helpers ────────────────────────────────────────
  static bool _listEq<T>(List<T> a, List<T> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _setEq<T>(Set<T> a, Set<T> b) =>
      a.length == b.length && a.containsAll(b);

  static bool _mapEq<K, V>(Map<K, V> a, Map<K, V> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key) || b[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }
}
