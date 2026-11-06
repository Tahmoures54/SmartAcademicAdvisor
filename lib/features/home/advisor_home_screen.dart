import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../models/exam.dart';
import '../../models/planner_snapshot.dart';
import '../../models/review_card.dart';
import '../../models/study_session.dart';
import '../../services/advisor_api.dart';
import '../../services/local_store.dart';
import '../../services/offline_advice.dart';
import '../assessment/study_assessment_page.dart';

part 'home_logic.dart';
part 'home_logic2.dart';
part 'home_planner.dart';
part 'home_exams.dart';
part 'home_shell.dart';

class AdvisorHomeScreen extends StatefulWidget {
  const AdvisorHomeScreen({super.key});
  @override
  State<AdvisorHomeScreen> createState() => _AdvisorHomeScreenState();
}

class _AdvisorHomeScreenState extends State<AdvisorHomeScreen> {
  final _questionController = TextEditingController();
  final _newTaskController = TextEditingController();
  final _notesController = TextEditingController();
  final List<String> _studyTasks = [];
  final Set<int> _completedTasks = {};
  final Map<String, String> _taskDueDates = {};
  final List<Map<String, String>> _exams = [];
  final List<Map<String, String>> _studySessions = [];
  final List<Map<String, String>> _reviewCards = [];
  bool _localDataLoaded = false;
  Timer? _focusTimer;
  int _focusSecondsRemaining = 25 * 60;
  bool _focusRunning = false;
  String _stage = AcademicStages.defaultStage;
  String _goal = AcademicStages.defaultGoal;
  String _tab = 'خانه';
  bool _showGuide = false;
  String? _answer;
  static const stages = AcademicStages.all;
  final _store = LocalStore();
  final _advisorApi = AdvisorApi();

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

  @override
  void dispose() {
    _questionController.dispose();
    _newTaskController.dispose();
    _notesController.dispose();
    _focusTimer?.cancel();
    super.dispose();
  }

  String _stageAdvice() => OfflineAdvice.forStage(_stage);

  String _goalAdvice() => OfflineAdvice.forGoal(_goal);

  Future<String?> _requestAiAnswer(String question) async {
    return _advisorApi.requestAnswer(stage: _stage, goal: _goal, question: question);
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
    if (mounted) setState(() => _answer = 'در حال دریافت پاسخ از مربی هوش مصنوعی…');
    try {
      final aiAnswer = await _requestAiAnswer(question);
      if (!mounted || aiAnswer == null) return;
      setState(() => _answer =
        'پاسخ مربی هوش مصنوعی\n\n$aiAnswer\n\n'
        'اگر پاسخ مربوط به تصمیم مهم تحصیلی یا انتخاب رشته است، اطلاعات را با منابع معتبر و خانواده نیز بررسی کن.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _answer =
        '$fallback\n\nدر حال حاضر اتصال به مربی هوش مصنوعی برقرار نشد؛ لطفاً بعداً دوباره تلاش کن.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: _tab == 'خانه' ? CustomScrollView(slivers: [
      SliverToBoxAdapter(child: _header()),
      SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(18,18,18,12), child: _welcomeCard())),
      SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal:18), child: _stagePicker())),
      const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(18,22,18,10),
        child: Text('از کجا شروع کنیم؟', style: TextStyle(fontSize:19,fontWeight:FontWeight.w800)))),
      SliverPadding(padding: const EdgeInsets.symmetric(horizontal:18), sliver: SliverGrid(
        delegate: SliverChildListDelegate([
          _goalCard(Icons.calendar_month_rounded,'برنامه‌ریزی درسی','برنامهٔ قابل اجرا برای روزهای شلوغ'),
          _goalCard(Icons.explore_rounded,'انتخاب رشته','شناخت علاقه‌ها و مسیرهای آینده'),
          _goalCard(Icons.school_rounded,'آزمون و کنکور','مرور، تمرین و مدیریت زمان'),
          _goalCard(Icons.work_outline_rounded,'دانشگاه و شغل','تصمیم‌گیری برای قدم بعدی'),
        ]),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:2,crossAxisSpacing:12,mainAxisSpacing:12,childAspectRatio:1.42),
      )),
      SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(18,18,18,0),
        child: OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const StudyAssessmentPage())),
          icon: const Icon(Icons.insights_rounded),
          label: const Padding(padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('ارزیابی سریع روش مطالعه')),
        ))),
      const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(18,24,18,8),
        child: Text('از مشاور تحصیلی بپرس',style:TextStyle(fontSize:19,fontWeight:FontWeight.w800)))),
      SliverToBoxAdapter(child: Padding(padding:const EdgeInsets.symmetric(horizontal:18),child:_questionCard())),
      if (_answer != null) SliverToBoxAdapter(child: Padding(padding:const EdgeInsets.fromLTRB(18,14,18,12),child:_answerCard())),
      SliverToBoxAdapter(child: Padding(padding:const EdgeInsets.fromLTRB(18,18,18,28),child:_privacyNote())),
    ]) : _secondaryPage()),
    bottomNavigationBar: NavigationBar(
      selectedIndex: ['خانه','برنامه من','آزمون‌ها','یادداشت‌ها','پروفایل'].indexOf(_tab),
      onDestinationSelected:(i)=>setState(()=>_tab=['خانه','برنامه من','آزمون‌ها','یادداشت‌ها','پروفایل'][i]),
      destinations: const [
        NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:'خانه'),
        NavigationDestination(icon:Icon(Icons.event_note_outlined),label:'برنامه من'),
        NavigationDestination(icon:Icon(Icons.event_available_outlined),label:'آزمون‌ها'),
        NavigationDestination(icon:Icon(Icons.bookmark_border),label:'یادداشت‌ها'),
        NavigationDestination(icon:Icon(Icons.person_outline),label:'پروفایل'),
      ],
    ),
  );
}
