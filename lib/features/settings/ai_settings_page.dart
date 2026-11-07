import 'package:flutter/material.dart';

import '../services/ai_settings_store.dart';

class AiSettingsPage extends StatefulWidget {
  const AiSettingsPage({super.key});

  @override
  State<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends State<AiSettingsPage> {
  final _store = AiSettingsStore();
  final _keyController = TextEditingController();
  final _urlController = TextEditingController();
  final _modelController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _showKey = false;
  bool _hasSavedKey = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _keyController.dispose();
    _urlController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final settings = await _store.load();
      if (!mounted) return;
      setState(() {
        _keyController.text = settings.apiKey;
        _urlController.text = settings.baseUrl;
        _modelController.text = settings.model;
        _hasSavedKey = settings.apiKey.isNotEmpty;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = 'خواندن تنظیمات امن دستگاه ممکن نشد.';
        _messageIsError = true;
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      await _store.save(AiProviderSettings(
        apiKey: _keyController.text,
        baseUrl: _urlController.text,
        model: _modelController.text,
      ));
      if (!mounted) return;
      setState(() {
        _hasSavedKey = true;
        _saving = false;
        _message = 'تنظیمات با امنیت روی همین دستگاه ذخیره شد.';
        _messageIsError = false;
      });
    } on ArgumentError catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _message = error.message.toString();
        _messageIsError = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _message = 'ذخیره تنظیمات انجام نشد؛ فضای امن دستگاه را بررسی کنید.';
        _messageIsError = true;
      });
    }
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف کلید هوش مصنوعی؟'),
        content: const Text('کلید و تنظیمات اتصال از این گوشی حذف می‌شوند.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف کلید'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _store.clear();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = 'حذف کلید از حافظه امن انجام نشد.';
        _messageIsError = true;
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _keyController.clear();
      _urlController.text = 'https://api.deepseek.com';
      _modelController.text = 'deepseek-chat';
      _hasSavedKey = false;
      _message = 'کلید از حافظه امن گوشی حذف شد.';
      _messageIsError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تنظیمات هوش مصنوعی')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Row(
                          children: [
                            Icon(Icons.phonelink_lock_outlined),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'اتصال مستقیم از گوشی',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'درخواست‌ها مستقیماً از اینترنت گوشی به سرویس انتخابی شما ارسال می‌شوند. '
                          'هیچ سرور واسط یا حساب کاربری در این برنامه وجود ندارد.',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _urlController,
                  keyboardType: TextInputType.url,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'نشانی سرویس (HTTPS)',
                    hintText: 'https://api.deepseek.com',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _modelController,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'نام مدل',
                    hintText: 'deepseek-chat',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _keyController,
                  obscureText: !_showKey,
                  autocorrect: false,
                  enableSuggestions: false,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: 'کلید API شخصی شما',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: _showKey ? 'پنهان کردن کلید' : 'نمایش کلید',
                      onPressed: () => setState(() => _showKey = !_showKey),
                      icon: Icon(_showKey ? Icons.visibility_off : Icons.visibility),
                    ),
                  ),
                ),
                if (_hasSavedKey)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'یک کلید روی این دستگاه ذخیره شده است.',
                      style: TextStyle(color: Colors.green),
                    ),
                  ),
                const SizedBox(height: 12),
                const Text(
                  'کلید در حافظه امن اندروید نگهداری می‌شود و به برنامه دیگری ارسال نمی‌شود؛ '
                  'اما در گوشی روت‌شده یا آلوده، هیچ روش ذخیره‌سازی محلی مصونیت کامل ندارد. '
                  'هزینه درخواست‌ها طبق تعرفه ارائه‌دهنده و حساب خودتان محاسبه می‌شود.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _message!,
                    style: TextStyle(
                      color: _messageIsError ? Colors.red : Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'در حال ذخیره…' : 'ذخیره تنظیمات'),
                ),
                OutlinedButton.icon(
                  onPressed: _hasSavedKey ? _clear : null,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('حذف کلید ذخیره‌شده'),
                ),
              ],
            ),
    );
  }
}
