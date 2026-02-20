import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CourierNotificationsScreen extends StatelessWidget {
  final String driverId;

  const CourierNotificationsScreen({Key? key, required this.driverId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GFAppBar(
        title: const Text('الإشعارات'),
        backgroundColor: GFColors.PRIMARY,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('driverId', isEqualTo: driverId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: GFLoader(type: GFLoaderType.circle));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('لا توجد إشعارات جديدة.', style: TextStyle(fontSize: 16)),
            );
          }

          final notifications = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final data = notifications[index].data() as Map<String, dynamic>;

              return GFListTile(
                margin: const EdgeInsets.only(bottom: 12),
                color: GFColors.LIGHT,
                avatar: const GFAvatar(
                  backgroundColor: GFColors.PRIMARY,
                  child: Icon(Icons.notifications_active, color: Colors.white),
                ),
                titleText: data['title'] ?? 'إشعار بدون عنوان',
                subTitleText: data['body'] ?? '',
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
      return '${dt.day}/${dt.month}/${dt.year}';
    }
    return '';
  }
}
