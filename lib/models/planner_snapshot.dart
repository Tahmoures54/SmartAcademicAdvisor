import 'exam.dart';
import 'review_card.dart';
import 'study_session.dart';

/// Aggregate of all on-device planner data.
class PlannerSnapshot {
  PlannerSnapshot({
    this.stage = 'متوسطه اول',
    this.goal = 'برنامه‌ریزی درسی',
    List<String>? studyTasks,
    Set<int>? completedTasks,
    Map<String, String>? taskDueDates,
    this.notes = '',
    List<Exam>? exams,
    List<StudySession>? studySessions,
    List<ReviewCard>? reviewCards,
  })  : studyTasks = studyTasks ?? <String>[],
        completedTasks = completedTasks ?? <int>{},
        taskDueDates = taskDueDates ?? <String, String>{},
        exams = exams ?? <Exam>[],
        studySessions = studySessions ?? <StudySession>[],
        reviewCards = reviewCards ?? <ReviewCard>[];

  String stage;
  String goal;
  final List<String> studyTasks;
  final Set<int> completedTasks;
  final Map<String, String> taskDueDates;
  String notes;
  final List<Exam> exams;
  final List<StudySession> studySessions;
  final List<ReviewCard> reviewCards;

  void clearAll() {
    stage = 'متوسطه اول';
    goal = 'برنامه‌ریزی درسی';
    studyTasks.clear();
    completedTasks.clear();
    taskDueDates.clear();
    notes = '';
    exams.clear();
    studySessions.clear();
    reviewCards.clear();
  }
}
