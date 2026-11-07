import 'package:flutter/material.dart';

import '../../config/app_config.dart';

class StudyAssessmentPage extends StatefulWidget {
  const StudyAssessmentPage({super.key});

  @override
  State<StudyAssessmentPage> createState() => _StudyAssessmentPageState();
}

/// One question with its answer options, ordered from weakest (index 0) to
/// strongest (last index). Keeping text + options together prevents the two
/// parallel lists from drifting out of sync.
abstract final class _AssessmentQuestion {
  const _AssessmentQuestion({required this.text, required this.options});

  final String text;
  final List<String> options;

  /// Highest score a single question can contribute.
  int get maxScore => options.length - 1;
}

class _StudyAssessmentPageState extends State<StudyAssessmentPage> {
  static const List<_AssessmentQuestion> _questions = <_AssessmentQuestion>[
    _AssessmentQuestion(
      text:
          'وقتی درس را می‌خوانی، چقدر می‌توانی بدون نگاه‌کردن به کتاب آن را توضیح بدهی؟',
      options: <String>['به‌سختی', 'تا حدی', 'معمولاً خوب'],
    ),
    _AssessmentQuestion(
      text: 'چقدر زود مطالبی را که قبلاً خوانده‌ای فراموش می‌کنی؟',
      options: <String>['خیلی زود', 'گاهی', 'با مرور معمولاً یادم می‌ماند'],
    ),
    _AssessmentQuestion(
      text:
          'وقتی پاسخ یک سؤال را اشتباه می‌دهی، چقدر علت اشتباه را بررسی می‌کنی؟',
      options: <String>['به‌ندرت', 'گاهی', 'تقریباً همیشه'],
    ),
    _AssessmentQuestion(
      text: 'برنامهٔ مطالعه‌ات چقدر با زمان و انرژی واقعی تو هماهنگ است؟',
      options: <String>['اغلب سنگین است', 'تا حدی هماهنگ است', 'واقع‌بینانه و قابل اجراست'],
    ),
  ];

  late List<int?> _answers = List<int?>.filled(_questions.length, null);
  bool _showResult = false;

  final GlobalKey _resultKey = GlobalKey();

  @override
  void dispose() {
    // No ScrollController is retained; ensureVisible is used with a GlobalKey.
    super.dispose();
  }

  // ── Derived state ──────────────────────────────────────────────────
  int get _answered => _answers.whereType<int>().length;

  bool get _complete => _answered == _questions.length;

  /// Sum of selected option indexes. All questions are ordered weakest →
  /// strongest, so a simple sum is correct — no per-question inversion.
  int get _score =>
      _answers.whereType<int>().fold<int>(0, (sum, answer) => sum + answer);

  int get _maxScore =>
      _questions.fold<int>(0, (sum, q) => sum + q.maxScore);

  String get _advice {
    final score = _score;
    if (score <= 3) {
      return 'از زمان کوتاه شروع کن، هر بار یک هدف کوچک تعیین کن و پس از '
          'مطالعه، مطلب را با زبان خودت توضیح بده.';
    }
    if (score <= 6) {
      return 'روش مطالعه‌ات چند نقطهٔ قوت دارد. مرور فاصله‌دار و بررسی '
          'اشتباه‌ها را منظم‌تر کن و برنامه را با انرژی واقعی خود هماهنگ نگه دار.';
    }
    return 'پایهٔ مناسبی برای مطالعهٔ مؤثر داری. برای تثبیت نتیجه، از خودآزمایی، '
        'مرور دوره‌ای و تحلیل اشتباه‌ها استفاده کن.';
  }

  // ── Actions ────────────────────────────────────────────────────────
  void _select(int index, int? value) {
    if (_answers[index] == value) return;
    setState(() {
      _answers[index] = value;
      _showResult = false;
    });
  }

  void _reset() {
    setState(() {
      _answers = List<int?>.filled(_questions.length, null);
      _showResult = false;
    });
  }

  void _showSummary() {
    setState(() => _showResult = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _resultKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignment: 0.2,
        );
      }
    });
  }

  // ── UI ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('ارزیابی روش مطالعه')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: <Widget>[
          Text(
            'به چهار پرسش زیر صادقانه پاسخ بده. این ارزیابی کوتاه، آزمون علمی '
            'یا تشخیص تخصصی نیست؛ فقط برای شروع گفت‌وگو دربارهٔ عادت‌های مطالعه است.',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.8),
          ),
          const SizedBox(height: 12),
          Semantics(
            label: 'پیشرفت پاسخ‌دهی',
            value: '$_answered از ${_questions.length}',
            child: ExcludeSemantics(
              child: LinearProgressIndicator(
                value: _answered / _questions.length,
                minHeight: 6,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text('$_answered از ${_questions.length} پرسش پاسخ داده شده'),
          const SizedBox(height: 12),
          for (int i = 0; i < _questions.length; i++) _buildQuestionCard(i),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _answered == 0 ? null : _reset,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('شروع دوباره'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _complete ? _showSummary : null,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('نمایش جمع‌بندی'),
                ),
              ),
            ],
          ),
          if (_complete && _showResult) ...<Widget>[
            const SizedBox(height: 14),
            _buildResultCard(theme),
          ],
        ],
      ),
    );
  }

  Widget _buildQuestionCard(int index) {
    final q = _questions[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${index + 1}. ${q.text}',
              style: const TextStyle(fontWeight: FontWeight.w800, height: 1.6),
            ),
            const SizedBox(height: 6),
            // RadioGroup<int> owns selection for this question; individual
            // RadioListTile widgets must not set groupValue/onChanged.
            RadioGroup<int>(
              groupValue: _answers[index],
              onChanged: (int? value) => _select(index, value),
              child: Column(
                children: <Widget>[
                  for (int option = 0; option < q.options.length; option++)
                    RadioListTile<int>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: option,
                      title: Text(q.options[option]),
                      semanticLabel: q.options[option],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(ThemeData theme) {
    return Container(
      key: _resultKey,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.softGreenColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'امتیاز راهنمایی: $_score از $_maxScore',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(_advice, style: const TextStyle(height: 1.8)),
          const SizedBox(height: 8),
          const Text(
            'این امتیاز نمرهٔ هوش یا توانایی تحصیلی نیست و نباید به‌تنهایی مبنای '
            'انتخاب رشته یا تصمیم مهم قرار بگیرد.',
            style: TextStyle(fontSize: 12, height: 1.7, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.refresh),
            label: const Text('انجام دوبارهٔ ارزیابی'),
          ),
        ],
      ),
    );
  }
}
