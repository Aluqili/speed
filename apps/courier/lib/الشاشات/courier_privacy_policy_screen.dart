import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'courier_ui.dart';

class CourierPrivacyPolicyScreen extends StatelessWidget {
  const CourierPrivacyPolicyScreen({super.key});

  static const String _policyUrl =
      'https://speedstar-dev.web.app/legal/privacy-courier-ar.html';
  static const String _deletionUrl =
      'https://speedstar-dev.web.app/legal/account-deletion-courier-ar.html';

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
        appBar: buildCourierAppBar('سياسة الخصوصية'),
        body: CourierPageBackground(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const CourierHeroCard(
                title: 'خصوصية المندوب',
                subtitle:
                    'روابط السياسة الرسمية وحذف الحساب الخاصة بتطبيق المندوب.',
                icon: Icons.privacy_tip_rounded,
              ),
              const SizedBox(height: 14),
              CourierSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CourierSectionTitle(
                      title: 'سياسة الخصوصية للمندوب',
                      subtitle:
                          'توضح كيفية التعامل مع بيانات الحساب والموقع والطلبات.',
                    ),
                    const SizedBox(height: 16),
                    const SelectableText(_policyUrl),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => _openExternalUrl(context, _policyUrl),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('فتح الرابط الرسمي'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          const ClipboardData(text: _policyUrl),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم نسخ رابط سياسة الخصوصية'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('نسخ الرابط'),
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),
                    const CourierSectionTitle(
                      title: 'حذف الحساب',
                      subtitle: 'الرابط الرسمي لطلب حذف حساب المندوب.',
                    ),
                    const SizedBox(height: 12),
                    const SelectableText(_deletionUrl),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => _openExternalUrl(context, _deletionUrl),
                      icon: const Icon(Icons.delete_forever_rounded),
                      label: const Text('فتح صفحة حذف الحساب'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
