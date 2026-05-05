import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';

class ClientNotificationsScreen extends StatefulWidget {
  final String clientId;

  const ClientNotificationsScreen({Key? key, required this.clientId})
      : super(key: key);

  @override
  State<ClientNotificationsScreen> createState() =>
      _ClientNotificationsScreenState();
}

class _ClientNotificationsScreenState
    extends State<ClientNotificationsScreen> {
  static const _primary = AppThemeArabic.clientPrimary;

  @override
  void initState() {
    super.initState();
    _markAllAsRead();
  }

  Future<void> _markAllAsRead() async {
    try {
      final recent = await FirebaseFirestore.instance
          .collection('clients')
          .doc(widget.clientId)
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      var ops = 0;
      for (final doc in recent.docs) {
        if ((doc.data()['isRead'] as bool? ?? false)) continue;
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
        ops++;
      }
      if (ops > 0) await batch.commit();
    } catch (_) {}
  }

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '';
    final date = ts.toDate().toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);

    final time = intl.DateFormat('hh:mm a', 'ar').format(date);
    if (d == today) return 'اليوم  $time';
    if (d == yesterday) return 'أمس  $time';
    return '${intl.DateFormat('d MMM', 'ar').format(date)}  $time';
  }

  IconData _iconForTitle(String title) {
    final t = title.toLowerCase();
    if (t.contains('طلب') || t.contains('order')) return Icons.receipt_long_rounded;
    if (t.contains('دفع') || t.contains('payment')) return Icons.payments_rounded;
    if (t.contains('مندوب') || t.contains('driver')) return Icons.delivery_dining_rounded;
    if (t.contains('محفظة') || t.contains('wallet')) return Icons.account_balance_wallet_rounded;
    if (t.contains('ترقية') || t.contains('promo')) return Icons.local_offer_rounded;
    return Icons.notifications_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          centerTitle: true,
          title: const Text(
            'الإشعارات',
            style: TextStyle(
                color: _primary,
                fontWeight: FontWeight.bold,
                fontSize: 18),
          ),
          iconTheme: const IconThemeData(color: _primary),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('clients')
              .doc(widget.clientId)
              .collection('notifications')
              .orderBy('timestamp', descending: true)
              .limit(50)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: _primary));
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline,
                        size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text('تعذر تحميل الإشعارات',
                        style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_off_outlined,
                        size: 56, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text('لا توجد إشعارات',
                        style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('ستظهر هنا عند وصول أي إشعار',
                        style: TextStyle(
                            color: Colors.grey[400], fontSize: 13)),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final title = (data['title'] ?? 'تنبيه').toString();
                final body = (data['body'] ?? '').toString();
                final ts = data['timestamp'];
                final timestamp = ts is Timestamp ? ts : null;
                final isRead = data['isRead'] as bool? ?? false;

                return _NotificationCard(
                  title: title,
                  body: body,
                  time: _formatDate(timestamp),
                  icon: _iconForTitle(title),
                  isRead: isRead,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.title,
    required this.body,
    required this.time,
    required this.icon,
    required this.isRead,
  });

  final String title;
  final String body;
  final String time;
  final IconData icon;
  final bool isRead;

  static const _primary = AppThemeArabic.clientPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : const Color(0xFFFFF3EE),
        borderRadius: BorderRadius.circular(14),
        border: isRead
            ? null
            : Border.all(color: _primary.withValues(alpha: 0.2), width: 1),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _primary.withValues(alpha: isRead ? 0.08 : 0.15),
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
                    fontWeight:
                        isRead ? FontWeight.w500 : FontWeight.bold,
                    fontSize: 14),
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
                      fontSize: 13, color: Colors.grey[700], height: 1.4)),
            ],
            if (time.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(time,
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey[400])),
            ],
          ],
        ),
      ),
    );
  }
}
