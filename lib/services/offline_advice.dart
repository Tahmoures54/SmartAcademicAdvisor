import '../config/app_config.dart';

/// Rule-based offline guidance used when no AI channel is configured.
///
/// Input tolerance:
///   • Leading/trailing whitespace is trimmed.
///   • Bidi control characters (RLM, LRM, ALM, LRE/RLE/PDF/LRO/RLO,
///     LRI/RLI/FSI/PDI, ZWNBSP) are stripped.
///   • ZWNJ (`\u200C`), NBSP (`\u00A0`), and regular spaces are treated as
///     equivalent inside stage and goal names, so "فارغ‌التحصیل",
///     "فارغ التحصیل", and "فارغالتحصیل" all map to the same message.
///   • Questions are length-limited to 1500 characters (matches the
///     backend's `MAX_QUESTION_LENGTH`).
///
/// Every value in [AcademicStages.all] and [AcademicGoals.all] has an
/// explicit message. Unknown inputs fall back to a safe generic message.
/// Use [hasStageSpecificAdvice] / [hasGoalSpecificAdvice] in tests to
/// guard against future drift.
abstract final class OfflineAdvice {
  // ── Stage messages ─────────────────────────────────────────────────
  static const String _stagePrimary =
      'درس را به بخش‌های کوتاه ۱۰ تا ۱۵ دقیقه‌ای تقسیم کن، بعد از هر بخش کمی '
      'استراحت داشته باش و اگر مطلبی سخت بود از معلم یا خانواده کمک بگیر.';

  static const String _stageMiddle1 =
      'برای هر درس هدف کوچک و مشخص تعیین کن، تکالیف را به شب آخر موکول نکن و '
      'بعد از مطالعه با چند سؤال کوتاه مطمئن شو مطلب را فهمیده‌ای.';

  static const String _stageMiddle2 =
      'درس‌های مدرسه را با مرور منظم ترکیب کن، مباحث دشوار را زودتر مشخص کن و '
      'برای هر هفته زمان جبرانی در نظر بگیر.';

  static const String _stagePreUniversity =
      'برنامه را بر پایهٔ سطح فعلی و زمان باقی‌مانده بچین؛ حل تست، تحلیل '
      'اشتباه‌ها و مرور فاصله‌دار را کنار هم نگه دار و خواب را قربانی مطالعه نکن.';

  static const String _stageUniversity =
      'موعد تحویل پروژه‌ها و امتحان‌ها را از قبل ثبت کن، کارهای بزرگ را به '
      'گام‌های کوچک بشکن و برای مطالعهٔ مستقل و استراحت تعادل نگه دار.';

  static const String _stageGraduate =
      'هدف شغلی یا تحصیلی بعدی را مشخص کن، مهارت‌های موردنیاز را فهرست کن و '
      'پیش از تصمیم بزرگ، اطلاعات را از چند منبع معتبر بررسی کن.';

  /// Used only when the stage value does not match any known stage.
  static const String _stageGeneric =
      'یک هدف کوچک و روشن برای امروز انتخاب کن، زمان تقریبی برایش مشخص کن و '
      'در پایان روز نتیجه را بررسی کن.';

  // ── Goal messages ──────────────────────────────────────────────────
  static const String _goalPlanning =
      'امروز سه کار مهم را انتخاب کن، زمان تقریبی هرکدام را مشخص کن و در '
      'پایان روز برنامه را بر اساس آنچه واقعاً انجام دادی اصلاح کن.';

  static const String _goalFieldOfStudy =
      'علاقه‌ها، توانایی‌ها، شرایط و محدودیت‌هایت را جداگانه بنویس؛ تصمیم '
      'نهایی را فقط بر پایهٔ نظر دیگران یا یک آزمون نگذار.';

  static const String _goalExams =
      'پس از هر آزمون، اشتباه‌ها را به دانشی، بی‌دقتی و مدیریت زمان دسته‌بندی '
      'کن و برای هر دسته یک اقدام اصلاحی در نظر بگیر.';

  static const String _goalUniversityCareer =
      'مسیرهای تحصیلی و شغلی موردعلاقه را مقایسه کن، مهارت‌های لازم و '
      'فرصت‌های واقعی را بررسی کن و یک قدم کم‌هزینه برای تجربه‌کردن مسیر '
      'انتخاب کن.';

  /// Used only when the goal value does not match any known goal.
  static const String _goalGeneric =
      'دربارهٔ موضوع، اطلاعات کافی از چند منبع معتبر جمع کن و یک اقدام کوچک '
      'و قابل سنجش برای این هفته تعیین کن.';

  // ── Shared footer ──────────────────────────────────────────────────
  static const String _nextStepHint =
      'یک اقدام کوچک و قابل سنجش برای امروز انتخاب کنید و نتیجه را بعداً '
      'ارزیابی کنید.';

  static const String _disclaimer =
      'این راهنمای قاعده‌محور و عمومی است؛ برای پاسخ اختصاصی مربی هوش مصنوعی، '
      'کلید API یا آدرس سرویس باید در ساخت برنامه تنظیم شده باشد.';

  // ── Lookup tables (kanonized keys) ─────────────────────────────────
  static final Map<String, String> _stageMap = <String, String>{
    _kanon('ابتدایی'): _stagePrimary,
    _kanon('متوسطه اول'): _stageMiddle1,
    _kanon('متوسطه دوم'): _stageMiddle2,
    _kanon('کنکوری'): _stagePreUniversity,
    _kanon('دانشجو'): _stageUniversity,
    _kanon('فارغ‌التحصیل'): _stageGraduate,
  };

  static final Map<String, String> _goalMap = <String, String>{
    _kanon('برنامه‌ریزی درسی'): _goalPlanning,
    _kanon('انتخاب رشته'): _goalFieldOfStudy,
    _kanon('آزمون و کنکور'): _goalExams,
    _kanon('دانشگاه و شغل'): _goalUniversityCareer,
  };

  // ── Public API ─────────────────────────────────────────────────────
  /// Advice tailored to [stage]; falls back to a generic message for
  /// unknown values. Input is normalized (see class docs).
  static String forStage(String stage) {
    return _stageMap[_kanon(_sanitize(stage))] ?? _stageGeneric;
  }

  /// Advice tailored to [goal]; falls back to a generic message for
  /// unknown values. Input is normalized (see class docs).
  static String forGoal(String goal) {
    return _goalMap[_kanon(_sanitize(goal))] ?? _goalGeneric;
  }

  /// True when [stage] maps to a specific, non-generic message.
  static bool hasStageSpecificAdvice(String stage) =>
      _stageMap.containsKey(_kanon(_sanitize(stage)));

  /// True when [goal] maps to a specific, non-generic message.
  static bool hasGoalSpecificAdvice(String goal) =>
      _goalMap.containsKey(_kanon(_sanitize(goal)));

  /// Structured answer; useful when the UI wants to render the stage and
  /// goal sections independently (e.g. as separate cards).
  static OfflineAnswer answerFor({
    required String stage,
    required String goal,
    required String question,
  }) {
    final cleanStage =
        _ensureDisplayable(_sanitize(stage), AcademicStages.defaultStage);
    final cleanGoal =
        _ensureDisplayable(_sanitize(goal), AcademicGoals.defaultGoal);
    final cleanQuestion = _sanitize(question, maxLength: 1500);
    return OfflineAnswer(
      stage: cleanStage,
      goal: cleanGoal,
      question: cleanQuestion,
      stageAdvice: forStage(cleanStage),
      goalAdvice: forGoal(cleanGoal),
      stageWasExplicit: hasStageSpecificAdvice(cleanStage),
      goalWasExplicit: hasGoalSpecificAdvice(cleanGoal),
    );
  }

  /// Plain-text fallback used when no AI channel is available.
  ///
  /// Backward compatible with the previous layout; input is sanitized and
  /// length-limited, so an empty stage/goal shows the default instead of a
  /// blank line.
  static String buildFallback({
    required String stage,
    required String goal,
    required String question,
  }) {
    return answerFor(stage: stage, goal: goal, question: question)
        .toPlainText();
  }

  // ── Internals ──────────────────────────────────────────────────────
  /// Trims, strips bidi/format controls, collapses whitespace runs (incl.
  /// NBSP), and truncates to [maxLength] characters with an ellipsis.
  static String _sanitize(String input, {int maxLength = 500}) {
    var v = input.trim();
    // Bidi and format controls that can corrupt display order.
    v = v.replaceAll(
      RegExp(r'[\u061C\u200E\u200F\u202A-\u202E\u2066-\u2069\uFEFF]'),
      '',
    );
    // Collapse runs of whitespace (including NBSP) to a single space.
    v = v.replaceAll(RegExp(r'[\s\u00A0]+'), ' ');
    v = v.trim();
    if (v.length > maxLength) {
      v = '${v.substring(0, maxLength - 1)}…';
    }
    return v;
  }

  /// Kanonized form used as the lookup key. Removes ZWNJ, NBSP, and all
  /// whitespace so "فارغ‌التحصیل" / "فارغ التحصیل" / "فارغالتحصیل" all
  /// collapse to the same key.
  static String _kanon(String input) {
    return input
        .replaceAll('\u200C', '') // ZWNJ
        .replaceAll('\u00A0', '') // NBSP
        .replaceAll(RegExp(r'\s+'), '')
        .trim();
  }

  static String _ensureDisplayable(String value, String fallback) =>
      value.isEmpty ? fallback : value;
}

/// Structured offline answer. Renders stage and goal sections independently
/// so callers can format, localize, or theme them without re-parsing text.
final class OfflineAnswer {
  const OfflineAnswer({
    required this.stage,
    required this.goal,
    required this.question,
    required this.stageAdvice,
    required this.goalAdvice,
    required this.stageWasExplicit,
    required this.goalWasExplicit,
  });

  final String stage;
  final String goal;
  final String question;
  final String stageAdvice;
  final String goalAdvice;

  /// True when [stage] matched a specific entry in [AcademicStages.all]
  /// rather than the generic fallback.
  final bool stageWasExplicit;

  /// True when [goal] matched a specific entry in [AcademicGoals.all]
  /// rather than the generic fallback.
  final bool goalWasExplicit;

  /// Plain-text form. Preserves the historical [OfflineAdvice.buildFallback]
  /// layout so any existing substring-based tests keep passing.
  String toPlainText() {
    return 'راهنمای آغازین متناسب با اطلاعات انتخاب‌شده\n\n'
        'مقطع: $stage\nموضوع: $goal\n\n'
        'پیشنهاد برای مقطع شما: $stageAdvice\n\n'
        'پیشنهاد دربارهٔ موضوع انتخابی: $goalAdvice\n\n'
        'سؤال شما: «$question»\n'
        '${OfflineAdvice._nextStepHint}\n\n'
        '${OfflineAdvice._disclaimer}';
  }

  @override
  String toString() => 'OfflineAnswer('
      'stage: "$stage" (${stageWasExplicit ? "explicit" : "generic"}), '
      'goal: "$goal" (${goalWasExplicit ? "explicit" : "generic"}), '
      'question: ${question.length} chars)';
}
