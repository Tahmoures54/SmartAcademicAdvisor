import 'dart:async';

import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'features/assessment/study_assessment_page.dart';
import 'models/exam.dart';
import 'models/planner_snapshot.dart';
import 'models/review_card.dart';
import 'models/study_session.dart';
import 'services/advisor_api.dart';
import 'services/local_store.dart';
import 'services/offline_advice.dart';

void main() => runApp(const AcademicAdvisorApp());

class AcademicAdvisorApp extends StatelessWidget {
  const AcademicAdvisorApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'همراه تحصیلی',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF287D72)),
          scaffoldBackgroundColor: const Color(0xFFF5F8F7),
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            margin: EdgeInsets.zero,
          ),
        ),
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: AdvisorHomeScreen(),
        ),
      );
}

class AdvisorHomeScreen extends StatefulWidget {
  const AdvisorHomeScreen({super.key});
  @override
  State<AdvisorHomeScreen> createState() => _AdvisorHomeScreenState();
}

class _AdvisorHomeScreenState extends State<AdvisorHomeScreen> {
  final _questionController = TextEditingController();
  final _notesController = TextEditingController();
  final _newTaskController = TextEditingController();
  final _store = LocalStore();
  final _advisorApi = AdvisorApi();
  String _stage = AcademicStages.defaultStage;
  String _goal = AcademicStages.defaultGoal;
  String _tab = 'خانه';
  String? _answer;
  bool _localDataLoaded = false;
  bool _showGuide = false;
  final List<String> _studyTasks = [];
  final Set<int> _completedTasks = {};
  final Map<String, String> _taskDueDates = {};
  final List<Map<String, String>> _exams = [];
  final List<Map<String, String>> _studySessions = [];
  final List<Map<String, String>> _reviewCards = [];
  Timer? _focusTimer;
  int _focusSecondsRemaining = 25 * 60;
  bool _focusRunning = false;
  static const stages = AcademicStages.all;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    final snapshot = await _store.load();
    if (!mounted) return;
    setState(() {
      _stage = snapshot.stage;
      _goal = snapshot.goal;
      _studyTasks..clear()..addAll(snapshot.studyTasks);
      _completedTasks..clear()..addAll(snapshot.completedTasks);
      _taskDueDates..clear()..addAll(snapshot.taskDueDates);
      _notesController.text = snapshot.notes;
      _exams..clear()..addAll(snapshot.exams.map((e) => e.toJson()));
      _studySessions..clear()..addAll(snapshot.studySessions.map((e) => e.toJson()));
      _reviewCards..clear()..addAll(snapshot.reviewCards.map((e) => e.toJson()));
      _localDataLoaded = true;
    });
  }

  Future<void> _saveData() async {
    final snapshot = PlannerSnapshot(
      stage: _stage,
      goal: _goal,
      studyTasks: List<String>.from(_studyTasks),
      completedTasks: Set<int>.from(_completedTasks),
      taskDueDates: Map<String, String>.from(_taskDueDates),
      notes: _notesController.text,
      exams: _exams.map((m) => Exam.fromJson(Map<String, dynamic>.from(m))).toList(),
      studySessions: _studySessions.map((m) => StudySession.fromJson(Map<String, dynamic>.from(m))).toList(),
      reviewCards: _reviewCards.map((m) => ReviewCard.fromJson(Map<String, dynamic>.from(m))).toList(),
    );
    await _store.save(snapshot);
  }

  Future<void> _clearSavedData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف اطلاعات ذخیره‌شده؟'),
        content: const Text('برنامه‌ها، یادداشت‌ها و ترجیحات محلی این اپ از روی این دستگاه حذف می‌شوند.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف اطلاعات')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _store.clear();
    if (!mounted) return;
    setState(() {
      _stage = AcademicStages.defaultStage;
      _goal = AcademicStages.defaultGoal;
      _studyTasks.clear();
      _completedTasks.clear();
      _taskDueDates.clear();
      _exams.clear();
      _studySessions.clear();
      _reviewCards.clear();
      _notesController.clear();
      _answer = null;
    });
  }

  Future<void> _askAdvisor() async {
    final question = _questionController.text.trim();
    if (question.isEmpty) {
      setState(() => _answer = 'لطفاً ابتدا سؤال یا دغدغهٔ تحصیلی‌تان را بنویسید.');
      return;
    }
    final fallback = OfflineAdvice.buildFallback(stage: _stage, goal: _goal, question: question);
    setState(() => _answer = fallback);
    if (!AppConfig.hasAnyAiChannel) return;
    setState(() => _answer = 'در حال دریافت پاسخ از مربی هوش مصنوعی…');
    try {
      final ai = await _advisorApi.requestAnswer(stage: _stage, goal: _goal, question: question);
      if (!mounted || ai == null) return;
      setState(() => _answer =
          'پاسخ مربی هوش مصنوعی\n\n$ai\n\nاگر پاسخ مربوط به تصمیم مهم تحصیلی یا انتخاب رشته است، اطلاعات را با منابع معتبر و خانواده نیز بررسی کن.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _answer =
          '$fallback\n\nدر حال حاضر اتصال به مربی هوش مصنوعی برقرار نشد؛ لطفاً بعداً دوباره تلاش کن.');
    }
  }

  void _addStudyTask() {
    final task = _newTaskController.text.trim();
    if (!_localDataLoaded || task.isEmpty) return;
    setState(() {
      _studyTasks.add(task);
      _newTaskController.clear();
    });
    _saveData();
  }

  void _toggleFocusTimer() {
    if (_focusRunning) {
      _focusTimer?.cancel();
      setState(() => _focusRunning = false);
      return;
    }
    if (_focusSecondsRemaining <= 0) setState(() => _focusSecondsRemaining = 25 * 60);
    setState(() => _focusRunning = true);
    _focusTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_focusSecondsRemaining <= 1) {
        timer.cancel();
        setState(() {
          _focusSecondsRemaining = 0;
          _focusRunning = false;
        });
      } else {
        setState(() => _focusSecondsRemaining--);
      }
    });
  }

  void _resetFocusTimer() {
    _focusTimer?.cancel();
    setState(() {
      _focusRunning = false;
      _focusSecondsRemaining = 25 * 60;
    });
  }

  Future<void> _addExam() async {
    final subjectController = TextEditingController();
    final scoreController = TextEditingController();
    DateTime examDate = DateTime.now().add(const Duration(days: 7));
    final exam = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('ثبت آزمون'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: subjectController, autofocus: true,
                    decoration: const InputDecoration(labelText: 'نام درس یا آزمون')),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final selected = await showDatePicker(
                      context: dialogContext,
                      initialDate: examDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (selected != null) setDialogState(() => examDate = selected);
                  },
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text('تاریخ: ${examDate.year}/${examDate.month}/${examDate.day}'),
                ),
                TextField(controller: scoreController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'نمره (اختیاری از ۲۰)')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('انصراف')),
            FilledButton(
              onPressed: () {
                final subject = subjectController.text.trim();
                if (subject.isEmpty) return;
                final scoreText = scoreController.text.trim();
                final score = scoreText.isEmpty ? null : double.tryParse(scoreText);
                if (scoreText.isNotEmpty && (score == null || score < 0 || score > 20)) return;
                Navigator.pop(dialogContext, {
                  'subject': subject,
                  'date': examDate.toIso8601String(),
                  'score': score == null ? '' : score.toString(),
                });
              },
              child: const Text('ذخیره آزمون'),
            ),
          ],
        ),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      subjectController.dispose();
      scoreController.dispose();
    });
    if (exam == null || !mounted) return;
    setState(() => _exams.add(exam));
    await _saveData();
  }

  @override
  void dispose() {
    _questionController.dispose();
    _notesController.dispose();
    _newTaskController.dispose();
    _focusTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (_focusSecondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_focusSecondsRemaining % 60).toString().padLeft(2, '0');
    return Scaffold(
      body: SafeArea(
        child: switch (_tab) {
          'خانه' => ListView(
              padding: const EdgeInsets.all(18),
              children: [
                const Text('همراه تحصیلی', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                const Text('از اولین قدم تا آینده‌ای روشن', style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 16),
                const Text('مقطع تحصیلی شما', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: stages
                      .map((s) => ChoiceChip(
                            label: Text(s),
                            selected: _stage == s,
                            onSelected: (_) {
                              setState(() => _stage = s);
                              _saveData();
                            },
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
                const Text('از کجا شروع کنیم؟', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['برنامه‌ریزی درسی', 'انتخاب رشته', 'آزمون و کنکور', 'دانشگاه و شغل']
                      .map((g) => ChoiceChip(
                            label: Text(g),
                            selected: _goal == g,
                            onSelected: (_) {
                              setState(() => _goal = g);
                              _saveData();
                            },
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const StudyAssessmentPage()),
                  ),
                  icon: const Icon(Icons.insights_rounded),
                  label: const Text('ارزیابی سریع روش مطالعه'),
                ),
                const SizedBox(height: 16),
                const Text('از مشاور تحصیلی بپرس', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                TextField(
                  controller: _questionController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'مثلاً: برای امتحان‌های دو هفتهٔ آینده چطور برنامه‌ریزی کنم؟',
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _askAdvisor,
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('دریافت راهنمایی'),
                ),
                if (_answer != null) ...[
                  const SizedBox(height: 12),
                  const Text('راهنمای پیشنهادی', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                  const SizedBox(height: 8),
                  SelectableText(_answer!, style: const TextStyle(height: 1.8)),
                ],
              ],
            ),
          'برنامه من' => ListView(
              padding: const EdgeInsets.all(18),
              children: [
                const Text('برنامهٔ درسی من', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2ED),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      const Text('زمان تمرکز', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                      Text('$minutes:$seconds',
                          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Color(0xFF287D72))),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FilledButton(
                            onPressed: _toggleFocusTimer,
                            child: Text(_focusRunning ? 'مکث' : 'شروع تمرکز'),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            onPressed: _resetFocusTimer,
                            icon: const Icon(Icons.restart_alt_rounded),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _newTaskController,
                  enabled: _localDataLoaded,
                  decoration: const InputDecoration(
                    labelText: 'کار یا درس بعدی',
                    hintText: 'مثلاً: مرور فصل دوم علوم',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _addStudyTask(),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _localDataLoaded ? _addStudyTask : null,
                  icon: const Icon(Icons.add_task_rounded),
                  label: const Text('افزودن به برنامه'),
                ),
                const SizedBox(height: 12),
                Text('${_completedTasks.length} از ${_studyTasks.length} انجام‌شده',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF287D72))),
                if (_studyTasks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('هنوز کاری ثبت نشده است', textAlign: TextAlign.center),
                  )
                else
                  ..._studyTasks.asMap().entries.map((entry) => CheckboxListTile(
                        value: _completedTasks.contains(entry.key),
                        title: Text(entry.value),
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _completedTasks.add(entry.key);
                            } else {
                              _completedTasks.remove(entry.key);
                            }
                          });
                          _saveData();
                        },
                      )),
              ],
            ),
          'آزمون‌ها' => ListView(
              padding: const EdgeInsets.all(18),
              children: [
                const Text('آزمون‌ها و نتیجه‌ها', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _localDataLoaded ? _addExam : null,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: const Text('افزودن آزمون یا امتحان'),
                ),
                const SizedBox(height: 12),
                if (_exams.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('هنوز آزمونی ثبت نشده است', textAlign: TextAlign.center),
                  )
                else
                  ..._exams.map((exam) {
                    final date = DateTime.tryParse(exam['date'] ?? '') ?? DateTime.now();
                    final days = DateTime(date.year, date.month, date.day)
                        .difference(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day))
                        .inDays;
                    final countdown = days < 0
                        ? 'تاریخ آزمون گذشته است'
                        : days == 0
                            ? 'آزمون امروز است'
                            : 'تا آزمون $days روز مانده';
                    return Card(
                      child: ListTile(
                        title: Text(exam['subject'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(
                            '${date.year}/${date.month}/${date.day} · $countdown${(exam['score'] ?? '').isEmpty ? '' : '\nنمره: ${exam['score']} از ۲۰'}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () {
                            setState(() => _exams.remove(exam));
                            _saveData();
                          },
                        ),
                      ),
                    );
                  }),
              ],
            ),
          'یادداشت‌ها' => ListView(
              padding: const EdgeInsets.all(18),
              children: [
                const Text('یادداشت‌های من', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  enabled: _localDataLoaded,
                  minLines: 8,
                  maxLines: 16,
                  onChanged: (_) => _saveData(),
                  decoration: const InputDecoration(
                    hintText: 'یادداشت تحصیلی شما…',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _localDataLoaded ? _saveData : null,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('ذخیرهٔ یادداشت'),
                ),
              ],
            ),
          _ => ListView(
              padding: const EdgeInsets.all(18),
              children: [
                const Text('پروفایل تحصیلی', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Text('مقطع فعلی: $_stage'),
                Text('موضوع منتخب: $_goal'),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _clearSavedData,
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: const Text('حذف اطلاعات ذخیره‌شده'),
                ),
              ],
            ),
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: ['خانه', 'برنامه من', 'آزمون‌ها', 'یادداشت‌ها', 'پروفایل'].indexOf(_tab),
        onDestinationSelected: (i) =>
            setState(() => _tab = ['خانه', 'برنامه من', 'آزمون‌ها', 'یادداشت‌ها', 'پروفایل'][i]),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'خانه'),
          NavigationDestination(icon: Icon(Icons.event_note_outlined), label: 'برنامه من'),
          NavigationDestination(icon: Icon(Icons.event_available_outlined), label: 'آزمون‌ها'),
          NavigationDestination(icon: Icon(Icons.bookmark_border), label: 'یادداشت‌ها'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'پروفایل'),
        ],
      ),
    );
  }
}
