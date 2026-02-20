import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'courier_order_details_screen.dart'; // تأكد أن هذا الملف موجود

class CourierCurrentOrdersTab extends StatelessWidget {
  final String driverId;

  const CourierCurrentOrdersTab({Key? key, required this.driverId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('assignedDriverId', isEqualTo: driverId)
            .where('status', isEqualTo: 'قيد التوصيل')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('لا توجد طلبات قيد التوصيل حالياً'));
          }

          final orders = snapshot.data!.docs;

          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final data = orders[index].data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text('طلب #${data['orderId'] ?? 'غير معروف'}'),
                  subtitle: Text('العميل: ${data['clientName'] ?? 'غير معروف'}'),
                  trailing: ElevatedButton(
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
