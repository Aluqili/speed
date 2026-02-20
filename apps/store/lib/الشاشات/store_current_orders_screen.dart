import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'store_order_details_screen.dart';

class StoreCurrentOrdersScreen extends StatelessWidget {
  final String restaurantId;
  const StoreCurrentOrdersScreen({super.key, required this.restaurantId});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('الطلبات الحالية')),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .where('restaurantId', isEqualTo: restaurantId)
              .where('status', whereIn: ['قيد المراجعة','قيد التجهيز','قيد التوصيل','بانتظار المطعم','انتظار الدفع'])
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Center(child: Text('لا توجد طلبات حالياً'));
            }
            return ListView.separated(
              itemCount: docs.length,
              separatorBuilder: (_, __) => const Divider(height: 0),
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final orderId = docs[index].id;
                final status = data['status'] ?? '—';
                final clientName = data['clientName'] ?? 'عميل';
                final total = data['total'] ?? 0;
                return ListTile(
                  title: Text('طلب $orderId — $clientName'),
                  subtitle: Text('الحالة: $status — الإجمالي: $total'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StoreOrderDetailsScreen(orderData: {
                          'docId': orderId,
                          ...data,
                        }),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
