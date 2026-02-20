import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'courier_order_details_screen.dart'; // تأكد أن الشاشة موجودة

class CourierNewOrdersScreen extends StatelessWidget {
  final String driverId;

  const CourierNewOrdersScreen({Key? key, required this.driverId}) : super(key: key);

  Future<String?> _getDriverRegion() async {
    final doc = await FirebaseFirestore.instance.collection('drivers').doc(driverId).get();
    if (doc.exists) {
      return doc.data()?['region'];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الطلبات الجديدة')),
      body: FutureBuilder<String?>(
        future: _getDriverRegion(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('لم يتم تحديد منطقتك بعد'));
          }

          final driverRegion = snapshot.data!;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .where('status', isEqualTo: 'قيد المراجعة')
                .where('region', isEqualTo: driverRegion) // فقط الطلبات في نفس المنطقة
                .where('assignedDriverId', isNull: true) // الطلبات غير المعينة
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('لا توجد طلبات جديدة حالياً'));
              }

              final orders = snapshot.data!.docs;

              return ListView.builder(
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final data = orders[index].data() as Map<String, dynamic>;

                  return Card(
                    margin: const EdgeInsets.all(8),
                    child: ListTile(
                      title: Text('طلب #${data['orderId']}'),
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
          );
        },
      ),
    );
  }
}
