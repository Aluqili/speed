import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ClientPrivacyPolicyScreen extends StatelessWidget {
  const ClientPrivacyPolicyScreen({super.key});

  static const String _policyUrl =
      'https://speedstar-dev.web.app/legal/privacy-client-ar.html';

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
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                      onPressed: () async {
                        await Clipboard.setData(
                          const ClipboardData(text: _policyUrl),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم نسخ رابط سياسة الخصوصية')),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('نسخ الرابط'),
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
