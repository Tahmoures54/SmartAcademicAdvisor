import 'package:flutter_test/flutter_test.dart';
import 'package:smart_academic_advisor/services/ai_settings_store.dart';

void main() {
  test('accepts a complete HTTPS provider configuration', () {
    const settings = AiProviderSettings(
      apiKey: 'user-key',
      baseUrl: 'https://api.deepseek.com/v1/',
      model: 'deepseek-chat',
    );
    expect(settings.isConfigured, isTrue);
  });

  test('does not accept an empty key', () {
    const settings = AiProviderSettings(
      apiKey: ' ',
      baseUrl: 'https://api.deepseek.com',
      model: 'deepseek-chat',
    );
    expect(settings.isConfigured, isFalse);
  });

  test('rejects insecure or credential-bearing provider URLs', () {
    for (final url in [
      'http://api.example.com',
      'https://user:password@api.example.com',
      'https://api.example.com?token=secret',
      'https://api.example.com#fragment',
      'not a url',
    ]) {
      final settings = AiProviderSettings(
        apiKey: 'user-key',
        baseUrl: url,
        model: 'model',
      );
      expect(settings.isConfigured, isFalse, reason: url);
    }
  });

  test('rejects an empty model name', () {
    const settings = AiProviderSettings(
      apiKey: 'user-key',
      baseUrl: 'https://api.deepseek.com',
      model: ' ',
    );
    expect(settings.isConfigured, isFalse);
  });
}
