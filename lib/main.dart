import 'dart:async';

import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'features/assessment/study_assessment_page.dart';
import 'features/settings/ai_settings_page.dart';
import 'models/exam.dart';
import 'models/planner_snapshot.dart';
import 'models/review_card.dart';
import 'models/study_session.dart';
import 'services/advisor_api.dart';
import 'services/ai_settings_store.dart';
import 'services/local_store.dart';
import 'services/offline_advice.dart';

void main() => runApp(const AcademicAdvisorApp());

class AcademicAdvisorApp extends StatelessWidget {
  const AcademicAdvisorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'همراه تحصیلی',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.seedColor),
        scaffoldBackgroundColor: AppColors.scaffoldColor,
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
  final _aiSettingsStore = AiSettingsStore();

  // ── Scalar state ────────────────────────────────────────────────
  String _stage = AcademicStages.defaultStage;
  String _goal = AcademicGoals.defaultGoal;
  int _tabIndex = 0;
  String? _answer;
  bool _askingAdvisor = false;

  // ── Loading state ───────────────────────────────────────────────
  bool _localDataLoaded = false;
  String? _loadError;

  // ── Typed collections ───────────────────────────────────────────
  final List<String> _studyTasks = <String>[];
  final Set<int> _completedTasks = <int>{};
  final Map<String, String> _taskDueDates = <String, String>{};
  final List<Exam> _exams = <Exam>[];
  final List<StudySession> _studySessions = <StudySession>[];
  final List<ReviewCard> _reviewCards = <ReviewCard>[];

  // ── Focus timer ─────────────────────────────────────────────────
  Timer? _focusTimer;
  int _focusSecondsRemaining = 25 * 60;
  bool _focusRunning = false;

  // ── Notes debounce ──────────────────────────────────────────────
  Timer? _notesDebounce;

  static const _stages = AcademicStages.all;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  @override
  void dispose() {
    _questionController.dispose();
    _notesController.dispose();
    _newTaskController.dispose();
    _focusTimer?.cancel();
    _notesDebounce?.cancel();
    _advisorApi.dispose();
    super.dispose();
  }

  // ── Load / save ─────────────────────────────────────────────────
  Future<void> _loadSavedData() async {
    try {
      final snapshot = await _store.load();
      if (!mounted) return;
      setState(() {
        _stage = snapshot.stage;
        _goal = snapshot.goal;
        _studyTasks
          ..clear()
          ..addAll(snapshot.studyTasks);
        _completedTasks
          ..clear()
          ..addAll(snapshot.completedTasks);
        _taskDueDates
          ..clear()
          ..addAll(snapshot.taskDueDates);
        _notesController.text = snapshot.notes;
        _exams
          ..clear()
          ..addAll(snapshot.exams);
        _studySessions
          ..clear()
          ..addAll(snapshot.studySessions);
        _reviewCards
          ..clear()
          ..addAll(snapshot.reviewCards);
        _localDataLoaded = true;
        _loadError = null;
      });
    } catch (e, stack) {
      debugPrint('Load failed: $e\n$stack');
      if (!mounted) return;
      setState(() => _loadError = e.toString());
    }
  }

  Future<void> _saveData() async {
    final snapshot = PlannerSnapshot(
      stage: _stage,
      goal: _goal,
      studyTasks: _studyTasks,
      completedTasks: _completedTasks,
      taskDueDates: _taskDueDates,
      notes: _notesController.text,
      exams: _exams,
      studySessions: _studySessions,
      reviewCards: _reviewCards,
    );
    try {
      await _store.save(snapshot);
    } catch (e) {
      debugPrint('Save failed: $e');
      _showSnack('ذخیرهٔ اطلاعات با خطا مواجه شد');
    }
  }

  /// Debounces saves for high-frequency events like typing.
  void _scheduleSave() {
    _notesDebounce?.cancel();
    _notesDebounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _saveData();
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ── Clear all ───────────────────────────────────────────────────
  Future<void> _clearSavedData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف اطلاعات ذخیره‌شده؟'),
        content: const Text(
          'برنامه‌ها، یادداشت‌ها و ترجیحات محلی این اپ از روی این دستگاه '
          'حذف می‌شوند. سایر تنظیمات برنامه حفظ می‌شود.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف اطلاعات'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _store.clear();
    if (!mounted) return;
    setState(() {
      _stage = AcademicStages.defaultStage;
      _goal = AcademicGoals.defaultGoal;
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

  // ── AI advice ───────────────────────────────────────────────────
  Future<void> _askAdvisor() async {
    if (_askingAdvisor) return;
    final question = _questionController.text.trim();
    if (question.isEmpty) {
      setState(() => _answer = 'لطفاً ابتدا سؤال یا دغدغهٔ تحصیلی‌تان را بنویسید.');
      return;
    }

    final fallback = OfflineAdvice.buildFallback(
      stage: _stage,
      goal: _goal,
      question: question,
    );

    setState(() {
      _askingAdvisor = true;
      _answer = null;
    });

    AiProviderSettings settings;
    try {
      settings = await _aiSettingsStore.load();
    } catch (error) {
      debugPrint('AI settings unavailable: $error');
      if (!mounted) return;
      setState(() {
        _askingAdvisor = false;
        _answer = '$fallback\n\nحافظه امن تنظیمات در دسترس نیست؛ تنظیمات دستگاه را بررسی کنید.';
      });
      return;
    }
    if (!settings.isConfigured) {
      setState(() {
        _askingAdvisor = false;
        _answer = '$fallback\n\nبرای دریافت پاسخ هوش مصنوعی، ابتدا کلید شخصی خود را در بخش پروفایل ← تنظیمات هوش مصنوعی وارد کنید.';
      });
      return;
    }

    String result;
    try {
      final ai = await _advisorApi.requestAnswer(
        settings: settings,
        stage: _stage,
        goal: _goal,
        question: question,
      );
      if (ai.trim().isNotEmpty) {
        result = 'پاسخ مربی هوش مصنوعی\n\n$ai\n\n'
            'اگر پاسخ مربوط به تصمیم مهم تحصیلی یا انتخاب رشته است، اطلاعات را '
            'با منابع معتبر و خانواده نیز بررسی کن.';
      } else {
        result = '$fallback\n\nمربی هوش مصنوعی پاسخ مناسبی برنگرداند.';
      }
    } on AdvisorException catch (e) {
      final hint = switch (e.kind) {
        AdvisorErrorKind.rateLimited =>
          'تعداد درخواست‌ها زیاد است؛ کمی بعد دوباره تلاش کن.',
        AdvisorErrorKind.network =>
          'اتصال به سرویس برقرار نشد؛ اتصال اینترنت را بررسی کن.',
        AdvisorErrorKind.misconfigured =>
          'تنظیمات سرویس معتبر نیست؛ نشانی HTTPS، نام مدل و کلید را بررسی کنید.',
        AdvisorErrorKind.unauthorized => 'کلید سرویس معتبر نیست.',
        AdvisorErrorKind.badRequest =>
          'درخواست معتبر نیست؛ متن سؤال یا انتخاب‌های مقطع/موضوع را بررسی کن.',
        AdvisorErrorKind.invalidResponse =>
          'پاسخ سرویس قابل خواندن نبود.',
        AdvisorErrorKind.serverError => 'خطایی در سرویس رخ داد.',
      };
      result = '$fallback\n\n$hint';
    } catch (e) {
      debugPrint('Advisor request failed: $e');
      result = '$fallback\n\nاتصال به سرویس برقرار نشد؛ لطفاً بعداً دوباره تلاش کن.';
    }

    if (!mounted) return;
    setState(() {
      _answer = result;
      _askingAdvisor = false;
    });
  }

  // ── Tasks ───────────────────────────────────────────────────────
  void _addStudyTask() {
    final task = _newTaskController.text.trim();
    if (task.isEmpty) return;
    setState(() {
      _studyTasks.add(task);
      _newTaskController.clear();
    });
    _saveData();
  }

  void _toggleTask(int index, bool? checked) {
    setState(() {
      if (checked == true) {
        _completedTasks.add(index);
      } else {
        _completedTasks.remove(index);
      }
    });
    _saveData();
  }

  // ── Focus timer ─────────────────────────────────────────────────
  void _toggleFocusTimer() {
    if (_focusRunning) {
      _focusTimer?.cancel();
      setState(() => _focusRunning = false);
      return;
    }
    if (_focusSecondsRemaining <= 0) {
      setState(() => _focusSecondsRemaining = 25 * 60);
    }
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
        _showSnack('دورهٔ تمرکز تمام شد. کمی استراحت کن.');
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

  // ── Exams ───────────────────────────────────────────────────────
  Future<void> _addExam() async {
    final exam = await showDialog<Exam>(
      context: context,
      builder: (_) => const _AddExamDialog(),
    );
    if (exam == null || !mounted) return;
    setState(() => _exams.add(exam));
    await _saveData();
  }

  Future<void> _deleteExam(int index) async {
    final exam = _exams[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف آزمون؟'),
        content: Text('آزمون «${exam.subject}» حذف شود؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _exams.removeAt(index));
    await _saveData();
  }

  // ── Build ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loadError != null) {
      return _buildErrorScreen();
    }
    if (!_localDataLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      body: SafeArea(child: _buildTab()),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'خانه',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            label: 'برنامه من',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_available_outlined),
            label: 'آزمون‌ها',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_border),
            label: 'یادداشت‌ها',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'پروفایل',
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                const SizedBox(height: 12),
                const Text(
                  'بارگذاری اطلاعات با خطا مواجه شد',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _loadError!,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    setState(() => _loadError = null);
                    _loadSavedData();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('تلاش دوباره'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTab() {
    return switch (_tabIndex) {
      0 => _buildHomeTab(),
      1 => _buildPlanTab(),
      2 => _buildExamsTab(),
      3 => _buildNotesTab(),
      _ => _buildProfileTab(),
    };
  }

  // ── Home tab ────────────────────────────────────────────────────
  Widget _buildHomeTab() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text('همراه تحصیلی',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        const Text('از اولین قدم تا آینده‌ای روشن',
            style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 16),
        const Text('مقطع تحصیلی شما',
            style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _stages
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
        const Text('از کجا شروع کنیم؟',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AcademicGoals.all
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
            hintText: 'مثلاً: برای امتحان‌های دو هفتهٔ آینده چطور برنامه‌ریزی کنم؟',
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _askingAdvisor ? null : _askAdvisor,
          icon: _askingAdvisor
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.chat_bubble_outline),
          label: Text(_askingAdvisor ? 'در حال دریافت…' : 'دریافت راهنمایی'),
        ),
        if (_answer != null) ...[
          const SizedBox(height: 12),
          const Text('راهنمای پیشنهادی',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          const SizedBox(height: 8),
          SelectableText(_answer!, style: const TextStyle(height: 1.8)),
        ],
      ],
    );
  }

  // ── Plan tab ────────────────────────────────────────────────────
  Widget _buildPlanTab() {
    final minutes =
        (_focusSecondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds =
        (_focusSecondsRemaining % 60).toString().padLeft(2, '0');
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text('برنامهٔ درسی من',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.softGreenColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              const Text('زمان تمرکز',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              Text(
                '$minutes:$seconds',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: AppColors.seedColor,
                ),
              ),
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
          decoration: const InputDecoration(
            labelText: 'کار یا درس بعدی',
            hintText: 'مثلاً: مرور فصل دوم علوم',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _addStudyTask(),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _addStudyTask,
          icon: const Icon(Icons.add_task_rounded),
          label: const Text('افزودن به برنامه'),
        ),
        const SizedBox(height: 12),
        Text(
          '${_completedTasks.length} از ${_studyTasks.length} انجام‌شده',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.seedColor,
          ),
        ),
        if (_studyTasks.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('هنوز کاری ثبت نشده است', textAlign: TextAlign.center),
          )
        else
          ..._studyTasks.asMap().entries.map(
                (entry) => CheckboxListTile(
                  value: _completedTasks.contains(entry.key),
                  title: Text(entry.value),
                  onChanged: (checked) => _toggleTask(entry.key, checked),
                ),
              ),
      ],
    );
  }

  // ── Exams tab ───────────────────────────────────────────────────
  Widget _buildExamsTab() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text('آزمون‌ها و نتیجه‌ها',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _addExam,
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
          ..._exams.asMap().entries.map((entry) {
            final index = entry.key;
            final exam = entry.value;
            final countdown = exam.isPast
                ? 'تاریخ آزمون گذشته است'
                : exam.isToday
                    ? 'آزمون امروز است'
                    : 'تا آزمون ${exam.daysUntil} روز مانده';
            final scoreLine =
                exam.hasScore ? '\nنمره: ${exam.score} از ۲۰' : '';
            return Card(
              key: ValueKey('exam-$index-${exam.date.toIso8601String()}'),
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(
                  exam.subject,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${exam.date.year}/${exam.date.month}/${exam.date.day} · '
                  '$countdown$scoreLine',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'حذف آزمون',
                  onPressed: () => _deleteExam(index),
                ),
              ),
            );
          }),
      ],
    );
  }

  // ── Notes tab ───────────────────────────────────────────────────
  Widget _buildNotesTab() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text('یادداشت‌های من',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        TextField(
          controller: _notesController,
          minLines: 8,
          maxLines: 16,
          onChanged: (_) => _scheduleSave(),
          decoration: const InputDecoration(
            hintText: 'یادداشت تحصیلی شما…',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _saveData,
          icon: const Icon(Icons.save_outlined),
          label: const Text('ذخیرهٔ یادداشت'),
        ),
      ],
    );
  }

  // ── Profile tab ─────────────────────────────────────────────────
  Widget _buildProfileTab() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text('پروفایل تحصیلی',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        Text('مقطع فعلی: $_stage'),
                Text('موضوع منتخب: $_goal'),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const AiSettingsPage(),
            ),
          ),
          icon: const Icon(Icons.smart_toy_outlined),
          label: const Text('تنظیمات هوش مصنوعی'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _clearSavedData,
          icon: const Icon(Icons.delete_forever_outlined),
          label: const Text('حذف اطلاعات ذخیره‌شده'),
        ),
      ],
    );
  }
}

// ── Add exam dialog ─────────────────────────────────────────────────
class _AddExamDialog extends StatefulWidget {
  const _AddExamDialog();

  @override
  State<_AddExamDialog> createState() => _AddExamDialogState();
}

class _AddExamDialogState extends State<_AddExamDialog> {
  final _subjectController = TextEditingController();
  final _scoreController = TextEditingController();
  DateTime _examDate = DateTime.now().add(const Duration(days: 7));
  String? _errorText;

  @override
  void dispose() {
    _subjectController.dispose();
    _scoreController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _examDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (selected != null && mounted) {
      setState(() => _examDate = selected);
    }
  }

  void _submit() {
    final subject = _subjectController.text.trim();
    if (subject.isEmpty) {
      setState(() => _errorText = 'نام درس یا آزمون را وارد کنید.');
      return;
    }
    final scoreText = _scoreController.text.trim();
    final score = scoreText.isEmpty ? null : double.tryParse(scoreText);
    if (scoreText.isNotEmpty && (score == null || score < 0 || score > 20)) {
      setState(() => _errorText = 'نمره باید عددی بین ۰ و ۲۰ باشد.');
      return;
    }
    Navigator.pop(
      context,
      Exam(
        subject: subject,
        date: _examDate,
        score: score?.toString() ?? '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ثبت آزمون'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _subjectController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'نام درس یا آزمون'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(
                'تاریخ: ${_examDate.year}/${_examDate.month}/${_examDate.day}',
              ),
            ),
            TextField(
              controller: _scoreController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'نمره (اختیاری از ۲۰)',
              ),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorText!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('انصراف'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('ذخیره آزمون'),
        ),
      ],
    );
  }
}
