import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';
import 'package:speedstar_core/speedstar_core.dart'
    show formatUnifiedOrderCode, OrderStatusPalette;

import 'courier_order_details_screen.dart';

class CourierNewOrdersScreen extends StatelessWidget {
  final String driverId;

  const CourierNewOrdersScreen({Key? key, required this.driverId})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeArabic.clientBackground,
      appBar: AppBar(
        title: const Text('الطلبات الجديدة',
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
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('offeredDriverId', isEqualTo: driverId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('لا توجد عروض متاحة لك حالياً'));
          }

          final orders = snapshot.data!.docs.where((d) {
            final m = d.data() as Map<String, dynamic>;
            final status = (m['orderStatus'] ?? m['status'] ?? '').toString();
            return status == 'courier_offer_pending';
          }).toList();

          if (orders.isEmpty) {
            return const Center(child: Text('لا توجد عروض متاحة لك حالياً'));
          }

          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final data = orders[index].data() as Map<String, dynamic>;
              final status =
                  (data['orderStatus'] ?? data['status'] ?? '').toString();
              final unifiedOrderCode = formatUnifiedOrderCode(
                orderNumber: data['orderNumber'],
                orderId: data['orderId'],
                docId: orders[index].id,
              );

              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text('طلب $unifiedOrderCode'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('العميل: ${data['clientName'] ?? 'غير معروف'}'),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: OrderStatusPalette.backgroundForStatus(status),
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
                    ],
                  ),
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
