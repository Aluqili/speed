import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';
import 'store_order_details_screen.dart';

class StoreNotificationsScreen extends StatelessWidget {
  final String restaurantId;

  const StoreNotificationsScreen({
    super.key,
    required this.restaurantId,
  });

  Future<void> _openNotification(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final orderId = (data['orderId'] ?? '').toString().trim();

    try {
      await doc.reference.update({
        'read': true,
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Ignore read tracking failures.
    }

    if (orderId.isNotEmpty) {
      final orderDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .get();
      final orderData = orderDoc.data();
      if (context.mounted && orderDoc.exists) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => StoreOrderDetailsScreen(
              orderData: {
                'docId': orderDoc.id,
                ...?orderData,
              },
            ),
          ),
        );
        return;
      }
    }

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text((data['title'] ?? 'إشعار').toString()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text((data['body'] ?? 'لا توجد تفاصيل إضافية').toString()),
            const SizedBox(height: 12),
            Text(
              _formatDate(data['createdAt']),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeArabic.clientBackground,
      appBar: AppBar(
        title: const Text(
          'الإشعارات',
          style: TextStyle(
            color: AppThemeArabic.clientPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            fontFamily: 'Tajawal',
          ),
        ),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 1,
        iconTheme: const IconThemeData(color: AppThemeArabic.clientPrimary),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('restaurantId', isEqualTo: restaurantId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: GFLoader(type: GFLoaderType.circle));
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
              child: Text(
                'لا توجد إشعارات جديدة.',
                style: TextStyle(fontSize: 16),
              ),
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
            padding: const EdgeInsets.all(12),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final doc = notifications[index];
              final data = doc.data();
              final isRead = data['read'] == true || data['isRead'] == true;
              final hasOrder = (data['orderId'] ?? '').toString().trim().isNotEmpty;

              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _openNotification(context, doc),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isRead
                          ? Colors.black12
                          : AppThemeArabic.clientPrimary.withOpacity(0.28),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GFAvatar(
                        backgroundColor: hasOrder
                            ? AppThemeArabic.clientPrimary
                            : Colors.blueGrey,
                        child: Icon(
                          hasOrder ? Icons.receipt_long : Icons.notifications_active,
                          color: Colors.white,
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
                                    (data['title'] ?? 'إشعار بدون عنوان').toString(),
                                    style: TextStyle(
                                      fontWeight: isRead
                                          ? FontWeight.w600
                                          : FontWeight.w800,
                                      fontFamily: 'Tajawal',
                                    ),
                                  ),
                                ),
                                if (!isRead)
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: AppThemeArabic.clientPrimary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              (data['body'] ?? '').toString(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppThemeArabic.clientTextSecondary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Text(
                                  _formatDate(data['createdAt']),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                const Spacer(),
                                Text(
                                  hasOrder ? 'عرض تفاصيل الطلب' : 'عرض التفاصيل',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppThemeArabic.clientPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
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
    if (date is Timestamp) {
      final dt = date.toDate();
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '';
  }
}
