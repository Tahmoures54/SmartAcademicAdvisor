import 'dart:ui' show Color;

/// Static presentation constants. AI credentials are user-managed and stored
/// locally by [AiSettingsStore]; no provider key is compiled into the APK.
abstract final class AppConfig {
  static const Duration aiTimeout = Duration(seconds: 45);
  static const int aiMaxRetries = 1;
}

/// Shared UI constants.
abstract final class AppColors {
  // Backward-compatible int values (existing call sites keep working).
  static const int seed = 0xFF287D72;
  static const int scaffold = 0xFFF5F8F7;
  static const int softGreen = 0xFFE3F2ED;
  static const int softGreenAlt = 0xFFEAF5F1;
  static const int border = 0xFFE2EAE6;
  static const int accentChip = 0xFFDCEFEA;
  static const int warningBg = 0xFFFFF3D8;
  static const int warningIcon = 0xFF93620B;
  static const int warningText = 0xFF76520F;

  // Typed Color variants — use these directly in widgets.
  static const Color seedColor = Color(seed);
  static const Color scaffoldColor = Color(scaffold);
  static const Color softGreenColor = Color(softGreen);
  static const Color softGreenAltColor = Color(softGreenAlt);
  static const Color borderColor = Color(border);
  static const Color accentChipColor = Color(accentChip);
  static const Color warningBackgroundColor = Color(warningBg);
  static const Color warningIconColor = Color(warningIcon);
  static const Color warningTextColor = Color(warningText);
}

/// Study stages offered by the advisor.
/// Mirrors the backend's `_ALLOWED_STAGES`.
abstract final class AcademicStages {
  static const List<String> all = <String>[
    'ابتدایی',
    'متوسطه اول',
    'متوسطه دوم',
    'کنکوری',
    'دانشجو',
    'فارغ‌التحصیل',
  ];
  static const String defaultStage = 'متوسطه اول';

  /// Kept for backward compatibility. Use [AcademicGoals.defaultGoal].
  @Deprecated('Use AcademicGoals.defaultGoal')
  static const String defaultGoal = AcademicGoals.defaultGoal;

  static bool contains(String stage) => all.contains(stage);
}

/// Study goals offered by the advisor.
/// Mirrors the backend's `_ALLOWED_GOALS`.
abstract final class AcademicGoals {
  static const List<String> all = <String>[
    'برنامه‌ریزی درسی',
    'انتخاب رشته',
    'آزمون و کنکور',
    'دانشگاه و شغل',
  ];
  static const String defaultGoal = 'برنامه‌ریزی درسی';

  static bool contains(String goal) => all.contains(goal);
}
