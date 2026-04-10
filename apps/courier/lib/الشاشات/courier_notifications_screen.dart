import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';

class CourierNotificationsScreen extends StatelessWidget {
  final String driverId;

  const CourierNotificationsScreen({Key? key, required this.driverId})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeArabic.clientBackground,
      appBar: AppBar(
        title: const Text('الإشعارات',
            style: TextStyle(
                color: AppThemeArabic.clientPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 20,
                fontFamily: 'Tajawal')),
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
            .where('driverId', isEqualTo: driverId)
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
            padding: const EdgeInsets.all(12),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final data = notifications[index].data();

              return GFListTile(
                margin: const EdgeInsets.only(bottom: 12),
                color: AppThemeArabic.clientSurface,
                avatar: const GFAvatar(
                  backgroundColor: AppThemeArabic.clientPrimary,
                  child: Icon(Icons.notifications_active, color: Colors.white),
                ),
                titleText: (data['title'] ?? 'إشعار بدون عنوان').toString(),
                subTitleText: (data['body'] ?? '').toString(),
                icon: Text(
                  _formatDate(data['createdAt']),
                  style: const TextStyle(fontSize: 12),
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
