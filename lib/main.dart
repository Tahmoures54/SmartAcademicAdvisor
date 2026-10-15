import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    final score = _answers.asMap().entries.fold<int>(0, (sum, entry) =>
      sum + (entry.key == 1 ? 2 - entry.value! : entry.value!));
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
              ...List.generate(3, (option) => RadioListTile<int>(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: option,
                groupValue: _answers[index],
                title: Text(_options[index][option]),
                onChanged: (value) => setState(() { _answers[index] = value; _showResult = false; }),
              )),
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
  final Set<String> _completedTasks = {};
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
      _notesController.text = prefs.getString('study_notes') ?? '';
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_stage', _stage);
    await prefs.setString('profile_goal', _goal);
    await prefs.setStringList('study_tasks', _studyTasks);
    await prefs.setStringList('completed_tasks',
      _completedTasks.map((index) => index.toString()).toList());
    await prefs.setString('study_notes', _notesController.text);
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
      _notesController.clear();
      _answer = null;
    });
  }

  @override
  void dispose() {
    _questionController.dispose();
    _newTaskController.dispose();
    _notesController.dispose();
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

  void _askAdvisor() {
    final question = _questionController.text.trim();
    setState(() {
      _answer = question.isEmpty
        ? 'لطفاً ابتدا سؤال یا دغدغهٔ تحصیلی‌تان را بنویسید.'
        : 'راهنمای آغازین متناسب با اطلاعات انتخاب‌شده\n\n'
          'مقطع: $_stage\nموضوع: $_goal\n\n'
          'پیشنهاد برای مقطع شما: ${_stageAdvice()}\n\n'
          'پیشنهاد دربارهٔ موضوع انتخابی: ${_goalAdvice()}\n\n'
          'سؤال شما: «$question»\n'
          'یک اقدام کوچک و قابل سنجش برای امروز انتخاب کنید و نتیجه را بعداً ارزیابی کنید.\n\n'
          'این نسخهٔ اولیه هنوز به سرویس هوش مصنوعی متصل نیست؛ این راهنمای قاعده‌محور و عمومی است و جایگزین مشاور مدرسه یا متخصص نیست.';
    });
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
      selectedIndex: ['خانه','برنامه من','یادداشت‌ها','پروفایل'].indexOf(_tab),
      onDestinationSelected:(i)=>setState(()=>_tab=['خانه','برنامه من','یادداشت‌ها','پروفایل'][i]),
      destinations: const [
        NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:'خانه'),
        NavigationDestination(icon:Icon(Icons.event_note_outlined),label:'برنامه من'),
        NavigationDestination(icon:Icon(Icons.bookmark_border),label:'یادداشت‌ها'),
        NavigationDestination(icon:Icon(Icons.person_outline),label:'پروفایل'),
      ],
    ),
  );

  void _addStudyTask() {
    final task = _newTaskController.text.trim();
    if (task.isEmpty) return;
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
      Container(padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2EAE6))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(controller: _newTaskController,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _addStudyTask(),
            decoration: InputDecoration(
              labelText: 'کار یا درس بعدی',
              hintText: 'مثلاً: مرور فصل دوم علوم',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: _addStudyTask,
            icon: const Icon(Icons.add_task_rounded), label: const Text('افزودن به برنامه')),
        ]),
      ),
      const SizedBox(height: 18),
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
            controlAffinity: ListTileControlAffinity.leading,
            secondary: IconButton(
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
                _saveData();
              }
            ),
          ),
        )),
      const SizedBox(height: 12),
      const Text('کارها، وضعیت انجام و یادداشت‌ها روی همین دستگاه ذخیره می‌شوند. برای انتقال به گوشی دیگر، همگام‌سازی ابری در نسخهٔ بعدی لازم است.',
        style: TextStyle(color: Colors.black54, fontSize: 12, height: 1.7)),
    ],
  );

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
    TextField(controller: _notesController, minLines: 8, maxLines: 18,
      onChanged: (_) => _saveData(),
      decoration: InputDecoration(hintText: 'یادداشت تحصیلی شما…', filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)))),
    const SizedBox(height: 12),
    FilledButton.icon(onPressed: _saveData, icon: const Icon(Icons.save_outlined), label: const Text('ذخیرهٔ یادداشت')),
    const SizedBox(height: 8),
    const Text('یادداشت‌ها فقط در حافظهٔ محلی این دستگاه ذخیره می‌شوند و همگام‌سازی ابری ندارند.', style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.7)),
  ]);

  Widget _secondaryPage() {
    if (_tab == 'برنامه من') return _studyPlannerPage();
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
      Expanded(child:Text('این نسخه نمونهٔ اولیه است و هنوز به هوش مصنوعی، حساب کاربری، همگام‌سازی یا پرداخت متصل نشده است. تصمیم‌های مهم آموزشی را با خانواده و مشاور مدرسه نیز بررسی کنید.',style:TextStyle(height:1.7,color:Color(0xFF76520F),fontSize:12))),
    ]));
}
