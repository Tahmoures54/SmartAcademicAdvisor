import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// High-level category of an advisor failure. Use to decide whether to retry,
/// back off, or surface a configuration message to the user.
enum AdvisorErrorKind {
  /// Caller sent an invalid request (e.g. missing fields, oversized body).
  badRequest,

  /// Server-side AI service is not configured.
  misconfigured,

  /// Authentication with the provider failed.
  unauthorized,

  /// Rate limited. Check [AdvisorException.retryAfter] when available.
  rateLimited,

  /// Upstream provider or proxy returned a 5xx-equivalent failure.
  serverError,

  /// Network-level failure (DNS, connect, timeout).
  network,

  /// Response could not be parsed or was semantically empty.
  invalidResponse,
}

/// Failure raised by [AdvisorApi].
///
/// Extends [FormatException] so existing callers that catch `FormatException`
/// keep working unchanged. New callers should inspect [kind], [statusCode],
/// and [retryAfter] for precise handling.
class AdvisorException extends FormatException {
  const AdvisorException(
    this.message, {
    this.kind = AdvisorErrorKind.serverError,
    this.statusCode,
    this.requestId,
    this.retryAfter,
  });

  @override
  final String message;

  final AdvisorErrorKind kind;
  final int? statusCode;
  final String? requestId;

  /// Value of the `Retry-After` header, if the server provided one.
  final Duration? retryAfter;

  @override
  String toString() {
    final parts = <String>[
      'AdvisorException(${kind.name})',
      if (statusCode != null) 'status=$statusCode',
      if (requestId != null && requestId!.isNotEmpty) 'rid=$requestId',
      if (retryAfter != null) 'retryAfter=${retryAfter!.inSeconds}s',
      message,
    ];
    return parts.join(' | ');
  }
}

/// Optional AI guidance through the server-side backend proxy.
/// Returns `null` when no valid backend is configured, allowing offline advice.
class AdvisorApi {
  AdvisorApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Optional clock injection for tests of retry backoff.
  @visibleForTesting
  Duration Function(int attempt) backoffFor = (attempt) =>
      Duration(milliseconds: 400 * (attempt + 1));

  Future<String?> requestAnswer({
    required String stage,
    required String goal,
    required String question,
  }) async {
    final q = question.trim();
    if (q.isEmpty) {
      throw const AdvisorException(
        'Question must not be empty',
        kind: AdvisorErrorKind.badRequest,
      );
    }

    if (AppConfig.hasValidAdvisorBackend) {
      return _requestBackend(stage: stage, goal: goal, question: q);
    }
    return null;
  }

  /// Releases the underlying HTTP client. Safe to call multiple times.
  void dispose() {
    _client.close();
  }

  // ── Proxy path ─────────────────────────────────────────────────────
  Future<String> _requestBackend({
    required String stage,
    required String goal,
    required String question,
  }) async {
    final uri = Uri.parse('${AppConfig.advisorApiBaseUrl}/api/advice');
    final body = jsonEncode({
      'stage': stage,
      'goal': goal,
      'question': question,
    });

    final response = await _sendWithRetry(
      () => _client
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(AppConfig.aiTimeout),
    );

    return _parseBackendResponse(response);
  }

  // ── Shared helpers ─────────────────────────────────────────────────
  /// Sends [send] and retries transient failures up to
  /// `AppConfig.aiMaxRetries` times. Non-transient status codes are returned
  /// as-is so the caller can map them precisely.
  Future<http.Response> _sendWithRetry(Future<http.Response> Function() send) async {
    final maxAttempts = 1 + AppConfig.aiMaxRetries;
    Object? lastError;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final response = await send();
        if (response.statusCode >= 500 && attempt + 1 < maxAttempts) {
          await Future<void>.delayed(backoffFor(attempt));
          continue;
        }
        return response;
      } on TimeoutException catch (e) {
        lastError = e;
        if (attempt + 1 < maxAttempts) {
          await Future<void>.delayed(backoffFor(attempt));
          continue;
        }
        throw AdvisorException(
          'Request timed out after ${AppConfig.aiTimeout.inSeconds}s',
          kind: AdvisorErrorKind.network,
        );
      } on http.ClientException catch (e) {
        lastError = e;
        if (attempt + 1 < maxAttempts) {
          await Future<void>.delayed(backoffFor(attempt));
          continue;
        }
        throw AdvisorException(
          'Network error: ${e.message}',
          kind: AdvisorErrorKind.network,
        );
      }
    }
    // Unreachable in practice; kept for compiler completeness.
    throw AdvisorException(
      'Request failed: $lastError',
      kind: AdvisorErrorKind.network,
    );
  }

  Future<String> _parseBackendResponse(http.Response response) async {
    final requestId = response.headers['x-request-id'];
    final status = response.statusCode;

    if (status == 200) {
      final payload = _decodeJson(response, requestId);
      final answer = payload is Map<String, dynamic> ? payload['answer'] : null;
      if (answer is! String || answer.trim().isEmpty) {
        throw AdvisorException(
          'Advisor service returned an invalid response',
          kind: AdvisorErrorKind.invalidResponse,
          statusCode: status,
          requestId: requestId,
        );
      }
      return answer.trim();
    }

    final message = _extractErrorMessage(response) ??
        'Advisor service returned HTTP $status';
    throw AdvisorException(
      message,
      kind: _kindForStatus(status),
      statusCode: status,
      requestId: requestId,
      retryAfter: _parseRetryAfter(response),
    );
  }

  dynamic _decodeJson(http.Response response, String? requestId) {
    final contentType = response.headers['content-type'] ?? '';
    if (contentType.isNotEmpty && !contentType.contains('json')) {
      throw AdvisorException(
        'Unexpected content-type: $contentType',
        kind: AdvisorErrorKind.invalidResponse,
        statusCode: response.statusCode,
        requestId: requestId,
      );
    }
    try {
      return jsonDecode(response.body);
    } on FormatException catch (e) {
      throw AdvisorException(
        'Response is not valid JSON: ${e.message}',
        kind: AdvisorErrorKind.invalidResponse,
        statusCode: response.statusCode,
        requestId: requestId,
      );
    }
  }

  /// Tries both common error shapes:
  ///   • `{"error": "message"}`            (this proxy, and some providers)
  ///   • `{"error": {"message": "..."}}`   (OpenAI-style providers)
  String? _extractErrorMessage(http.Response response) {
    if (response.body.isEmpty) return null;
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    final error = decoded['error'];
    if (error is String) {
      final trimmed = error.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (error is Map) {
      final msg = error['message'];
      if (msg is String && msg.trim().isNotEmpty) return msg.trim();
    }
    return null;
  }

  AdvisorErrorKind _kindForStatus(int status) {
    if (status == 400 || status == 413 || status == 415) {
      return AdvisorErrorKind.badRequest;
    }
    if (status == 401 || status == 403) return AdvisorErrorKind.unauthorized;
    if (status == 429) return AdvisorErrorKind.rateLimited;
    if (status == 503) return AdvisorErrorKind.misconfigured;
    return AdvisorErrorKind.serverError;
  }

  Duration? _parseRetryAfter(http.Response response) {
    final raw = response.headers['retry-after'];
    if (raw == null) return null;
    final seconds = int.tryParse(raw.trim());
    if (seconds != null && seconds > 0) return Duration(seconds: seconds);
    final date = DateTime.tryParse(raw);
    if (date != null) {
      final delta = date.difference(DateTime.now());
      if (delta.isNegative) return Duration.zero;
      return delta;
    }
    return null;
  }
}
