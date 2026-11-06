import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// Optional AI guidance via embedded key or backend proxy.
class AdvisorApi {
  Future<String?> requestAnswer({
    required String stage,
    required String goal,
    required String question,
  }) async {
    if (AppConfig.hasDirectAiKey) {
      return _requestDirect(stage: stage, goal: goal, question: question);
    }
    if (AppConfig.hasAdvisorBackend) {
      return _requestBackend(stage: stage, goal: goal, question: question);
    }
    return null;
  }

  Future<String> _requestDirect({
    required String stage,
    required String goal,
    required String question,
  }) async {
    var baseUrl = AppConfig.aiBaseUrl.trim();
    while (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }
    if (!baseUrl.endsWith('/chat/completions')) {
      baseUrl = '$baseUrl/chat/completions';
    }
    final response = await http
        .post(
          Uri.parse(baseUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${AppConfig.aiApiKey}',
          },
          body: jsonEncode({
            'model': AppConfig.aiModel,
            'messages': [
              {
                'role': 'system',
                'content':
                    'تو مربی آموزشی فارسی‌زبان و صبور هستی. پاسخ را متناسب با مقطع تحصیلی کاربر تنظیم کن. ابتدا فهم مسئله را روشن کن، مطالب را مرحله‌به‌مرحله توضیح بده، مثال ساده بزن و در پایان یک سؤال یا تمرین کوتاه برای سنجش فهم بده. اگر اطلاعات کافی نیست، سؤال روشن‌کننده بپرس. برای کودکان ساده و امن توضیح بده. نتیجه یا اطلاعات پذیرش دانشگاه را تضمین نکن.',
              },
              {
                'role': 'user',
                'content': 'مقطع: $stage\nموضوع: $goal\nدرخواست: $question',
              },
            ],
            'temperature': 0.4,
            'max_tokens': 800,
            'stream': false,
          }),
        )
        .timeout(const Duration(seconds: 35));
    if (response.statusCode != 200) {
      throw const FormatException('AI provider returned an error');
    }
    final payload = jsonDecode(response.body);
    final choices = payload is Map<String, dynamic> ? payload['choices'] : null;
    final message = choices is List && choices.isNotEmpty && choices.first is Map
        ? choices.first['message']
        : null;
    final content = message is Map ? message['content'] : null;
    if (content is! String || content.trim().isEmpty) {
      throw const FormatException('AI provider returned an invalid response');
    }
    return content.trim();
  }

  Future<String> _requestBackend({
    required String stage,
    required String goal,
    required String question,
  }) async {
    final baseUrl =
        AppConfig.advisorApiBaseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/advice'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'stage': stage,
            'goal': goal,
            'question': question,
          }),
        )
        .timeout(const Duration(seconds: 35));
    if (response.statusCode != 200) {
      throw const FormatException('Advisor service returned an error');
    }
    final payload = jsonDecode(response.body);
    final answer = payload is Map<String, dynamic> ? payload['answer'] : null;
    if (answer is! String || answer.trim().isEmpty) {
      throw const FormatException('Advisor service returned an invalid response');
    }
    return answer.trim();
  }
}
