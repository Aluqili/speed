import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';
import 'courier_order_details_screen.dart';

class CourierNotificationsScreen extends StatefulWidget {
  final String driverId;

  const CourierNotificationsScreen({Key? key, required this.driverId})
      : super(key: key);

  @override
  State<CourierNotificationsScreen> createState() =>
      _CourierNotificationsScreenState();
}

class _CourierNotificationsScreenState
    extends State<CourierNotificationsScreen> {
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

    final orderId = (data['orderId'] ?? '').toString().trim();
    if (!mounted || orderId.isEmpty) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CourierOrderDetailsScreen(
          orderId: orderId,
          driverId: widget.driverId,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeArabic.courierBackground,
      appBar: AppBar(
        title: const Text('الإشعارات',
            style: TextStyle(
                color: AppThemeArabic.courierPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 20,
                fontFamily: 'Tajawal')),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 1,
        iconTheme: const IconThemeData(color: AppThemeArabic.courierPrimary),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('driverId', isEqualTo: widget.driverId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'تعذر تحميل الإشعارات الآن. تحقق من إعدادات الفهرسة أو الشبكة.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('لا توجد إشعارات جديدة.',
                  style: TextStyle(fontSize: 16)),
            );
          }

          final notifications = [...snapshot.data!.docs]..sort((a, b) {
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

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final doc = notifications[index];
              final data = doc.data();
              final isRead = data['read'] == true || data['isRead'] == true;
              final type = (data['type'] ?? '').toString().toLowerCase();

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => _openNotification(context, doc),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isRead
                              ? Colors.black12
                              : AppThemeArabic.courierAccent
                                  .withValues(alpha: 0.4),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 14,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: (isRead
                                      ? AppThemeArabic.courierPrimary
                                      : AppThemeArabic.courierAccent)
                                  .withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              _iconForType(type),
                              color: isRead
                                  ? AppThemeArabic.courierPrimary
                                  : AppThemeArabic.courierAccent,
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
                                        (data['title'] ?? 'إشعار بدون عنوان')
                                            .toString(),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: isRead
                                              ? FontWeight.w700
                                              : FontWeight.w800,
                                          color:
                                              AppThemeArabic.courierTextPrimary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatDate(data['createdAt']),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color:
                                            AppThemeArabic.courierTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  (data['body'] ?? '').toString(),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.5,
                                    color: AppThemeArabic.courierTextSecondary,
                                  ),
                                ),
                                if ((data['orderId'] ?? '')
                                    .toString()
                                    .trim()
                                    .isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppThemeArabic.courierPrimary
                                            .withValues(alpha: 0.08),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: const Text(
                                        'اضغط لفتح الطلب',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color:
                                              AppThemeArabic.courierTextPrimary,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    if (date is Timestamp) {
      final dt = date.toDate();
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '';
  }
}
