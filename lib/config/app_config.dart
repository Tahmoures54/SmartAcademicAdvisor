import 'dart:ui' show Color;

/// Compile-time configuration for optional AI connectivity.
///
/// All values come from `--dart-define=KEY=value` at build time. Never commit
/// a real key. For public releases prefer `ADVISOR_API_BASE_URL` (proxy)
/// and never embeds provider credentials in the application.
abstract final class AppConfig {
  // ── Raw compile-time values ─────────────────────────────────────────
  static const String _rawAdvisorApiBaseUrl =
      String.fromEnvironment('ADVISOR_API_BASE_URL');
  // ── Safety bounds ───────────────────────────────────────────────────
  static const int _minTimeoutSeconds = 1;
  static const int _maxTimeoutSeconds = 300;
  static const int _maxRetriesCap = 5;

  // ── Public, normalized values ───────────────────────────────────────
  /// Advisor proxy base URL. Trailing slashes stripped. Empty when the app
  /// was built without `ADVISOR_API_BASE_URL`.
  static final String advisorApiBaseUrl =
      _stripTrailingSlashes(_rawAdvisorApiBaseUrl);

  /// Upstream timeout in seconds, clamped to [1, 300].
  static final int aiTimeoutSeconds =
      _clampInt(_rawAiTimeoutSeconds, _minTimeoutSeconds, _maxTimeoutSeconds);

  /// Retry count on 5xx/timeout, clamped to [0, 5].
  static final int aiMaxRetries =
      _clampInt(_rawAiMaxRetries, 0, _maxRetriesCap);

  /// Max completion tokens, clamped to [1, 8000].
  /// Ready-to-use timeout for `http` calls.
  static final Duration aiTimeout = Duration(seconds: aiTimeoutSeconds);

  // ── Feature flags ───────────────────────────────────────────────────
  static bool get hasAdvisorBackend => advisorApiBaseUrl.isNotEmpty;

  /// True only when the configured backend URL uses HTTP or HTTPS.
  static bool get hasValidAdvisorBackend =>
      hasAdvisorBackend && _isHttpUrl(advisorApiBaseUrl);

  /// AI is available only through the server-side proxy; otherwise use offline advice.
  static bool get hasAnyAiChannel => hasValidAdvisorBackend;

  static String describe() => 'AppConfig('
      'advisor=${hasValidAdvisorBackend ? advisorApiBaseUrl : "<none>"}, '
      'timeout=${aiTimeoutSeconds}s, '
      'retries=$aiMaxRetries)';

  // ── Helpers ─────────────────────────────────────────────────────────
  static String _stripTrailingSlashes(String value) {
    var v = value.trim();
    while (v.endsWith('/')) {
      v = v.substring(0, v.length - 1);
    }
    return v;
  }

  static bool _isHttpUrl(String value) =>
      value.startsWith('http://') || value.startsWith('https://');

  static int _clampInt(int value, int min, int max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
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
