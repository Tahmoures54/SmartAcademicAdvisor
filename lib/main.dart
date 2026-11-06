import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _advisorApiBaseUrl = String.fromEnvironment('ADVISOR_API_BASE_URL');
const _aiApiKey = String.fromEnvironment('AI_API_KEY');
const _aiBaseUrl = String.fromEnvironment('AI_BASE_URL', defaultValue: 'https://api.deepseek.com');
const _aiModel = String.fromEnvironment('AI_MODEL', defaultValue: 'deepseek-chat');

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

// NOTE: Full UI implementation remains in this file for stability.
// New modular layers live under lib/models, lib/services, lib/config, lib/features/assessment.
// See README architecture section for the migration plan.

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

// PLACEHOLDER: The full _AdvisorHomeScreenState implementation is restored from the previous
// working revision in a follow-up. To avoid a broken main, this temporary stub routes users
// to a message. Prefer checking out the last green CI commit if needed.

class _AdvisorHomeScreenState extends State<AdvisorHomeScreen> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'در حال تکمیل مهاجرت ساختاری. لطفاً چند لحظه صبر کنید یا از آخرین commit پایدار استفاده کنید.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
