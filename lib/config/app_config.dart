/// Compile-time configuration for optional AI connectivity.
class AppConfig {
  static const advisorApiBaseUrl =
      String.fromEnvironment('ADVISOR_API_BASE_URL');
  static const aiApiKey = String.fromEnvironment('AI_API_KEY');
  static const aiBaseUrl = String.fromEnvironment(
    'AI_BASE_URL',
    defaultValue: 'https://api.deepseek.com',
  );
  static const aiModel = String.fromEnvironment(
    'AI_MODEL',
    defaultValue: 'deepseek-chat',
  );

  static bool get hasDirectAiKey => aiApiKey.trim().isNotEmpty;
  static bool get hasAdvisorBackend => advisorApiBaseUrl.trim().isNotEmpty;
  static bool get hasAnyAiChannel => hasDirectAiKey || hasAdvisorBackend;
}

/// Shared UI constants.
class AppColors {
  static const seed = 0xFF287D72;
  static const scaffold = 0xFFF5F8F7;
  static const softGreen = 0xFFE3F2ED;
  static const softGreenAlt = 0xFFEAF5F1;
  static const border = 0xFFE2EAE6;
  static const accentChip = 0xFFDCEFEA;
  static const warningBg = 0xFFFFF3D8;
  static const warningIcon = 0xFF93620B;
  static const warningText = 0xFF76520F;
}

class AcademicStages {
  static const all = [
    'ابتدایی',
    'متوسطه اول',
    'متوسطه دوم',
    'کنکوری',
    'دانشجو',
    'فارغ‌التحصیل',
  ];
  static const defaultStage = 'متوسطه اول';
  static const defaultGoal = 'برنامه‌ریزی درسی';
}
