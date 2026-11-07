import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// User-owned AI provider settings. Credentials never ship inside the APK.
class AiProviderSettings {
  const AiProviderSettings({
    required this.apiKey,
    required this.baseUrl,
    required this.model,
  });

  final String apiKey;
  final String baseUrl;
  final String model;

  bool get isConfigured =>
      apiKey.trim().isNotEmpty && _isSecureProviderUrl(baseUrl) && model.trim().isNotEmpty;

  static bool _isSecureProviderUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
  }
}

/// Stores the API key using Android Keystore-backed encrypted preferences.
class AiSettingsStore {
  AiSettingsStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _keyApiKey = 'ai_provider_api_key';
  static const _keyBaseUrl = 'ai_provider_base_url';
  static const _keyModel = 'ai_provider_model';

  final FlutterSecureStorage _storage;

  Future<AiProviderSettings> load() async {
    final values = await Future.wait([
      _storage.read(key: _keyApiKey),
      _storage.read(key: _keyBaseUrl),
      _storage.read(key: _keyModel),
    ]);
    return AiProviderSettings(
      apiKey: values[0] ?? '',
      baseUrl: values[1] ?? 'https://api.deepseek.com',
      model: values[2] ?? 'deepseek-chat',
    );
  }

  Future<void> save(AiProviderSettings settings) async {
    if (settings.apiKey.trim().isEmpty) {
      throw ArgumentError('کلید API نمی‌تواند خالی باشد.');
    }
    if (!AiProviderSettings._isSecureProviderUrl(settings.baseUrl)) {
      throw ArgumentError('نشانی سرویس باید HTTPS معتبر باشد.');
    }
    if (settings.model.trim().isEmpty || settings.model.length > 100) {
      throw ArgumentError('نام مدل معتبر نیست.');
    }
    await _storage.write(key: _keyApiKey, value: settings.apiKey.trim());
    await _storage.write(key: _keyBaseUrl, value: settings.baseUrl.trim());
    await _storage.write(key: _keyModel, value: settings.model.trim());
  }

  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _keyApiKey),
      _storage.delete(key: _keyBaseUrl),
      _storage.delete(key: _keyModel),
    ]);
  }
}
