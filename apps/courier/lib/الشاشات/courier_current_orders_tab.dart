import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';
import 'courier_order_details_screen.dart'; // تأكد أن هذا الملف موجود

class CourierCurrentOrdersTab extends StatelessWidget {
  final String driverId;
  static const List<String> activeStatuses = [
    'courier_assigned',
    'pickup_ready',
    'picked_up',
    'arrived_to_client',
    'جاهز للتوصيل',
    'قيد التوصيل',
    'وصل إلى العميل',
  ];

  const CourierCurrentOrdersTab({Key? key, required this.driverId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeArabic.clientBackground,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('assignedDriverId', isEqualTo: driverId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('لا توجد طلبات قيد التوصيل حالياً'));
          }

          final orders = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = (data['orderStatus'] ?? data['status'] ?? '').toString();
            return activeStatuses.contains(status);
          }).toList();

          if (orders.isEmpty) {
            return const Center(child: Text('لا توجد طلبات قيد التوصيل حالياً'));
          }

          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final data = orders[index].data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.all(8),
                color: AppThemeArabic.clientSurface,
                child: ListTile(
                  title: Text('طلب #${data['orderId'] ?? 'غير معروف'}'),
                  subtitle: Text('العميل: ${data['clientName'] ?? 'غير معروف'}'),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppThemeArabic.clientPrimary, foregroundColor: Colors.white),
                    child: const Text('عرض التفاصيل'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CourierOrderDetailsScreen(
                            orderId: orders[index].id,
                            driverId: driverId,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
