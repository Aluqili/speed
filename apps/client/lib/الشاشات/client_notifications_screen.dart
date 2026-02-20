import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ClientNotificationsScreen extends StatelessWidget {
  final String clientId;

  const ClientNotificationsScreen({Key? key, required this.clientId}) : super(key: key);

  static const Color primaryColor = Color(0xFFFE724C);
  static const Color backgroundColor = Color(0xFFF5F5F5);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: ClientNotificationsScreen.backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          centerTitle: true,
          title: const Text('الإشعارات', style: TextStyle(color: ClientNotificationsScreen.primaryColor, fontWeight: FontWeight.bold, fontSize: 20, fontFamily: 'Tajawal')),
          iconTheme: const IconThemeData(color: ClientNotificationsScreen.primaryColor),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('clients')
              .doc(clientId)
              .collection('notifications')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: ClientNotificationsScreen.primaryColor));
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('لا توجد إشعارات حالياً', style: TextStyle(fontFamily: 'Tajawal')));
            }

            final notifications = snapshot.data!.docs;

            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final data = notifications[index].data() as Map<String, dynamic>;
                final title = data['title'] ?? 'تنبيه';
                final body = data['body'] ?? '';
                final timestamp = data['timestamp'] as Timestamp?;
                final date = timestamp?.toDate();

                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 14),
                  child: ListTile(
                    leading: const Icon(Icons.notifications, color: ClientNotificationsScreen.primaryColor),
                    title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(body, style: const TextStyle(fontFamily: 'Tajawal')),
                        if (date != null)
                          Text('${date.day}/${date.month}/${date.year} - ${date.hour}:${date.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Tajawal')),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
