import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_academic_advisor/services/advisor_api.dart';
import 'package:smart_academic_advisor/services/ai_settings_store.dart';

void main() {
  const settings = AiProviderSettings(
    apiKey: 'user-owned-test-key',
    baseUrl: 'https://api.deepseek.com',
    model: 'deepseek-chat',
  );

  test('sends request directly to configured HTTPS provider', () async {
    var requestSeen = false;
    final client = MockClient((request) async {
      requestSeen = true;
      expect(request.url.host, 'api.deepseek.com');
      expect(request.url.path, '/chat/completions');
      expect(request.headers['authorization'], 'Bearer user-owned-test-key');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['model'], 'deepseek-chat');
      expect(body['stream'], false);
      expect((body['messages'] as List).last['content'], contains('چطور درس بخوانم'));
      return http.Response(
        jsonEncode({
          'choices': [
            {'message': {'content': 'پاسخ آزمایشی'}}
          ]
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = AdvisorApi(client: client);
    addTearDown(api.dispose);

    final answer = await api.requestAnswer(
      settings: settings,
      stage: 'متوسطه اول',
      goal: 'برنامه‌ریزی درسی',
      question: 'چطور درس بخوانم؟',
    );

    expect(answer, 'پاسخ آزمایشی');
    expect(requestSeen, isTrue);
  });

  test('accepts OpenAI-compatible base URLs that already include v1', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/v1/chat/completions');
      return http.Response(
        '{"choices":[{"message":{"content":"ok"}}]}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = AdvisorApi(client: client);
    addTearDown(api.dispose);

    final answer = await api.requestAnswer(
      settings: const AiProviderSettings(
        apiKey: 'test',
        baseUrl: 'https://provider.example/v1/',
        model: 'model-x',
      ),
      stage: 'دانشجو',
      goal: 'دانشگاه و شغل',
      question: 'سلام',
    );
    expect(answer, 'ok');
  });

  test('rejects non-HTTPS provider URLs before making a request', () async {
    var sent = false;
    final client = MockClient((_) async {
      sent = true;
      return http.Response('{}', 200);
    });
    final api = AdvisorApi(client: client);
    addTearDown(api.dispose);

    expect(
      () => api.requestAnswer(
        settings: const AiProviderSettings(
          apiKey: 'test',
          baseUrl: 'http://insecure.example',
          model: 'model-x',
        ),
        stage: 'دانشجو',
        goal: 'برنامه‌ریزی درسی',
        question: 'سلام',
      ),
      throwsA(isA<AdvisorException>()),
    );
    await Future<void>.delayed(Duration.zero);
    expect(sent, isFalse);
  });

  test('maps provider authentication and rate-limit errors', () async {
    final unauthorizedClient = MockClient((_) async => http.Response(
          '{"error":{"message":"Invalid API key"}}',
          401,
          headers: {'content-type': 'application/json'},
        ));
    final unauthorizedApi = AdvisorApi(client: unauthorizedClient);
    addTearDown(unauthorizedApi.dispose);
    await expectLater(
      unauthorizedApi.requestAnswer(
        settings: settings,
        stage: 'دانشجو',
        goal: 'برنامه‌ریزی درسی',
        question: 'سلام',
      ),
      throwsA(
        isA<AdvisorException>().having(
          (error) => error.kind,
          'kind',
          AdvisorErrorKind.unauthorized,
        ),
      ),
    );

    final limitedClient = MockClient((_) async => http.Response(
          '{"error":"slow down"}',
          429,
          headers: {'content-type': 'application/json', 'retry-after': '15'},
        ));
    final limitedApi = AdvisorApi(client: limitedClient);
    addTearDown(limitedApi.dispose);
    await expectLater(
      limitedApi.requestAnswer(
        settings: settings,
        stage: 'دانشجو',
        goal: 'برنامه‌ریزی درسی',
        question: 'سلام',
      ),
      throwsA(
        isA<AdvisorException>()
            .having((error) => error.kind, 'kind', AdvisorErrorKind.rateLimited)
            .having((error) => error.retryAfter, 'retryAfter', const Duration(seconds: 15)),
      ),
    );
  });

  test('rejects blank and excessively long questions', () async {
    final api = AdvisorApi(
      client: MockClient((_) async => http.Response('{}', 200)),
    );
    addTearDown(api.dispose);
    for (final question in ['', 'x' * 6001]) {
      await expectLater(
        api.requestAnswer(
          settings: settings,
          stage: 'دانشجو',
          goal: 'برنامه‌ریزی درسی',
          question: question,
        ),
        throwsA(isA<AdvisorException>()),
      );
    }
  });
}
