import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config/app_config.dart';
import 'services/advisor_api.dart';
import 'services/local_store.dart';
import 'services/offline_advice.dart';
import 'features/assessment/study_assessment_page.dart';
import 'models/exam.dart';
import 'models/planner_snapshot.dart';
import 'models/review_card.dart';
import 'models/study_session.dart';

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
  final _store = LocalStore();
  final _advisorApi = AdvisorApi();
  String _stage = AcademicStages.defaultStage;
  String _goal = AcademicStages.defaultGoal;
  String _tab = 'خانه';
  String? _answer;
  bool _loaded = false;
  final List<String> _studyTasks = [];
  final Set<int> _completedTasks = {};
  final Map<String, String> _taskDueDates = {};
  final List<Map<String, String>> _exams = [];
  final List<Map<String, String>> _studySessions = [];
  final List<Map<String, String>> _reviewCards = [];
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await _store.load();
    if (!mounted) return;
    setState(() {
      _stage = s.stage;
      _goal = s.goal;
      _studyTasks
        ..clear()
        ..addAll(s.studyTasks);
      _completedTasks
        ..clear()
        ..addAll(s.completedTasks);
      _taskDueDates
        ..clear()
        ..addAll(s.taskDueDates);
      _notesController.text = s.notes;
      _exams
        ..clear()
        ..addAll(s.exams.map((e) => e.toJson()));
      _studySessions
        ..clear()
        ..addAll(s.studySessions.map((e) => e.toJson()));
      _reviewCards
        ..clear()
        ..addAll(s.reviewCards.map((e) => e.toJson()));
      _loaded = true;
    });
  }

  Future<void> _save() async {
    final snapshot = PlannerSnapshot(
      stage: _stage,
      goal: _goal,
      studyTasks: List<String>.from(_studyTasks),
      completedTasks: Set<int>.from(_completedTasks),
      taskDueDates: Map<String, String>.from(_taskDueDates),
      notes: _notesController.text,
      exams: _exams.map((m) => Exam.fromJson(Map<String, dynamic>.from(m))).toList(),
      studySessions: _studySessions
          .map((m) => StudySession.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
      reviewCards: _reviewCards
          .map((m) => ReviewCard.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
    );
    await _store.save(snapshot);
  }

  Future<void> _ask() async {
    final q = _questionController.text.trim();
    if (q.isEmpty) {
      setState(() => _answer = 'لطفاً ابتدا سؤال یا دغدغهٔ تحصیلی‌تان را بنویسید.');
      return;
    }
    final fallback = OfflineAdvice.buildFallback(stage: _stage, goal: _goal, question: q);
    setState(() => _answer = fallback);
    if (!AppConfig.hasAnyAiChannel) return;
    setState(() => _answer = 'در حال دریافت پاسخ از مربی هوش مصنوعی…');
    try {
      final ai = await _advisorApi.requestAnswer(stage: _stage, goal: _goal, question: q);
      if (!mounted || ai == null) return;
      setState(() => _answer =
          'پاسخ مربی هوش مصنوعی\n\n$ai\n\nاگر پاسخ مربوط به تصمیم مهم تحصیلی یا انتخاب رشته است، اطلاعات را با منابع معتبر و خانواده نیز بررسی کن.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _answer =
          '$fallback\n\nدر حال حاضر اتصال به مربی هوش مصنوعی برقرار نشد؛ لطفاً بعداً دوباره تلاش کن.');
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _tab == 'خانه'
            ? ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  const Text('همراه تحصیلی',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  const Text('از اولین قدم تا آینده‌ای روشن',
                      style: TextStyle(color: Colors.black54)),
                  const SizedBox(height: 16),
                  const Text('مقطع تحصیلی شما',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: AcademicStages.all
                        .map((s) => ChoiceChip(
                              label: Text(s),
                              selected: _stage == s,
                              onSelected: (_) {
                                setState(() => _stage = s);
                                _save();
                              },
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text('از کجا شروع کنیم؟',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      'برنامه‌ریزی درسی',
                      'انتخاب رشته',
                      'آزمون و کنکور',
                      'دانشگاه و شغل',
                    ]
                        .map((g) => ChoiceChip(
                              label: Text(g),
                              selected: _goal == g,
                              onSelected: (_) {
                                setState(() => _goal = g);
                                _save();
                              },
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const StudyAssessmentPage(),
                      ),
                    ),
                    icon: const Icon(Icons.insights_rounded),
                    label: const Text('ارزیابی سریع روش مطالعه'),
                  ),
                  const SizedBox(height: 16),
                  const Text('از مشاور تحصیلی بپرس',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _questionController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'سؤال تحصیلی خود را بنویسید',
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _ask,
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('دریافت راهنمایی'),
                  ),
                  if (_answer != null) ...[
                    const SizedBox(height: 12),
                    const Text('راهنمای پیشنهادی',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                    const SizedBox(height: 8),
                    SelectableText(_answer!, style: const TextStyle(height: 1.8)),
                  ],
                ],
              )
            : Center(
                child: Text(
                  _tab == 'برنامه من'
                      ? 'برنامهٔ درسی من'
                      : _tab == 'آزمون‌ها'
                          ? 'آزمون‌ها و نتیجه‌ها'
                          : _tab == 'یادداشت‌ها'
                              ? 'یادداشت‌های من'
                              : 'پروفایل تحصیلی',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: ['خانه', 'برنامه من', 'آزمون‌ها', 'یادداشت‌ها', 'پروفایل']
            .indexOf(_tab),
        onDestinationSelected: (i) => setState(
          () => _tab = ['خانه', 'برنامه من', 'آزمون‌ها', 'یادداشت‌ها', 'پروفایل'][i],
        ),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'خانه'),
          NavigationDestination(icon: Icon(Icons.event_note_outlined), label: 'برنامه من'),
          NavigationDestination(icon: Icon(Icons.event_available_outlined), label: 'آزمون‌ها'),
          NavigationDestination(icon: Icon(Icons.bookmark_border), label: 'یادداشت‌ها'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'پروفایل'),
        ],
      ),
    );
  }
}
