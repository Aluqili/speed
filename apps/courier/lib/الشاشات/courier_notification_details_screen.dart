import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'courier_order_details_screen.dart';
import 'courier_new_orders_screen.dart';
import 'courier_ui.dart';

class CourierNotificationDetailsScreen extends StatelessWidget {
  final String driverId;
  final String title;
  final String body;
  final String type;
  final String orderId;
  final String imageUrl;
  final String linkUrl;
  final DateTime? createdAt;

  const CourierNotificationDetailsScreen({
    super.key,
    required this.driverId,
    required this.title,
    required this.body,
    required this.type,
    required this.orderId,
    required this.imageUrl,
    required this.linkUrl,
    required this.createdAt,
  });

  static String firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = (value ?? '').toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static String extractFirstUrl(String text) {
    final match =
        RegExp(r'https?:\/\/[^\s]+', caseSensitive: false).firstMatch(text);
    if (match == null) return '';
    return match.group(0)?.replaceAll(RegExp(r'[\]\[\)\(>,،؛!؟.,]+$'), '') ??
        '';
  }

  static bool isLikelyImageUrl(String url) {
    final clean = url.trim().toLowerCase();
    if (clean.isEmpty) return false;
    if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
      return false;
    }
    return clean.contains('.jpg') ||
        clean.contains('.jpeg') ||
        clean.contains('.png') ||
        clean.contains('.webp') ||
        clean.contains('.gif') ||
        clean.contains('.avif') ||
        clean.contains('.bmp') ||
        clean.contains('.heic') ||
        clean.contains('.heif') ||
        clean.contains('.tif') ||
        clean.contains('.tiff') ||
        clean.contains('/image/upload/') ||
        clean.contains('firebasestorage.googleapis.com') ||
        clean.contains('storage.googleapis.com');
  }

  static DateTime? parseCreatedAt(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is int) {
      if (raw <= 0) return null;
      return DateTime.fromMillisecondsSinceEpoch(raw);
    }
    final asNum = int.tryParse(raw.toString());
    if (asNum != null && asNum > 0) {
      return DateTime.fromMillisecondsSinceEpoch(asNum);
    }
    final dt = DateTime.tryParse(raw.toString());
    return dt;
  }

  static String iconLabelForType(String type) {
    if (type.contains('offer')) return 'عرض جديد';
    if (type.contains('pickup')) return 'تحديث استلام';
    if (type.contains('assigned')) return 'تعيين طلب';
    if (type.contains('wallet')) return 'تنبيه محفظة';
    return 'تنبيه';
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '';
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.day}/${value.month}/${value.year} $hour:$minute';
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح الرابط.')),
      );
    }
  }

  Future<void> _copyUrl(BuildContext context, String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ الرابط.')),
    );
  }

  void _showImagePreview(BuildContext context, String imageUrl) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                      'تعذر عرض هذه الصيغة داخل التطبيق. استخدم زر فتح المرفق.'),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton.filled(
                tooltip: 'إغلاق المعاينة',
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shownTitle = title.trim().isEmpty ? 'إشعار' : title.trim();
    final shownBody =
        body.trim().isEmpty ? 'لا توجد تفاصيل إضافية' : body.trim();

    final preferredLink =
        linkUrl.trim().isNotEmpty ? linkUrl.trim() : extractFirstUrl(shownBody);

    final shownImage = isLikelyImageUrl(imageUrl)
        ? imageUrl.trim()
        : (isLikelyImageUrl(preferredLink) ? preferredLink : '');

    return Scaffold(
      appBar: buildCourierAppBar('تفاصيل الإشعار'),
      body: CourierPageBackground(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CourierHeroCard(
              title: shownTitle,
              subtitle: iconLabelForType(type.toLowerCase()),
              icon: Icons.notifications_active_rounded,
            ),
            const SizedBox(height: 14),
            CourierSectionCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_formatDate(createdAt).isNotEmpty) ...[
                    Text(
                      _formatDate(createdAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7A6857),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    shownBody,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (shownImage.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: () => _showImagePreview(context, shownImage),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Image.network(
                            shownImage,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            },
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFFF3EEE8),
                              alignment: Alignment.center,
                              child: const Text(
                                'تعذر عرض الصورة داخل التطبيق. افتح المرفق لمشاهدتها.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (preferredLink.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    SelectableText(
                      preferredLink,
                      style: const TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (type.toLowerCase() == 'courier_offer_pending')
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CourierNewOrdersScreen(
                        driverId: driverId,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.local_shipping_rounded),
                label: const Text('فتح العروض المتاحة'),
              )
            else if (orderId.trim().isNotEmpty)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CourierOrderDetailsScreen(
                        orderId: orderId.trim(),
                        driverId: driverId,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('فتح الطلب المرتبط'),
              ),
            if (preferredLink.isNotEmpty || shownImage.isNotEmpty) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _openUrl(
                  context,
                  shownImage.isNotEmpty ? shownImage : preferredLink,
                ),
                icon: const Icon(Icons.link_rounded),
                label: Text(shownImage.isNotEmpty
                    ? 'فتح الصورة أو المرفق'
                    : 'فتح الرابط'),
              ),
              if ((shownImage.isNotEmpty ? shownImage : preferredLink)
                  .isNotEmpty) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _copyUrl(
                    context,
                    shownImage.isNotEmpty ? shownImage : preferredLink,
                  ),
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('نسخ رابط المرفق'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
