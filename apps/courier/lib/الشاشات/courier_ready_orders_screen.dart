import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';
import 'package:speedstar_core/speedstar_core.dart'
    show formatUnifiedOrderCode, OrderStatusPalette;

class CourierReadyOrdersScreen extends StatelessWidget {
  final String driverId;

  const CourierReadyOrdersScreen({Key? key, required this.driverId})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeArabic.clientBackground,
      appBar: AppBar(
        title: const Text('الطلبات الجاهزة للتوصيل',
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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('orders').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = (snapshot.data?.docs ?? []).where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status =
                (data['orderStatus'] ?? data['status'] ?? '').toString();
            return status == 'pickup_ready' || status == 'جاهز للتوصيل';
          }).toList();

          if (orders.isEmpty) {
            return const Center(child: Text('لا توجد طلبات جاهزة حالياً'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final doc = orders[index];
              final data = doc.data() as Map<String, dynamic>;
              final status =
                  (data['orderStatus'] ?? data['status'] ?? '').toString();

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                          'رقم الطلب: ${formatUnifiedOrderCode(orderNumber: data['orderNumber'], orderId: data['orderId'], docId: doc.id)}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('العميل: ${data['clientName'] ?? 'غير متوفر'}'),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color:
                                OrderStatusPalette.backgroundForStatus(status),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            OrderStatusPalette.displayText(status),
                            style: TextStyle(
                              color: OrderStatusPalette.colorForStatus(status),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('المبلغ: ${data['totalWithDelivery'] ?? 0} ج.س'),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          FirebaseFirestore.instance
                              .collection('orders')
                              .doc(doc.id)
                              .update({
                            'orderStatus': 'picked_up',
                            'status': 'picked_up',
                            'assignedDriverId': driverId,
                            'updatedAt': FieldValue.serverTimestamp(),
                          });
                        },
                        icon: const Icon(Icons.delivery_dining),
                        label: const Text('تم استلام الطلب'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppThemeArabic.clientPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                      )
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
}
