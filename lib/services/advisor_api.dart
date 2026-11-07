import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'ai_settings_store.dart';

enum AdvisorErrorKind {
  badRequest,
  misconfigured,
  unauthorized,
  rateLimited,
  serverError,
  network,
  invalidResponse,
}

class AdvisorException extends FormatException {
  const AdvisorException(
    this.message, {
    this.kind = AdvisorErrorKind.serverError,
    this.statusCode,
    this.retryAfter,
  });

  @override
  final String message;
  final AdvisorErrorKind kind;
  final int? statusCode;
  final Duration? retryAfter;

  @override
  String toString() => 'AdvisorException(${kind.name})'
      '${statusCode == null ? '' : ' | status=$statusCode'} | $message';
}

/// Sends requests directly from the phone to the user's selected AI provider.
class AdvisorApi {
  AdvisorApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @visibleForTesting
  Duration Function(int attempt) backoffFor = (attempt) =>
      Duration(milliseconds: 400 * (attempt + 1));

  Future<String> requestAnswer({
    required AiProviderSettings settings,
    required String stage,
    required String goal,
    required String question,
  }) async {
    final q = question.trim();
    if (q.isEmpty || q.length > 6000) {
      throw const AdvisorException(
        'Question must contain 1 to 6000 characters.',
        kind: AdvisorErrorKind.badRequest,
      );
    }
    if (!settings.isConfigured) {
      throw const AdvisorException(
        'AI provider settings are incomplete.',
        kind: AdvisorErrorKind.misconfigured,
      );
    }

    final uri = _completionUri(settings.baseUrl);
    final body = jsonEncode({
      'model': settings.model.trim(),
      'messages': [
        {
          'role': 'system',
          'content':
              'تو مربی آموزشی فارسی‌زبان، دقیق و صبور هستی. پاسخ را متناسب با مقطع تحصیلی تنظیم کن؛ مطالب را مرحله‌به‌مرحله توضیح بده، مثال ساده بزن و در پایان تمرین کوتاهی پیشنهاد کن. برای کودکان ساده و امن توضیح بده. درباره پذیرش، آینده شغلی یا نتایج آزمون تضمین نده. اگر اطلاعات کافی نیست سؤال روشن‌کننده بپرس.',
        },
        {
          'role': 'user',
          'content': 'مقطع: $stage\nموضوع: $goal\nدرخواست: $q',
        },
      ],
      'temperature': 0.4,
      'max_tokens': 700,
      'stream': false,
    });

    final response = await _sendWithRetry(() => _client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer ${settings.apiKey.trim()}',
          },
          body: body,
        )
        .timeout(AppConfig.aiTimeout));

    return _parseResponse(response);
  }

  Uri _completionUri(String baseUrl) {
    final uri = Uri.parse(baseUrl.trim());
    if (uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      throw const AdvisorException(
        'Provider URL must be a valid HTTPS address.',
        kind: AdvisorErrorKind.misconfigured,
      );
    }
    var path = uri.path.replaceFirst(RegExp(r'/+$'), '');
    if (!path.endsWith('/chat/completions')) {
      path = '$path/chat/completions';
    }
    return uri.replace(path: path, query: null, fragment: null);
  }

  Future<http.Response> _sendWithRetry(
    Future<http.Response> Function() send,
  ) async {
    Object? lastError;
    for (var attempt = 0; attempt <= AppConfig.aiMaxRetries; attempt++) {
      try {
        final response = await send();
        if (response.statusCode >= 500 &&
            attempt < AppConfig.aiMaxRetries) {
          await Future<void>.delayed(backoffFor(attempt));
          continue;
        }
        return response;
      } on TimeoutException catch (error) {
        lastError = error;
        if (attempt < AppConfig.aiMaxRetries) {
          await Future<void>.delayed(backoffFor(attempt));
          continue;
        }
        throw const AdvisorException(
          'ارتباط با سرویس بیش از حد طول کشید.',
          kind: AdvisorErrorKind.network,
        );
      } on http.ClientException catch (error) {
        lastError = error;
        if (attempt < AppConfig.aiMaxRetries) {
          await Future<void>.delayed(backoffFor(attempt));
          continue;
        }
        throw AdvisorException(
          'خطای ارتباط اینترنتی: ${error.message}',
          kind: AdvisorErrorKind.network,
        );
      }
    }
    throw AdvisorException(
      'درخواست ناموفق بود: $lastError',
      kind: AdvisorErrorKind.network,
    );
  }

  String _parseResponse(http.Response response) {
    final status = response.statusCode;
    dynamic payload;
    try {
      payload = jsonDecode(response.body);
    } on FormatException {
      throw AdvisorException(
        'پاسخ سرویس JSON معتبر نیست.',
        kind: AdvisorErrorKind.invalidResponse,
        statusCode: status,
      );
    }

    if (status == 200) {
      final choices = payload is Map ? payload['choices'] : null;
      final first = choices is List && choices.isNotEmpty ? choices.first : null;
      final message = first is Map ? first['message'] : null;
      final content = message is Map ? message['content'] : null;
      if (content is String && content.trim().isNotEmpty) {
        return content.trim();
      }
      throw const AdvisorException(
        'پاسخ هوش مصنوعی خالی یا نامعتبر است.',
        kind: AdvisorErrorKind.invalidResponse,
        statusCode: 200,
      );
    }

    final error = payload is Map ? payload['error'] : null;
    final detail = error is Map
        ? error['message']
        : error is String
            ? error
            : null;
    final kind = switch (status) {
      400 || 413 || 422 => AdvisorErrorKind.badRequest,
      401 || 403 => AdvisorErrorKind.unauthorized,
      429 => AdvisorErrorKind.rateLimited,
      >= 500 => AdvisorErrorKind.serverError,
      _ => AdvisorErrorKind.invalidResponse,
    };
    final retrySeconds = int.tryParse(
      response.headers['retry-after'] ?? '',
    );
    throw AdvisorException(
      detail is String && detail.trim().isNotEmpty
          ? detail.trim()
          : 'سرویس هوش مصنوعی خطای HTTP $status برگرداند.',
      kind: kind,
      statusCode: status,
      retryAfter: retrySeconds == null ? null : Duration(seconds: retrySeconds),
    );
  }

  void dispose() => _client.close();
}
