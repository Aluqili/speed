import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class ClientPrivacyPolicyScreen extends StatelessWidget {
  const ClientPrivacyPolicyScreen({super.key});

  static const String _policyUrl =
      'https://speedstarapp.web.app/legal/privacy-client-ar.html';
  static const String _deletionUrl =
      'https://speedstarapp.web.app/legal/account-deletion-client-ar.html';

  Future<void> _openExternalUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح الرابط')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('سياسة الخصوصية'),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'نحن نحترم خصوصيتك',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'هذه نسخة مختصرة داخل التطبيق.\nيمكنك قراءة النسخة الكاملة عبر الرابط الرسمي أدناه.',
                      style: TextStyle(height: 1.8),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'الرابط الرسمي:',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      _policyUrl,
                      style: const TextStyle(color: Colors.blueAccent),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => _openExternalUrl(context, _policyUrl),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('فتح الرابط الرسمي'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          const ClipboardData(text: _policyUrl),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('تم نسخ رابط سياسة الخصوصية')),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('نسخ الرابط'),
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),
                    const Text(
                      'رابط حذف الحساب الرسمي:',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      _deletionUrl,
                      style: const TextStyle(color: Colors.blueAccent),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => _openExternalUrl(context, _deletionUrl),
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('فتح صفحة حذف الحساب'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
