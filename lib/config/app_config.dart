import 'dart:ui' show Color;

/// Compile-time configuration for optional AI connectivity.
///
/// All values come from `--dart-define=KEY=value` at build time. Never commit
/// a real key. For public releases prefer `ADVISOR_API_BASE_URL` (proxy)
/// over `AI_API_KEY` (direct key embedded in the APK is extractable).
abstract final class AppConfig {
  // ── Raw compile-time values ─────────────────────────────────────────
  static const String _rawAdvisorApiBaseUrl =
      String.fromEnvironment('ADVISOR_API_BASE_URL');
  static const String _rawAiApiKey = String.fromEnvironment('AI_API_KEY');
  static const String _rawAiBaseUrl = String.fromEnvironment(
    'AI_BASE_URL',
    defaultValue: 'https://api.deepseek.com',
  );
  static const String _rawAiModel = String.fromEnvironment(
    'AI_MODEL',
    defaultValue: 'deepseek-chat',
  );
  static const int _rawAiTimeoutSeconds =
      int.fromEnvironment('AI_TIMEOUT_SECONDS', defaultValue: 30);
  static const int _rawAiMaxRetries =
      int.fromEnvironment('AI_MAX_RETRIES', defaultValue: 0);
  static const int _rawAiMaxTokens =
      int.fromEnvironment('AI_MAX_TOKENS', defaultValue: 700);

  // ── Safety bounds ───────────────────────────────────────────────────
  static const int _minTimeoutSeconds = 1;
  static const int _maxTimeoutSeconds = 300;
  static const int _maxRetriesCap = 5;
  static const int _minTokens = 1;
  static const int _maxTokens = 8000;

  // ── Public, normalized values ───────────────────────────────────────
  /// Advisor proxy base URL. Trailing slashes stripped. Empty when the app
  /// was built without `ADVISOR_API_BASE_URL`.
  static final String advisorApiBaseUrl =
      _stripTrailingSlashes(_rawAdvisorApiBaseUrl);

  /// Trimmed direct API key. Empty when built without `AI_API_KEY`.
  static final String aiApiKey = _rawAiApiKey.trim();

  /// Provider base URL, normalized, with a safe fallback.
  static final String aiBaseUrl =
      _normalizeOrDefault(_rawAiBaseUrl, 'https://api.deepseek.com');

  /// Model name, trimmed, with a safe fallback.
  static final String aiModel =
      _normalizeOrDefault(_rawAiModel, 'deepseek-chat');

  /// Upstream timeout in seconds, clamped to [1, 300].
  static final int aiTimeoutSeconds =
      _clampInt(_rawAiTimeoutSeconds, _minTimeoutSeconds, _maxTimeoutSeconds);

  /// Retry count on 5xx/timeout, clamped to [0, 5].
  static final int aiMaxRetries =
      _clampInt(_rawAiMaxRetries, 0, _maxRetriesCap);

  /// Max completion tokens, clamped to [1, 8000].
  static final int aiMaxTokens =
      _clampInt(_rawAiMaxTokens, _minTokens, _maxTokens);

  /// Ready-to-use timeout for `http` calls.
  static final Duration aiTimeout = Duration(seconds: aiTimeoutSeconds);

  // ── Feature flags ───────────────────────────────────────────────────
  static bool get hasDirectAiKey => aiApiKey.isNotEmpty;

  static bool get hasAdvisorBackend => advisorApiBaseUrl.isNotEmpty;

  /// True only when the advisor URL also starts with http(s).
  static bool get hasValidAdvisorBackend =>
      hasAdvisorBackend && _isHttpUrl(advisorApiBaseUrl);

  /// True only when key + URL + model are all present.
  static bool get hasDirectAiConfig =>
      hasDirectAiKey && aiBaseUrl.isNotEmpty && aiModel.isNotEmpty;

  /// Preferred path: valid proxy first, then direct key, then offline advice.
  static bool get hasAnyAiChannel =>
      hasValidAdvisorBackend || hasDirectAiConfig;

  /// Diagnostics-safe summary for startup logs. Never prints the key.
  static String describe() => 'AppConfig('
      'advisor=${hasValidAdvisorBackend ? advisorApiBaseUrl : "<none>"}, '
      'directKey=${hasDirectAiKey ? "<set>" : "<unset>"}, '
      'model=$aiModel, '
      'timeout=${aiTimeoutSeconds}s, '
      'retries=$aiMaxRetries, '
      'maxTokens=$aiMaxTokens)';

  // ── Helpers ─────────────────────────────────────────────────────────
  static String _stripTrailingSlashes(String value) {
    var v = value.trim();
    while (v.endsWith('/')) {
      v = v.substring(0, v.length - 1);
    }
    return v;
  }

  static String _normalizeOrDefault(String raw, String fallback) {
    final v = _stripTrailingSlashes(raw);
    return v.isEmpty ? fallback : v;
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
