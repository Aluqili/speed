import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'courier_new_orders_screen.dart';
import 'courier_notification_details_screen.dart';
import 'courier_ui.dart';

class CourierNotificationsScreen extends StatefulWidget {
  final String driverId;

  const CourierNotificationsScreen({super.key, required this.driverId});

  @override
  State<CourierNotificationsScreen> createState() =>
      _CourierNotificationsScreenState();
}

class _CourierNotificationsScreenState
    extends State<CourierNotificationsScreen> {
  String _extractFirstUrl(String text) {
    final match =
        RegExp(r'https?:\/\/[^\s]+', caseSensitive: false).firstMatch(text);
    if (match == null) return '';
    return match.group(0)?.replaceAll(RegExp(r'[\]\[\)\(>,،؛!؟.,]+$'), '') ??
        '';
  }

  String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = (value ?? '').toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  String _notificationImageUrl(Map<String, dynamic> data) {
    return _firstNonEmpty([
      data['imageUrl'],
      data['image'],
      data['photoUrl'],
      data['proofImageUrl'],
      data['receiptImageUrl'],
    ]);
  }

  String _notificationLink(Map<String, dynamic> data) {
    final body = (data['body'] ?? '').toString();
    return _firstNonEmpty([
      data['receiptUrl'],
      data['url'],
      data['link'],
      _extractFirstUrl(body),
    ]);
  }

  Future<void> _openNotification(
    BuildContext context,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data() ?? <String, dynamic>{};
    await doc.reference.set({
      'read': true,
      'isRead': true,
      'readAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;
    final type = (data['type'] ?? '').toString().toLowerCase();
    if (type == 'courier_offer_pending') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CourierNewOrdersScreen(driverId: widget.driverId),
        ),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CourierNotificationDetailsScreen(
          driverId: widget.driverId,
          title: (data['title'] ?? 'إشعار').toString(),
          body: (data['body'] ?? '').toString(),
          type: (data['type'] ?? '').toString(),
          orderId: (data['orderId'] ?? '').toString(),
          imageUrl: _notificationImageUrl(data),
          linkUrl: _notificationLink(data),
          createdAt: CourierNotificationDetailsScreen.parseCreatedAt(
              data['createdAt']),
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    if (type.contains('offer')) return Icons.local_shipping_rounded;
    if (type.contains('pickup')) return Icons.inventory_2_rounded;
    if (type.contains('assigned')) return Icons.assignment_turned_in_rounded;
    if (type.contains('wallet')) return Icons.account_balance_wallet_rounded;
    return Icons.notifications_active_rounded;
  }

  String _formatDate(dynamic date) {
    if (date is! Timestamp) return '';
    final dt = date.toDate();
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildCourierAppBar('الإشعارات'),
      body: CourierPageBackground(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('notifications')
              .where('driverId', isEqualTo: widget.driverId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const CourierEmptyState(
                title: 'تعذر تحميل الإشعارات',
                message: 'تحقق من الاتصال أو أعد المحاولة بعد قليل.',
                icon: Icons.error_outline_rounded,
              );
            }

            final notifications = (snapshot.data?.docs ?? const [])
                .where((doc) =>
                    (doc.data()['type'] ?? '').toString().toLowerCase() !=
                    'courier_offer_pending')
                .toList()
              ..sort((a, b) {
                final aDate = a.data()['createdAt'];
                final bDate = b.data()['createdAt'];
                final aMs = aDate is Timestamp
                    ? aDate.millisecondsSinceEpoch
                    : (aDate is num ? aDate.toInt() : 0);
                final bMs = bDate is Timestamp
                    ? bDate.millisecondsSinceEpoch
                    : (bDate is num ? bDate.toInt() : 0);
                return bMs.compareTo(aMs);
              });

            if (notifications.isEmpty) {
              return const CourierEmptyState(
                title: 'لا توجد إشعارات جديدة',
                message: 'أي تحديث يخص الطلبات أو المحفظة سيظهر هنا.',
                icon: Icons.notifications_off_outlined,
              );
            }

            final unreadCount = notifications.where((doc) {
              final data = doc.data();
              return !(data['read'] == true || data['isRead'] == true);
            }).length;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                CourierHeroCard(
                  title: '$unreadCount غير مقروء',
                  subtitle:
                      'الإشعارات الأحدث المتعلقة بالعروض والطلبات والحساب.',
                  icon: Icons.notifications_active_rounded,
                ),
                const SizedBox(height: 16),
                ...notifications.map((doc) {
                  final data = doc.data();
                  final isRead = data['read'] == true || data['isRead'] == true;
                  final type = (data['type'] ?? '').toString().toLowerCase();
                  final body = (data['body'] ?? '').toString();
                  final imageUrl = _notificationImageUrl(data);
                  final hasImage =
                      CourierNotificationDetailsScreen.isLikelyImageUrl(
                    imageUrl,
                  );
                  final hasLink = _notificationLink(data).isNotEmpty;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () => _openNotification(context, doc),
                      child: CourierSectionCard(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: (isRead
                                      ? const Color(0xFF8B5E34)
                                      : const Color(0xFFE1A44A))
                                  .withValues(alpha: 0.14),
                              child: Icon(
                                _iconForType(type),
                                color: isRead
                                    ? const Color(0xFF8B5E34)
                                    : const Color(0xFFE1A44A),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          (data['title'] ?? 'إشعار').toString(),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: isRead
                                                ? FontWeight.w700
                                                : FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _formatDate(data['createdAt']),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF7A6857),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    body,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.5,
                                      color: Color(0xFF7A6857),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (hasImage ||
                                      hasLink ||
                                      (data['orderId'] ?? '')
                                          .toString()
                                          .trim()
                                          .isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 10),
                                      child: OutlinedButton.icon(
                                        onPressed: () =>
                                            _openNotification(context, doc),
                                        icon: const Icon(
                                          Icons.visibility_outlined,
                                        ),
                                        label: const Text('عرض تفاصيل الإشعار'),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}
