import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';

class CourierPrivacyPolicyScreen extends StatelessWidget {
  const CourierPrivacyPolicyScreen({super.key});

  static const String _policyUrl =
      'https://speedstar-dev.web.app/legal/privacy-courier-ar.html';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppThemeArabic.clientBackground,
        appBar: AppBar(
          title: const Text('سياسة الخصوصية', style: TextStyle(color: AppThemeArabic.clientPrimary, fontWeight: FontWeight.bold, fontSize: 20, fontFamily: 'Tajawal')),
          backgroundColor: Colors.white,
          centerTitle: true,
          elevation: 1,
          iconTheme: const IconThemeData(color: AppThemeArabic.clientPrimary),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
          ),
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
                      'سياسة الخصوصية للمندوب',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'يوضح هذا القسم كيفية التعامل مع بيانات حساب المندوب والموقع والطلبات.',
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
                      style: const TextStyle(color: AppThemeArabic.clientPrimary),
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
