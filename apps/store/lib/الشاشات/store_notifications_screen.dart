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

  Future<void> _markAllAsRead() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('notifications')
        .where('restaurantId', isEqualTo: restaurantId)
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'read': true,
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeArabic.storeBackground,
      appBar: AppBar(
        title: const Text(
          'الإشعارات',
          style: TextStyle(
            color: AppThemeArabic.storePrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            fontFamily: 'Tajawal',
          ),
        ),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 1,
        iconTheme: const IconThemeData(color: AppThemeArabic.storePrimary),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
        ),
        actions: [
          IconButton(
            tooltip: 'تعليم الكل كمقروء',
            onPressed: () async {
              await _markAllAsRead();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم تعليم كل الإشعارات كمقروءة')),
              );
            },
            icon: const Icon(Icons.done_all_rounded),
          ),
        ],
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
            return Center(
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.black12),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      size: 54,
                      color: AppThemeArabic.storePrimary,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'لا توجد إشعارات جديدة.',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
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
          final unreadCount = notifications.where((doc) {
            final data = doc.data();
            return !(data['read'] == true || data['isRead'] == true);
          }).length;

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppThemeArabic.storePrimary, Color(0xFF14B8A6)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'مركز إشعارات المطعم',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'تابع الطلبات والتحديثات المهمة أولاً بأول.',
                      style: TextStyle(color: Colors.white70, fontFamily: 'Tajawal'),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _summaryBox('الإجمالي', '${notifications.length}')),
                        const SizedBox(width: 10),
                        Expanded(child: _summaryBox('غير المقروء', '$unreadCount')),
                      ],
                    ),
                  ],
                ),
              ),
              ...notifications.map((doc) {
                final data = doc.data();
                final isRead = data['read'] == true || data['isRead'] == true;
                final hasOrder = (data['orderId'] ?? '').toString().trim().isNotEmpty;

                return InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _openNotification(context, doc),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isRead
                            ? Colors.black12
                            : AppThemeArabic.storePrimary.withValues(alpha: 0.28),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GFAvatar(
                          backgroundColor:
                              hasOrder ? AppThemeArabic.storePrimary : Colors.blueGrey,
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
                                        fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                                        fontFamily: 'Tajawal',
                                      ),
                                    ),
                                  ),
                                  if (!isRead)
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        color: AppThemeArabic.storePrimary,
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
                                  color: AppThemeArabic.storeTextSecondary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(
                                    Icons.schedule_outlined,
                                    size: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatDate(data['createdAt']),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  const Spacer(),
                                  Text(
                                    hasOrder ? 'فتح الطلب' : 'فتح الإشعار',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppThemeArabic.storePrimary,
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
              }),
            ],
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

  Widget _summaryBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              fontFamily: 'Tajawal',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontFamily: 'Tajawal'),
          ),
        ],
      ),
    );
  }
}
