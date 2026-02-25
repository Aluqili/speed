import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';

class ClientNotificationsScreen extends StatefulWidget {
  final String clientId;

  const ClientNotificationsScreen({Key? key, required this.clientId}) : super(key: key);

  @override
  State<ClientNotificationsScreen> createState() => _ClientNotificationsScreenState();
}

class _ClientNotificationsScreenState extends State<ClientNotificationsScreen> {
  @override
  void initState() {
    super.initState();
    _markAllAsRead();
  }

  Future<void> _markAllAsRead() async {
    try {
      final unread = await FirebaseFirestore.instance
          .collection('clients')
          .doc(widget.clientId)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .limit(300)
          .get();

      if (unread.docs.isEmpty) {
        final maybeUnread = await FirebaseFirestore.instance
            .collection('clients')
            .doc(widget.clientId)
            .collection('notifications')
            .orderBy('timestamp', descending: true)
            .limit(300)
            .get();

        final batch = FirebaseFirestore.instance.batch();
        var ops = 0;
        for (final doc in maybeUnread.docs) {
          if ((doc.data()['isRead'] ?? false) == true) continue;
          batch.update(doc.reference, {
            'isRead': true,
            'readAt': FieldValue.serverTimestamp(),
          });
          ops += 1;
        }
        if (ops > 0) {
          await batch.commit();
        }
        return;
      }

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in unread.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (_) {
      // keep UI functional even if marking fails
    }
  }

  static const Color primaryColor = AppThemeArabic.clientPrimary;
  static const Color backgroundColor = AppThemeArabic.clientBackground;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          centerTitle: true,
          title: const Text('الإشعارات', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 20, fontFamily: 'Tajawal')),
          iconTheme: const IconThemeData(color: primaryColor),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('clients')
              .doc(widget.clientId)
              .collection('notifications')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: primaryColor));
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
                    leading: const Icon(Icons.notifications, color: primaryColor),
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
