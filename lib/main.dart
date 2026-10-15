import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _advisorApiBaseUrl = String.fromEnvironment('ADVISOR_API_BASE_URL');

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
        color: Colors.white, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),
    ),
    home: const Directionality(textDirection: TextDirection.rtl, child: AdvisorHomeScreen()),
  );
}

class AdvisorHomeScreen extends StatefulWidget {
  const AdvisorHomeScreen({super.key});
  @override
  State<AdvisorHomeScreen> createState() => _AdvisorHomeScreenState();
}

class StudyAssessmentPage extends StatefulWidget {
  const StudyAssessmentPage({super.key});

  @override
  State<StudyAssessmentPage> createState() => _StudyAssessmentPageState();
}

class _StudyAssessmentPageState extends State<StudyAssessmentPage> {
  final List<int?> _answers = List<int?>.filled(4, null);
  bool _showResult = false;
  static const _questions = [
    'وقتی درس را می‌خوانی، چقدر می‌توانی بدون نگاه‌کردن به کتاب آن را توضیح بدهی؟',
    'چقدر زود مطالبی را که قبلاً خوانده‌ای فراموش می‌کنی؟',
    'وقتی پاسخ یک سؤال را اشتباه می‌دهی، چقدر علت اشتباه را بررسی می‌کنی؟',
    'برنامهٔ مطالعه‌ات چقدر با زمان و انرژی واقعی تو هماهنگ است؟',
  ];
  static const _options = [
    ['به‌سختی', 'تا حدی', 'معمولاً خوب'],
    ['خیلی زود', 'گاهی', 'با مرور معمولاً یادم می‌ماند'],
    ['به‌ندرت', 'گاهی', 'تقریباً همیشه'],
    ['اغلب سنگین است', 'تا حدی هماهنگ است', 'واقع‌بینانه و قابل اجراست'],
  ];

  @override
  Widget build(BuildContext context) {
    final answered = _answers.whereType<int>().length;
    final score = _answers.asMap().entries.fold<int>(0, (sum, entry) {
      final answer = entry.value;
      if (answer == null) return sum;
      return sum + (entry.key == 1 ? 2 - answer : answer);
    });
    final complete = answered == _questions.length;
    final advice = score <= 3
      ? 'از زمان کوتاه شروع کن، هر بار یک هدف کوچک تعیین کن و پس از مطالعه، مطلب را با زبان خودت توضیح بده.'
      : score <= 6
        ? 'روش مطالعه‌ات چند نقطهٔ قوت دارد. مرور فاصله‌دار و بررسی اشتباه‌ها را منظم‌تر کن و برنامه را با انرژی واقعی خود هماهنگ نگه دار.'
        : 'پایهٔ مناسبی برای مطالعهٔ مؤثر داری. برای تثبیت نتیجه، از خودآزمایی، مرور دوره‌ای و تحلیل اشتباه‌ها استفاده کن.';
    return Scaffold(
      appBar: AppBar(title: const Text('ارزیابی روش مطالعه')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        const Text('به چهار پرسش زیر صادقانه پاسخ بده. این ارزیابی کوتاه، آزمون علمی یا تشخیص تخصصی نیست؛ فقط برای شروع گفت‌وگو دربارهٔ عادت‌های مطالعه است.',
          style: TextStyle(height: 1.8)),
        const SizedBox(height: 12),
        LinearProgressIndicator(value: answered / _questions.length,
          minHeight: 6, borderRadius: BorderRadius.circular(8)),
        const SizedBox(height: 6),
        Text('$answered از ${_questions.length} پرسش پاسخ داده شده'),
        const SizedBox(height: 12),
        ...List.generate(_questions.length, (index) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(padding: const EdgeInsets.all(14), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${index + 1}. ${_questions[index]}',
                style: const TextStyle(fontWeight: FontWeight.w800, height: 1.6)),
              const SizedBox(height: 6),
              RadioGroup<int>(
                groupValue: _answers[index],
                onChanged: (value) => setState(() {
                  _answers[index] = value;
                  _showResult = false;
                }),
                child: Column(children: List.generate(3, (option) => RadioListTile<int>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: option,
                  title: Text(_options[index][option]),
                ))),
              ),
            ],
          )),
        )),
        FilledButton.icon(
          onPressed: complete ? () => setState(() => _showResult = true) : null,
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('نمایش جمع‌بندی'),
        ),
        if (complete && _showResult) ...[
          const SizedBox(height: 14),
          Container(padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: const Color(0xFFE3F2ED),
              borderRadius: BorderRadius.circular(18)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('امتیاز راهنمایی: $score از 8',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(advice, style: const TextStyle(height: 1.8)),
              const SizedBox(height: 8),
              const Text('این امتیاز نمرهٔ هوش یا توانایی تحصیلی نیست و نباید به‌تنهایی مبنای انتخاب رشته یا تصمیم مهم قرار بگیرد.',
                style: TextStyle(fontSize: 12, height: 1.7, color: Colors.black54)),
            ]),
          ),
        ],
      ]),
    );
  }
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
  bool _localDataLoaded = false;
  Timer? _focusTimer;
  int _focusSecondsRemaining = 25 * 60;
  bool _focusRunning = false;
  String _stage = 'متوسطه اول';
  String _goal = 'برنامه‌ریزی درسی';
  String _tab = 'خانه';
  bool _showGuide = false;
  String? _answer;
  static const stages = ['ابتدایی', 'متوسطه اول', 'متوسطه دوم', 'کنکوری', 'دانشجو', 'فارغ‌التحصیل'];

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _stage = prefs.getString('profile_stage') ?? _stage;
      _goal = prefs.getString('profile_goal') ?? _goal;
      _studyTasks
        ..clear()
        ..addAll(prefs.getStringList('study_tasks') ?? []);
      _completedTasks
        ..clear()
        ..addAll((prefs.getStringList('completed_tasks') ?? [])
          .map(int.tryParse).whereType<int>());
      _taskDueDates
        ..clear()
        ..addAll((jsonDecode(prefs.getString('study_task_due_dates') ?? '{}') as Map<String, dynamic>)
          .map((key, value) => MapEntry(key, value.toString())));
      _notesController.text = prefs.getString('study_notes') ?? '';
      _exams
        ..clear()
        ..addAll((jsonDecode(prefs.getString('study_exams') ?? '[]') as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map((exam) => exam.map((key, value) => MapEntry(key, value.toString()))));
      _studySessions
        ..clear()
        ..addAll((jsonDecode(prefs.getString('study_sessions') ?? '[]') as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map((session) => session.map((key, value) => MapEntry(key, value.toString()))));
      _localDataLoaded = true;
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_stage', _stage);
    await prefs.setString('profile_goal', _goal);
    await prefs.setStringList('study_tasks', _studyTasks);
    await prefs.setStringList('completed_tasks',
      _completedTasks.map((index) => index.toString()).toList());
    await prefs.setString('study_task_due_dates', jsonEncode(_taskDueDates));
    await prefs.setString('study_notes', _notesController.text);
    await prefs.setString('study_exams', jsonEncode(_exams));
    await prefs.setString('study_sessions', jsonEncode(_studySessions));
  }

  Future<void> _clearSavedData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف اطلاعات ذخیره‌شده؟'),
        content: const Text('برنامه‌ها، یادداشت‌ها و ترجیحات محلی این اپ از روی این دستگاه حذف می‌شوند.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف اطلاعات')),
        ],
      ),
    );
    if (confirmed != true) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    setState(() {
      _stage = 'متوسطه اول';
      _goal = 'برنامه‌ریزی درسی';
      _studyTasks.clear();
      _completedTasks.clear();
      _taskDueDates.clear();
      _exams.clear();
      _studySessions.clear();
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

  String _stageAdvice() => switch (_stage) {
    'ابتدایی' => 'درس را به بخش‌های کوتاه ۱۰ تا ۱۵ دقیقه‌ای تقسیم کن، بعد از هر بخش کمی استراحت داشته باش و اگر مطلبی سخت بود از معلم یا خانواده کمک بگیر.',
    'متوسطه اول' => 'برای هر درس هدف کوچک و مشخص تعیین کن، تکالیف را به شب آخر موکول نکن و بعد از مطالعه با چند سؤال کوتاه مطمئن شو مطلب را فهمیده‌ای.',
    'متوسطه دوم' => 'درس‌های مدرسه را با مرور منظم ترکیب کن، مباحث دشوار را زودتر مشخص کن و برای هر هفته زمان جبرانی در نظر بگیر.',
    'کنکوری' => 'برنامه را بر پایهٔ سطح فعلی و زمان باقی‌مانده بچین؛ حل تست، تحلیل اشتباه‌ها و مرور فاصله‌دار را کنار هم نگه دار و خواب را قربانی مطالعه نکن.',
    'دانشجو' => 'موعد تحویل پروژه‌ها و امتحان‌ها را از قبل ثبت کن، کارهای بزرگ را به گام‌های کوچک بشکن و برای مطالعهٔ مستقل و استراحت تعادل نگه دار.',
    _ => 'هدف شغلی یا تحصیلی بعدی را مشخص کن، مهارت‌های موردنیاز را فهرست کن و پیش از تصمیم بزرگ، اطلاعات را از چند منبع معتبر بررسی کن.',
  };

  String _goalAdvice() => switch (_goal) {
    'برنامه‌ریزی درسی' => 'امروز سه کار مهم را انتخاب کن، زمان تقریبی هرکدام را مشخص کن و در پایان روز برنامه را بر اساس آنچه واقعاً انجام دادی اصلاح کن.',
    'انتخاب رشته' => 'علاقه‌ها، توانایی‌ها، شرایط و محدودیت‌هایت را جداگانه بنویس؛ تصمیم نهایی را فقط بر پایهٔ نظر دیگران یا یک آزمون نگذار.',
    'آزمون و کنکور' => 'پس از هر آزمون، اشتباه‌ها را به دانشی، بی‌دقتی و مدیریت زمان دسته‌بندی کن و برای هر دسته یک اقدام اصلاحی در نظر بگیر.',
    _ => 'مسیرهای تحصیلی و شغلی موردعلاقه را مقایسه کن، مهارت‌های لازم و فرصت‌های واقعی را بررسی کن و یک قدم کم‌هزینه برای تجربه‌کردن مسیر انتخاب کن.',
  };

  Future<void> _askAdvisor() async {
    final question = _questionController.text.trim();
    if (question.isEmpty) {
      setState(() => _answer = 'لطفاً ابتدا سؤال یا دغدغهٔ تحصیلی‌تان را بنویسید.');
      return;
    }

    setState(() {
      _answer = 'راهنمای آغازین متناسب با اطلاعات انتخاب‌شده\n\n'
        'مقطع: $_stage\nموضوع: $_goal\n\n'
        'پیشنهاد برای مقطع شما: ${_stageAdvice()}\n\n'
        'پیشنهاد دربارهٔ موضوع انتخابی: ${_goalAdvice()}\n\n'
        'سؤال شما: «$question»\n'
        'یک اقدام کوچک و قابل سنجش برای امروز انتخاب کنید و نتیجه را بعداً ارزیابی کنید.\n\n'
        'این راهنمای قاعده‌محور و عمومی است؛ پاسخ اختصاصی هوش مصنوعی فقط در صورت اتصال موفق سرویس ارائه می‌شود و جایگزین مشاور مدرسه یا متخصص نیست.';
    });

    // No network request is made unless a server URL is explicitly configured at build time.
    if (_advisorApiBaseUrl.trim().isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse('${_advisorApiBaseUrl.replaceFirst(RegExp(r'/+$'), '')}/api/advice'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'stage': _stage, 'goal': _goal, 'question': question}),
      ).timeout(const Duration(seconds: 35));
      if (response.statusCode != 200) {
        throw const FormatException('Advisor service returned an error');
      }
      final payload = jsonDecode(response.body);
      final aiAnswer = payload is Map<String, dynamic> ? payload['answer'] : null;
      if (aiAnswer is! String || aiAnswer.trim().isEmpty) {
        throw const FormatException('Advisor service returned an invalid response');
      }
      if (!mounted) return;
      setState(() => _answer =
        'پاسخ مشاور هوش مصنوعی\n\n$aiAnswer\n\n'
        'پاسخ تولیدشده با هوش مصنوعی ممکن است خطا داشته باشد. اطلاعات مهم آموزشی و انتخاب رشته را با خانواده یا مشاور مدرسه نیز بررسی کن.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _answer =
        'اتصال به سرویس مشاوره برقرار نشد؛ راهنمای عمومی زیر را فعلاً در نظر بگیر.\n\n$_answer');
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

  Widget _focusTimerCard() {
    final minutes = (_focusSecondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_focusSecondsRemaining % 60).toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2ED),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Row(children: [
          Icon(Icons.timer_outlined, color: Color(0xFF287D72)),
          SizedBox(width: 8),
          Expanded(child: Text('زمان تمرکز',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
          Text('۲۵ دقیقه', style: TextStyle(color: Color(0xFF287D72))),
        ]),
        const SizedBox(height: 12),
        Text('$minutes:$seconds',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900,
            color: Color(0xFF287D72))),
        const SizedBox(height: 4),
        Text(_focusSecondsRemaining == 0
          ? 'آفرین! یک نوبت تمرکز تمام شد؛ کمی استراحت کن.'
          : _focusRunning ? 'فقط روی یک کار تمرکز کن و اعلان‌ها را کنار بگذار.'
          : 'یک کار انتخاب کن و وقتی آماده‌ای شروع کن.',
          textAlign: TextAlign.center, style: const TextStyle(height: 1.6)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: FilledButton.icon(
            onPressed: _toggleFocusTimer,
            icon: Icon(_focusRunning ? Icons.pause_rounded : Icons.play_arrow_rounded),
            label: Text(_focusRunning ? 'مکث' : _focusSecondsRemaining == 0 ? 'دوباره شروع کن' : 'شروع تمرکز'))),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: _resetFocusTimer,
            tooltip: 'شروع دوباره از ۲۵ دقیقه',
            icon: const Icon(Icons.restart_alt_rounded)),
        ]),
      ]),
    );
  }


  Future<void> _addStudySession() async {
    final subjectController = TextEditingController();
    final minutesController = TextEditingController(text: '25');
    int confidence = 3;
    String? errorText;
    final session = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('ثبت مطالعه'),
          content: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(controller: subjectController, autofocus: true,
                decoration: const InputDecoration(labelText: 'نام درس', hintText: 'مثلاً: علوم یا ریاضی')),
              const SizedBox(height: 12),
              TextField(controller: minutesController, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'مدت مطالعه به دقیقه')),
              const SizedBox(height: 16),
              const Text('میزان تسلط فعلی خودت را ارزیابی کن', style: TextStyle(fontWeight: FontWeight.w800)),
              RadioGroup<int>(
                groupValue: confidence,
                onChanged: (value) => setDialogState(() => confidence = value ?? 3),
                child: Column(children: List.generate(5, (index) => RadioListTile<int>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: index + 1,
                  title: Text(['۱ ـ خیلی کم','۲ ـ کم','۳ ـ متوسط','۴ ـ خوب','۵ ـ خیلی خوب'][index]),
                ))),
              ),
              if (errorText != null) Text(errorText!, style: const TextStyle(color: Colors.red)),
            ],
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('انصراف')),
            FilledButton(onPressed: () {
              final subject = subjectController.text.trim();
              final minutes = int.tryParse(minutesController.text.trim());
              if (subject.isEmpty) {
                setDialogState(() => errorText = 'نام درس را وارد کن.');
                return;
              }
              if (minutes == null || minutes < 1 || minutes > 1440) {
                setDialogState(() => errorText = 'مدت مطالعه باید بین ۱ تا ۱۴۴۰ دقیقه باشد.');
                return;
              }
              Navigator.pop(dialogContext, {
                'subject': subject, 'minutes': minutes.toString(),
                'confidence': confidence.toString(), 'date': DateTime.now().toIso8601String(),
              });
            }, child: const Text('ثبت مطالعه')),
          ],
        ),
      ),
    );
    // Dialog pop animations can keep TextFields mounted briefly after showDialog completes.
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      subjectController.dispose();
      minutesController.dispose();
    });
    if (session == null || !mounted) return;
    setState(() => _studySessions.add(session));
    await _saveData();
  }

  Widget _studyProgressSection() {
    final subjects = <String, List<Map<String, String>>>{};
    for (final session in _studySessions) {
      subjects.putIfAbsent(session['subject']!, () => []).add(session);
    }
    final totalMinutes = _studySessions.fold<int>(0,
      (sum, session) => sum + (int.tryParse(session['minutes'] ?? '') ?? 0));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2EAE6))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('گزارش پیشرفت درس‌ها', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text('زمان مطالعه و میزان تسلطی را که خودت احساس می‌کنی ثبت کن؛ این امتیاز خودارزیابی است، نه آزمون علمی.',
          style: TextStyle(color: Colors.black54, height: 1.7, fontSize: 12)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _progressMetric('جلسه‌های ثبت‌شده', _studySessions.length.toString())),
          const SizedBox(width: 10),
          Expanded(child: _progressMetric('مجموع مطالعه', '$totalMinutes دقیقه')),
        ]),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: _localDataLoaded ? _addStudySession : null,
          icon: const Icon(Icons.add_chart_rounded), label: const Text('ثبت جلسهٔ مطالعه')),
        if (_studySessions.isEmpty) ...[
          const SizedBox(height: 12),
          const Text('هنوز جلسه‌ای ثبت نشده است.', textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54)),
        ] else ...[
          const SizedBox(height: 12),
          ...subjects.entries.map((entry) {
            final minutes = entry.value.fold<int>(0,
              (sum, session) => sum + (int.tryParse(session['minutes'] ?? '') ?? 0));
            final confidence = entry.value.fold<int>(0,
              (sum, session) => sum + (int.tryParse(session['confidence'] ?? '') ?? 3)) / entry.value.length;
            return Padding(padding: const EdgeInsets.only(bottom: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w800))),
                  Text('$minutes دقیقه · تسلط ${confidence.toStringAsFixed(1)}/5',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF287D72))),
                ]),
                const SizedBox(height: 6),
                LinearProgressIndicator(value: confidence / 5, minHeight: 6,
                  borderRadius: BorderRadius.circular(8), color: const Color(0xFF287D72),
                  backgroundColor: const Color(0xFFE3F2ED)),
                Align(alignment: Alignment.centerLeft,
                  child: Text('${entry.value.length} جلسه',
                    style: const TextStyle(fontSize: 11, color: Colors.black54))),
              ]),
            );
          }),
          Align(alignment: Alignment.centerLeft, child: TextButton.icon(
            onPressed: () async {
              final confirmed = await showDialog<bool>(context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('حذف گزارش پیشرفت؟'),
                  content: const Text('همهٔ جلسه‌های مطالعهٔ ثبت‌شده حذف می‌شوند.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('انصراف')),
                    FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حذف')),
                  ],
                ));
              if (confirmed == true && mounted) {
                setState(() => _studySessions.clear());
                await _saveData();
              }
            },
            icon: const Icon(Icons.delete_outline_rounded), label: const Text('پاک‌کردن گزارش پیشرفت'))),
        ],
      ]),
    );
  }

  Widget _progressMetric(String label, String value) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xFFE3F2ED), borderRadius: BorderRadius.circular(14)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF287D72))),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 11, height: 1.4)),
    ]),
  );

  Future<void> _setTaskDueDate(String task) async {
    final existing = _taskDueDates[task];
    final initial = existing == null ? DateTime.now().add(const Duration(days: 1)) : DateTime.parse(existing);
    final selected = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(DateTime.now().subtract(const Duration(days: 365))) ? DateTime.now() : initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      helpText: 'موعد انجام کار را انتخاب کن',
    );
    if (selected == null || !mounted) return;
    setState(() => _taskDueDates[task] = DateTime(selected.year, selected.month, selected.day).toIso8601String());
    await _saveData();
  }

  String _taskScheduleLabel(String task) {
    final raw = _taskDueDates[task];
    if (raw == null) return 'بدون موعد';
    final date = DateTime.parse(raw);
    final today = DateTime.now();
    final days = DateTime(date.year, date.month, date.day).difference(DateTime(today.year, today.month, today.day)).inDays;
    final dateText = '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
    if (_completedTasks.contains(_studyTasks.indexOf(task))) return 'انجام‌شده · $dateText';
    if (days < 0) return 'عقب‌افتاده · $dateText';
    if (days == 0) return 'موعد امروز · $dateText';
    if (days == 1) return 'موعد فردا · $dateText';
    return 'موعد $dateText · $days روز دیگر';
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

  Widget _studyPlannerPage() => ListView(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
    children: [
      Row(children: [
        IconButton(onPressed: () => setState(() => _tab = 'خانه'),
          icon: const Icon(Icons.arrow_forward_rounded), tooltip: 'بازگشت به خانه'),
        const SizedBox(width: 6),
        const Expanded(child: Text('برنامهٔ درسی من',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
      ]),
      const SizedBox(height: 8),
      const Text('کارهای درسی را ثبت کن و پس از انجام، تیک بزن.',
        style: TextStyle(color: Colors.black54, height: 1.7)),
      const SizedBox(height: 18),
      _focusTimerCard(),
      const SizedBox(height: 16),
      _studyProgressSection(),
      const SizedBox(height: 16),
      Container(padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2EAE6))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (!_localDataLoaded)
            const Padding(padding: EdgeInsets.only(bottom: 10), child: LinearProgressIndicator()),
          TextField(controller: _newTaskController,
            enabled: _localDataLoaded,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _addStudyTask(),
            decoration: InputDecoration(
              labelText: 'کار یا درس بعدی',
              hintText: 'مثلاً: مرور فصل دوم علوم',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: _localDataLoaded ? _addStudyTask : null,
            icon: const Icon(Icons.add_task_rounded), label: const Text('افزودن به برنامه')),
        ]),
      ),
      const SizedBox(height: 18),
      Builder(builder: (context) {
        final today = DateTime.now();
        final overdue = _studyTasks.asMap().entries.where((entry) {
          if (_completedTasks.contains(entry.key)) return false;
          final raw = _taskDueDates[entry.value];
          if (raw == null) return false;
          final date = DateTime.parse(raw);
          return DateTime(date.year, date.month, date.day).isBefore(DateTime(today.year, today.month, today.day));
        }).length;
        final dueToday = _studyTasks.asMap().entries.where((entry) {
          if (_completedTasks.contains(entry.key)) return false;
          final raw = _taskDueDates[entry.value];
          if (raw == null) return false;
          final date = DateTime.parse(raw);
          return date.year == today.year && date.month == today.month && date.day == today.day;
        }).length;
        return Container(padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFE3F2ED), borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Expanded(child: Text('موعد امروز: $dueToday', style: const TextStyle(fontWeight: FontWeight.w800))),
            Expanded(child: Text('عقب‌افتاده: $overdue', style: TextStyle(fontWeight: FontWeight.w800, color: overdue > 0 ? Colors.red.shade700 : const Color(0xFF287D72)))),
          ]));
      }),
      const SizedBox(height: 12),
      Row(children: [
        const Expanded(child: Text('کارهای امروز',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
        Text('${_completedTasks.length} از ${_studyTasks.length} انجام‌شده',
          style: const TextStyle(color: Color(0xFF287D72), fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 10),
      if (_studyTasks.isEmpty)
        Container(padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: const Color(0xFFEAF3F0), borderRadius: BorderRadius.circular(18)),
          child: const Column(children: [
            Icon(Icons.event_note_outlined, size: 34, color: Color(0xFF287D72)),
            SizedBox(height: 8),
            Text('هنوز کاری ثبت نشده است', style: TextStyle(fontWeight: FontWeight.w800)),
            SizedBox(height: 4),
            Text('اولین کار درسی خود را در کادر بالا بنویس.',
              textAlign: TextAlign.center, style: TextStyle(height: 1.6)),
          ]),
        )
      else
        ..._studyTasks.asMap().entries.map((entry) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: CheckboxListTile(
            value: _completedTasks.contains(entry.key),
            onChanged: (checked) {
              setState(() {
                if (checked == true) { _completedTasks.add(entry.key); }
                else { _completedTasks.remove(entry.key); }
              });
              _saveData();
            },
            title: Text(entry.value),
            subtitle: Text(_taskScheduleLabel(entry.value),
              style: TextStyle(height: 1.5, color: _taskDueDates[entry.value] != null && !_completedTasks.contains(entry.key) && DateTime.parse(_taskDueDates[entry.value]!).isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)) ? Colors.red.shade700 : Colors.black54)),
            controlAffinity: ListTileControlAffinity.leading,
            secondary: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(tooltip: 'تنظیم موعد', icon: const Icon(Icons.calendar_month_outlined),
                onPressed: () => _setTaskDueDate(entry.value)),
              IconButton(
              tooltip: 'حذف کار',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () {
                setState(() {
                  final updatedCompleted = _completedTasks
                    .where((index) => index != entry.key)
                    .map((index) => index > entry.key ? index - 1 : index)
                    .toSet();
                  _studyTasks.removeAt(entry.key);
                  _completedTasks
                    ..clear()
                    ..addAll(updatedCompleted);
                });
                _taskDueDates.remove(entry.value);
                _saveData();
              }
              ),
            ]),
          ),
        )),
      const SizedBox(height: 12),
      const Text('کارها، وضعیت انجام و یادداشت‌ها روی همین دستگاه ذخیره می‌شوند. برای انتقال به گوشی دیگر، همگام‌سازی ابری در نسخهٔ بعدی لازم است.',
        style: TextStyle(color: Colors.black54, fontSize: 12, height: 1.7)),
    ],
  );

  Future<void> _addExam() async {
    final subjectController = TextEditingController();
    final scoreController = TextEditingController();
    DateTime examDate = DateTime.now().add(const Duration(days: 7));
    String? validationMessage;
    final exam = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('ثبت آزمون'),
          content: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(controller: subjectController, autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'نام درس یا آزمون',
                  hintText: 'مثلاً: ریاضی فصل سوم')),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final selected = await showDatePicker(
                    context: dialogContext,
                    initialDate: examDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                    helpText: 'تاریخ آزمون را انتخاب کن',
                  );
                  if (selected != null) {
                    setDialogState(() {
                      examDate = selected;
                      validationMessage = null;
                    });
                  }
                },
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text('تاریخ: ${examDate.year}/${examDate.month.toString().padLeft(2, '0')}/${examDate.day.toString().padLeft(2, '0')}'),
              ),
              const SizedBox(height: 8),
              TextField(controller: scoreController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'نمره (اختیاری از ۲۰)',
                  hintText: 'مثلاً ۱۷٫۵')),
              if (validationMessage != null) ...[
                const SizedBox(height: 8),
                Text(validationMessage!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext),
              child: const Text('انصراف')),
            FilledButton(
              onPressed: () {
                final subject = subjectController.text.trim();
                final scoreText = scoreController.text.trim();
                final score = scoreText.isEmpty ? null : double.tryParse(scoreText);
                if (subject.isEmpty) {
                  setDialogState(() => validationMessage = 'نام درس یا آزمون را وارد کن.');
                  return;
                }
                if (scoreText.isNotEmpty && (score == null || score < 0 || score > 20)) {
                  setDialogState(() => validationMessage = 'نمره باید عددی بین صفر تا ۲۰ باشد.');
                  return;
                }
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
    // Let the dialog's reverse transition finish before disposing its TextField controllers.
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      subjectController.dispose();
      scoreController.dispose();
    });
    if (exam == null || !mounted) return;
    setState(() => _exams.add(exam));
    await _saveData();
  }

  void _createReviewPlan(Map<String, String> exam) {
    final subject = exam['subject'] ?? 'درس';
    final date = DateTime.parse(exam['date']!);
    final today = DateTime.now();
    final daysRemaining = DateTime(date.year, date.month, date.day)
      .difference(DateTime(today.year, today.month, today.day)).inDays;
    if (daysRemaining < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تاریخ این آزمون گذشته است؛ می‌توانی کار مرور را دستی اضافه کنی.')),
      );
      return;
    }
    final tasks = [
      'مرور خلاصه‌ها و نکته‌های $subject',
      'حل چند سؤال تمرینی از $subject',
      'تحلیل اشتباه‌ها و مرور نهایی $subject',
    ];
    final today = DateTime.now();
    final daySpan = daysRemaining.clamp(0, 3);
    final dueDates = [
      today.add(Duration(days: (daySpan / 3).floor())),
      today.add(Duration(days: (daySpan * 2 / 3).floor())),
      date,
    ];
    setState(() {
      for (var i = 0; i < tasks.length; i++) {
        final task = tasks[i];
        if (!_studyTasks.contains(task)) _studyTasks.add(task);
        _taskDueDates[task] = DateTime(dueDates[i].year, dueDates[i].month, dueDates[i].day).toIso8601String();
      }
      _tab = 'برنامه من';
    });
    _saveData();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('سه گام مرور برای $subject به برنامه اضافه شد.')),
    );
  }
  Widget _examsPage() {
    final sortedExams = [..._exams]
      ..sort((a, b) => DateTime.parse(a['date']!).compareTo(DateTime.parse(b['date']!)));
    final scored = _exams.where((exam) => (double.tryParse(exam['score'] ?? '') ?? -1) >= 0).toList();
    final average = scored.isEmpty ? null : scored
      .map((exam) => double.parse(exam['score']!))
      .reduce((a, b) => a + b) / scored.length;
    return ListView(padding: const EdgeInsets.fromLTRB(18,18,18,28), children: [
      Row(children: [
        IconButton(onPressed: () => setState(() => _tab = 'خانه'),
          icon: const Icon(Icons.arrow_forward_rounded), tooltip: 'بازگشت به خانه'),
        const SizedBox(width: 6),
        const Expanded(child: Text('آزمون‌ها و نتیجه‌ها',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
      ]),
      const SizedBox(height: 8),
      const Text('تاریخ آزمون‌ها را ثبت کن تا زمان باقی‌مانده و نتیجه‌ها را یکجا ببینی.',
        style: TextStyle(color: Colors.black54, height: 1.7)),
      const SizedBox(height: 16),
      if (!_localDataLoaded) const LinearProgressIndicator(),
      if (_exams.isNotEmpty) Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFFE3F2ED),
          borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          const Icon(Icons.insights_rounded, color: Color(0xFF287D72), size: 30),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${_exams.length} آزمون ثبت‌شده',
              style: const TextStyle(fontWeight: FontWeight.w900)),
            Text(average == null ? 'هنوز نمره‌ای ثبت نشده است'
              : 'میانگین نمره‌های ثبت‌شده: ${average.toStringAsFixed(1)} از ۲۰',
              style: const TextStyle(height: 1.6)),
          ])),
        ]),
      ),
      const SizedBox(height: 14),
      FilledButton.icon(onPressed: _localDataLoaded ? _addExam : null,
        icon: const Icon(Icons.add_circle_outline_rounded),
        label: const Padding(padding: EdgeInsets.symmetric(vertical: 12),
          child: Text('افزودن آزمون یا امتحان'))),
      const SizedBox(height: 12),
      if (_exams.isEmpty) Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2EAE6))),
        child: const Column(children: [
          Icon(Icons.event_available_outlined, size: 38, color: Color(0xFF287D72)),
          SizedBox(height: 8),
          Text('هنوز آزمونی ثبت نشده است',
            style: TextStyle(fontWeight: FontWeight.w800)),
          SizedBox(height: 5),
          Text('امتحان مدرسه، آزمون آزمایشی یا موعد مهم بعدی را اضافه کن.',
            textAlign: TextAlign.center, style: TextStyle(height: 1.7)),
        ]),
      ) else ...sortedExams.map((exam) {
        final date = DateTime.parse(exam['date']!);
        final today = DateTime.now();
        final days = DateTime(date.year, date.month, date.day)
          .difference(DateTime(today.year, today.month, today.day)).inDays;
        final countdown = days < 0 ? 'تاریخ آزمون گذشته است'
          : days == 0 ? 'آزمون امروز است'
          : 'تا آزمون $days روز مانده';
        final score = exam['score'] ?? '';
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFDCEFEA),
              child: Icon(days < 0 ? Icons.check_circle_outline : Icons.event_note,
                color: const Color(0xFF287D72))),
            title: Text(exam['subject']!, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Padding(padding: const EdgeInsets.only(top: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}  •  $countdown'
                  '${score.isEmpty ? '' : '\nنمره: $score از ۲۰'}',
                  style: const TextStyle(height: 1.6)),
                if (days >= 0)
                  TextButton.icon(
                    onPressed: () => _createReviewPlan(exam),
                    icon: const Icon(Icons.playlist_add_check_rounded, size: 18),
                    label: const Text('ساخت برنامهٔ مرور'),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                  ),
              ])),
            isThreeLine: true,
            trailing: IconButton(
              tooltip: 'حذف آزمون',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () {
                setState(() => _exams.remove(exam));
                _saveData();
              },
            ),
          ),
        );
      }),
      const SizedBox(height: 10),
      const Text('این اطلاعات فقط روی همین دستگاه نگهداری می‌شود؛ تاریخ و نمره را خودت ثبت می‌کنی و اپ به سامانهٔ رسمی مدرسه یا آزمون متصل نیست.',
        style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.7)),
    ]);
  }

  Widget _notesPage() => ListView(padding: const EdgeInsets.fromLTRB(18,18,18,28), children: [
    Row(children: [
      IconButton(onPressed: () => setState(() => _tab = 'خانه'),
        icon: const Icon(Icons.arrow_forward_rounded), tooltip: 'بازگشت به خانه'),
      const SizedBox(width: 6),
      const Expanded(child: Text('یادداشت‌های من', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
    ]),
    const SizedBox(height: 8),
    const Text('نکته‌ها، هدف‌ها یا پرسش‌هایی را که می‌خواهی بعداً مرور کنی اینجا بنویس.', style: TextStyle(height: 1.7, color: Colors.black54)),
    const SizedBox(height: 18),
    if (!_localDataLoaded) const LinearProgressIndicator(),
    TextField(controller: _notesController, enabled: _localDataLoaded, minLines: 8, maxLines: 18,
      onChanged: (_) => _saveData(),
      decoration: InputDecoration(hintText: 'یادداشت تحصیلی شما…', filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)))),
    const SizedBox(height: 12),
    FilledButton.icon(onPressed: _localDataLoaded ? _saveData : null, icon: const Icon(Icons.save_outlined), label: const Text('ذخیرهٔ یادداشت')),
    const SizedBox(height: 8),
    const Text('یادداشت‌ها فقط در حافظهٔ محلی این دستگاه ذخیره می‌شوند و همگام‌سازی ابری ندارند.', style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.7)),
  ]);

  Widget _secondaryPage() {
    if (_tab == 'برنامه من') return _studyPlannerPage();
    if (_tab == 'آزمون‌ها') return _examsPage();
    if (_tab == 'یادداشت‌ها') return _notesPage();
    final details = switch (_tab) {
      'برنامه من' => ('برنامهٔ درسی من', 'برنامه‌ریزی متناسب با زمان و هدف شما', Icons.calendar_month_rounded,
        'در نسخهٔ بعدی، درس‌ها، زمان آزاد و تاریخ امتحان‌ها را ثبت می‌کنیم تا برنامه‌ای واقع‌بینانه ساخته شود.'),
      'یادداشت‌ها' => ('یادداشت‌های من', 'نکته‌ها و هدف‌های مهم تحصیلی', Icons.bookmark_border_rounded,
        'اینجا محل نگهداری نکته‌ها، هدف‌ها و یادداشت‌های تحصیلی شما خواهد بود.'),
      _ => ('پروفایل تحصیلی', 'اطلاعات پایه برای راهنمایی دقیق‌تر', Icons.person_outline_rounded,
        'مقطع فعلی: $_stage\nموضوع منتخب: $_goal\nاین ترجیحات روی همین دستگاه ذخیره می‌شوند.'),
    };
    return ListView(padding: const EdgeInsets.fromLTRB(18, 18, 18, 28), children: [
      Row(children: [
        IconButton(onPressed: () => setState(() => _tab = 'خانه'),
          icon: const Icon(Icons.arrow_forward_rounded), tooltip: 'بازگشت به خانه'),
        const SizedBox(width: 6),
        Expanded(child: Text(details.$1, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
      ]),
      const SizedBox(height: 8),
      Text(details.$2, style: const TextStyle(color: Colors.black54, height: 1.7)),
      const SizedBox(height: 22),
      Container(padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE2EAE6))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 56, height: 56,
            decoration: BoxDecoration(color: const Color(0xFFDCEFEA), borderRadius: BorderRadius.circular(18)),
            child: Icon(details.$3, color: const Color(0xFF287D72), size: 30)),
          const SizedBox(height: 18),
          Text(details.$1, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(details.$4, style: const TextStyle(height: 1.8)),
          const SizedBox(height: 18),
          const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline, color: Color(0xFF93620B), size: 20),
            SizedBox(width: 8),
            Expanded(child: Text('این بخش در حال توسعه است؛ فعلاً اطلاعاتی ذخیره نمی‌شود.',
              style: TextStyle(color: Color(0xFF76520F), height: 1.6))),
          ]),
          const SizedBox(height: 16),
          if (_tab == 'پروفایل') ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: _clearSavedData,
              icon: const Icon(Icons.delete_forever_outlined), label: const Text('حذف اطلاعات ذخیره‌شده')),
          ],
          OutlinedButton.icon(
            onPressed: () => setState(() => _tab = 'خانه'),
            icon: const Icon(Icons.home_outlined), label: const Text('بازگشت به صفحهٔ اصلی')),
        ]),
      ),
    ]);
  }

  Widget _header()=>Padding(padding:const EdgeInsets.fromLTRB(20,14,20,4),child:Row(children:[
    Container(width:48,height:48,decoration:BoxDecoration(color:const Color(0xFFDCEFEA),borderRadius:BorderRadius.circular(16)),
      child:const Icon(Icons.auto_awesome,color:Color(0xFF287D72),size:28)),
    const SizedBox(width:12),
    const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('همراه تحصیلی',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900)),
      Text('از اولین قدم تا آینده‌ای روشن',style:TextStyle(fontSize:12,color:Colors.black54)),
    ])),
    IconButton(onPressed:()=>setState(()=>_showGuide=!_showGuide),tooltip:'راهنما',icon:const Icon(Icons.help_outline_rounded)),
  ]));

  Widget _welcomeCard()=>Container(padding:const EdgeInsets.all(20),
    decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF287D72),Color(0xFF3A9B88)],begin:Alignment.topRight,end:Alignment.bottomLeft),borderRadius:BorderRadius.circular(24)),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('مسیر تحصیلی تو، قدم‌به‌قدم',style:TextStyle(color:Colors.white,fontSize:21,fontWeight:FontWeight.w900)),
      const SizedBox(height:8),
      const Text('برای درس خواندن، انتخاب رشته، کنکور یا تصمیم‌های بعد از فارغ‌التحصیلی یک نقطهٔ شروع پیدا کن.',style:TextStyle(color:Colors.white,height:1.7)),
      if(_showGuide)...[const SizedBox(height:12),const Text('مقطع را انتخاب کن، موضوع را مشخص کن و پرسشت را با جزئیات بنویس. پاسخ‌های این نسخه نمونه و عمومی‌اند.',style:TextStyle(color:Colors.white,height:1.6))],
      const SizedBox(height:14),
      Wrap(spacing:8,runSpacing:8,children:[_heroPill(Icons.flag_outlined,'هدف‌گذاری'),_heroPill(Icons.schedule,'برنامهٔ واقع‌بینانه'),_heroPill(Icons.route_outlined,'انتخاب مسیر')]),
    ]));

  Widget _heroPill(IconData icon,String label)=>Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:7),
    decoration:BoxDecoration(color:Colors.white.withValues(alpha:.16),borderRadius:BorderRadius.circular(30)),
    child:Row(mainAxisSize:MainAxisSize.min,children:[Icon(icon,color:Colors.white,size:15),const SizedBox(width:5),Text(label,style:const TextStyle(color:Colors.white,fontSize:11,fontWeight:FontWeight.w600))]));

  Widget _stagePicker()=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Text('مقطع تحصیلی شما',style:TextStyle(fontSize:15,fontWeight:FontWeight.w800)),const SizedBox(height:10),
    Wrap(spacing:8,runSpacing:8,children:stages.map((s)=>ChoiceChip(label:Text(s),selected:_stage==s,
      onSelected:(_) { setState(()=>_stage=s); _saveData(); },selectedColor:const Color(0xFFDCEFEA),
      side:BorderSide(color:_stage==s?const Color(0xFF287D72):const Color(0xFFE2E9E6)),
      labelStyle:TextStyle(fontWeight:_stage==s?FontWeight.w800:FontWeight.w500))).toList()),
  ]);

  Widget _goalCard(IconData icon,String title,String subtitle){
    final selected=_goal==title;
    return InkWell(borderRadius:BorderRadius.circular(20),onTap:() { setState(()=>_goal=title); _saveData(); },
      child:Container(padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:selected?const Color(0xFFE3F2ED):Colors.white,borderRadius:BorderRadius.circular(20),border:Border.all(color:selected?const Color(0xFF287D72):const Color(0xFFE6ECE9))),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Icon(icon,color:const Color(0xFF287D72),size:27),const Spacer(),
          Text(title,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:14)),const SizedBox(height:4),
          Text(subtitle,style:const TextStyle(fontSize:11,color:Colors.black54,height:1.4),maxLines:2,overflow:TextOverflow.ellipsis),
        ])));
  }

  Widget _questionCard()=>Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Text('موضوع: $_goal',style:const TextStyle(fontWeight:FontWeight.w700,color:Color(0xFF287D72))),const SizedBox(height:12),
    TextField(controller:_questionController,minLines:3,maxLines:6,
      decoration:InputDecoration(hintText:'مثلاً: برای امتحان‌های دو هفتهٔ آینده چطور برنامه‌ریزی کنم؟',filled:true,fillColor:const Color(0xFFF5F8F7),border:OutlineInputBorder(borderRadius:BorderRadius.circular(14),borderSide:BorderSide.none))),
    const SizedBox(height:12),
    FilledButton.icon(onPressed:_askAdvisor,icon:const Icon(Icons.chat_bubble_outline_rounded),label:const Padding(padding:EdgeInsets.symmetric(vertical:13),child:Text('دریافت راهنمایی'))),
  ])));

  Widget _answerCard()=>Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Row(children:[Icon(Icons.lightbulb_outline,color:Color(0xFF287D72)),SizedBox(width:8),Text('راهنمای پیشنهادی',style:TextStyle(fontWeight:FontWeight.w900,fontSize:17))]),
    const SizedBox(height:12),SelectableText(_answer!,style:const TextStyle(height:1.8)),
  ])));

  Widget _privacyNote()=>Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:const Color(0xFFFFF3D8),borderRadius:BorderRadius.circular(16)),
    child:const Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Icon(Icons.info_outline,color:Color(0xFF93620B)),SizedBox(width:10),
      Expanded(child:Text('برنامه‌ها و یادداشت‌ها روی همین دستگاه ذخیره می‌شوند. اگر اتصال هوش مصنوعی در نسخه نصب‌شده فعال باشد، پرسش برای پاسخ‌گویی به سرور ارسال می‌شود؛ اطلاعات حساس وارد نکنید. تصمیم‌های مهم آموزشی را با خانواده و مشاور مدرسه نیز بررسی کنید.',style:TextStyle(height:1.7,color:Color(0xFF76520F),fontSize:12))),
    ]));
}
