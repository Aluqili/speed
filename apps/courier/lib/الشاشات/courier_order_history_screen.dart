import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CourierOrderHistoryScreen extends StatelessWidget {
  final String driverId;

  const CourierOrderHistoryScreen({Key? key, required this.driverId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل الطلبات', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFE724C), fontFamily: 'Tajawal', fontSize: 20)),
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFFFE724C)),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
        ),
      ),
      backgroundColor: const Color(0xFFF5F5F5),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('assignedDriverId', isEqualTo: driverId)
            .where('status', isEqualTo: 'تم التوصيل')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: GFLoader(type: GFLoaderType.circle));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('لا توجد طلبات مكتملة في السجل.', style: TextStyle(fontSize: 16)),
            );
          }

          final orders = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final data = orders[index].data() as Map<String, dynamic>;
              final orderId = orders[index].id;
              final restaurantName = data['restaurantName'] ?? 'غير معروف';
              final time = data.containsKey('deliveredAt')
                  ? _formatTimestamp(data['deliveredAt'])
                  : 'غير معروف';

              return GFCard(
                elevation: 5,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                title: GFListTile(
                  titleText: 'رقم الطلب: $orderId',
                  subTitleText: 'اسم المطعم: $restaurantName\nوقت التوصيل: $time',
                  icon: const Icon(Icons.arrow_forward_ios, size: 20),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      builder: (_) => Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            const Text('تفاصيل الطلب',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Text('اسم العميل: ${data['clientName'] ?? 'غير متوفر'}'),
                            const SizedBox(height: 4),
                            Text('رقم الجوال: ${data['clientPhone'] ?? 'غير متاح'}'),
                            const SizedBox(height: 8),
                            const Divider(),
                            Text('الإجمالي: ${data['total'] ?? 0} ج.س'),
                            Text('رسوم التوصيل: ${data['deliveryFee'] ?? 0} ج.س'),
                            const SizedBox(height: 8),
                            const Text('📦 الأصناف:', style: TextStyle(fontWeight: FontWeight.bold)),
                            ...((data['items'] ?? []) as List<dynamic>).map((item) {
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (item['imageUrl'] != null && item['imageUrl'].toString().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8.0),
                                      child: Image.network(
                                        item['imageUrl'],
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  Text('- ${item['name']} × ${item['quantity']}'),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  String? _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is Timestamp) {
      final dt = timestamp.toDate();
      return '${dt.day}/${dt.month}/${dt.year} - ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return null;
  }
}
