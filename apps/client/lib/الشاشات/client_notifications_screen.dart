import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../الثيم/client_theme.dart';
import '../الخدمات/push_notification_service.dart';

class ClientNotificationsScreen extends StatefulWidget {
  final String clientId;

  const ClientNotificationsScreen({super.key, required this.clientId});

  @override
  State<ClientNotificationsScreen> createState() =>
      _ClientNotificationsScreenState();
}

class _ClientNotificationsScreenState extends State<ClientNotificationsScreen> {
  static const _primary = ClientColors.primary;
  String get _effectiveClientId {
    final fromWidget = widget.clientId.trim();
    if (fromWidget.isNotEmpty) return fromWidget;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return '';
    return user.uid;
  }

  @override
  void initState() {
    super.initState();
    _markAllAsRead();
  }

  Future<void> _markAllAsRead() async {
    final clientId = _effectiveClientId;
    if (clientId.isEmpty) return;
    try {
      final recentSnapshots = await Future.wait([
        FirebaseFirestore.instance
            .collection('clients')
            .doc(clientId)
            .collection('notifications')
            .limit(50)
            .get(),
        FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: clientId)
            .limit(50)
            .get(),
        FirebaseFirestore.instance
            .collection('notifications')
            .where('clientId', isEqualTo: clientId)
            .limit(50)
            .get(),
      ]);

      final batch = FirebaseFirestore.instance.batch();
      var ops = 0;
      for (final recent in recentSnapshots) {
        for (final doc in recent.docs) {
          if (_readBool(doc.data()['isRead'])) continue;
          batch.update(doc.reference, {
            'isRead': true,
            'readAt': FieldValue.serverTimestamp(),
          });
          ops++;
        }
      }
      if (ops > 0) await batch.commit();
    } catch (e) {
      debugPrint('Error marking notifications as read: $e');
    }
  }

  bool _readBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return false;
  }

  Timestamp? _readTimestamp(Map<String, dynamic> data) {
    final candidates = [
      data['timestamp'],
      data['createdAt'],
      data['sentAt'],
      data['updatedAt'],
    ];
    for (final value in candidates) {
      if (value is Timestamp) return value;
      if (value is DateTime) return Timestamp.fromDate(value);
      if (value is num) {
        final millis = value.toInt();
        if (millis > 0) {
          return Timestamp.fromMillisecondsSinceEpoch(millis);
        }
      }
    }
    return null;
  }

  String _textField(Map<String, dynamic> data, List<String> keys,
      {String fallback = ''}) {
    for (final key in keys) {
      final text = (data[key] ?? '').toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return fallback;
  }

  Future<void> _deleteNotification(DocumentReference reference) async {
    try {
      await reference.delete();
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '';
    final date = ts.toDate().toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);

    final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour < 12 ? 'ص' : 'م';
    final time = '$hour12:$minute $period';
    if (d == today) return 'اليوم  $time';
    if (d == yesterday) return 'أمس  $time';
    return '${date.day}/${date.month}/${date.year}  $time';
  }

  IconData _iconForNotification(Map<String, dynamic> data) {
    final text = [
      data['type'],
      data['source'],
      data['category'],
      data['title'],
      data['body'],
    ].map((value) => (value ?? '').toString().toLowerCase()).join(' ');

    if (text.contains('support') || text.contains('دعم')) {
      return Icons.support_agent_rounded;
    }
    if (text.contains('chat') ||
        text.contains('message') ||
        text.contains('رسالة')) {
      return Icons.chat_bubble_rounded;
    }
    if (text.contains('طلب') || text.contains('order')) {
      return Icons.receipt_long_rounded;
    }
    if (text.contains('دفع') || text.contains('payment')) {
      return Icons.payments_rounded;
    }
    if (text.contains('مندوب') ||
        text.contains('driver') ||
        text.contains('courier')) {
      return Icons.delivery_dining_rounded;
    }
    if (text.contains('محفظة') || text.contains('wallet')) {
      return Icons.account_balance_wallet_rounded;
    }
    if (text.contains('ترقية') ||
        text.contains('عرض') ||
        text.contains('promo') ||
        text.contains('offer')) {
      return Icons.local_offer_rounded;
    }
    return Icons.notifications_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenBg =
        isDark ? ClientColors.background : ClientColors.lightBackground;
    final clientId = _effectiveClientId;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: screenBg,
        appBar: AppBar(
          centerTitle: true,
          title: const Text('الإشعارات'),
          iconTheme: const IconThemeData(color: _primary),
        ),
        body: clientId.isEmpty
            ? const _NotificationsEmptyState(
                title: 'سجل الدخول لعرض الإشعارات',
                subtitle: 'ستظهر إشعارات طلباتك وعروضك هنا بعد تسجيل الدخول.',
              )
            : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('clients')
              .doc(clientId)
              .collection('notifications')
              .limit(50)
              .snapshots(),
          builder: (context, privateSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('userId', isEqualTo: clientId)
                  .limit(50)
                  .snapshots(),
              builder: (context, publicSnapshot) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('notifications')
                      .where('clientId', isEqualTo: clientId)
                      .limit(50)
                      .snapshots(),
                  builder: (context, clientIdSnapshot) {
                    // نعرض التحميل ما دام استعلام الـ subcollection الأساسي لم يرد بعد
                    if (privateSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(color: _primary));
                    }

                    if (privateSnapshot.hasError ||
                        publicSnapshot.hasError ||
                        clientIdSnapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 48, color: ClientColors.textSecondary),
                            const SizedBox(height: 8),
                            const Text('تعذر تحميل الإشعارات',
                                style: TextStyle(
                                    color: ClientColors.textSecondary)),
                            if (privateSnapshot.hasError) ...[
                              const SizedBox(height: 4),
                              Text(
                                privateSnapshot.error.toString(),
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: ClientColors.textSecondary),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      );
                    }

                    final docsByPath =
                        <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
                    for (final doc in privateSnapshot.data?.docs ??
                        const <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
                      docsByPath[doc.reference.path] = doc;
                    }
                    for (final doc in publicSnapshot.data?.docs ??
                        const <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
                      docsByPath[doc.reference.path] = doc;
                    }
                    for (final doc in clientIdSnapshot.data?.docs ??
                        const <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
                      docsByPath[doc.reference.path] = doc;
                    }

                    final docs = docsByPath.values.toList()
                      ..sort((a, b) {
                        final ad = a.data();
                        final bd = b.data();
                        final am =
                            _readTimestamp(ad)?.millisecondsSinceEpoch ?? 0;
                        final bm =
                            _readTimestamp(bd)?.millisecondsSinceEpoch ?? 0;
                        return bm.compareTo(am);
                      });

                    if (docs.isEmpty) {
                      final textColor = Theme.of(context).colorScheme.onSurface;
                      final subtitleColor =
                          Theme.of(context).colorScheme.onSurfaceVariant;
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                color: _primary.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                  Icons.notifications_off_outlined,
                                  size: 42,
                                  color: _primary),
                            ),
                            const SizedBox(height: 16),
                            Text('لا توجد إشعارات',
                                style: TextStyle(
                                    color: textColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text('ستظهر هنا عند وصول أي إشعار',
                                style: TextStyle(
                                    color: subtitleColor, fontSize: 13)),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data();
                        final title = _textField(
                          data,
                          const ['title', 'notificationTitle', 'heading'],
                          fallback: 'تنبيه',
                        );
                        final body = _textField(
                          data,
                          const ['body', 'message', 'text', 'description'],
                        );
                        final timestamp = _readTimestamp(data);
                        final isRead = _readBool(data['isRead']);

                        return Dismissible(
                          key: Key(doc.reference.path),
                          direction: DismissDirection.startToEnd,
                          background: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: ClientColors.error,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(Icons.delete_rounded,
                                color: Colors.white, size: 22),
                          ),
                          onDismissed: (_) =>
                              _deleteNotification(doc.reference),
                          child: _NotificationCard(
                            title: title,
                            body: body,
                            time: _formatDate(timestamp),
                            icon: _iconForNotification(data),
                            isRead: isRead,
                            onTap: () {
                              PushNotificationService.instance.openFromNotificationData({
                                ...data,
                                'userId': clientId,
                              });
                            },
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _NotificationsEmptyState extends StatelessWidget {
  const _NotificationsEmptyState({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subtitleColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: ClientColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_off_outlined,
              size: 42,
              color: ClientColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: subtitleColor, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─── بطاقة الإشعار ────────────────────────────────────────────────────────

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.title,
    required this.body,
    required this.time,
    required this.icon,
    required this.isRead,
    this.onTap,
  });

  final String title;
  final String body;
  final String time;
  final IconData icon;
  final bool isRead;
  final VoidCallback? onTap;

  static const _primary = ClientColors.primary;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark
        ? (isRead ? const Color(0xFF1A1A1A) : const Color(0xFF2A1005))
        : (isRead ? Colors.white : const Color(0xFFFFF6F1));
    final titleColor = Theme.of(context).colorScheme.onSurface;
    final subtitleColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: isRead
            ? Border.all(color: const Color(0x14000000), width: 0.5)
            : Border.all(color: _primary.withValues(alpha: 0.25), width: 1),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _primary.withValues(alpha: isRead ? 0.08 : 0.16),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: _primary, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                    fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                    fontSize: 14,
                    color: titleColor),
              ),
            ),
            if (!isRead)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                    color: _primary, shape: BoxShape.circle),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (body.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(body,
                  style: TextStyle(
                      fontSize: 13, color: subtitleColor, height: 1.4)),
            ],
            if (time.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(time,
                  style: TextStyle(
                      fontSize: 11,
                      color: subtitleColor.withValues(alpha: 0.7))),
            ],
          ],
        ),
      ),
    );
  }
}
