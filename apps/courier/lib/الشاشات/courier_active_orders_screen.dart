import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';
import 'courier_order_details_screen.dart';

class CourierActiveOrdersScreen extends StatelessWidget {
  final String driverId;

  const CourierActiveOrdersScreen({Key? key, required this.driverId}) : super(key: key);

  // الحالات المطلوبة للعرض
  static const List<String> validStatuses = [
    'courier_assigned',
    'pickup_ready',
    'picked_up',
    'arrived_to_client',
    'جاهز للتوصيل',
    'قيد التوصيل',
    'وصل إلى العميل',
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('assignedDriverId', isEqualTo: driverId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: GFLoader(type: GFLoaderType.circle));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('لا توجد طلبات نشطة حالياً.'));
        }

        final orders = snapshot.data!.docs.where((d) {
          final m = d.data() as Map<String, dynamic>;
          final status = (m['orderStatus'] ?? m['status'] ?? '').toString();
          return validStatuses.contains(status);
        }).toList();

        if (orders.isEmpty) {
          return const Center(child: Text('لا توجد طلبات نشطة حالياً.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final doc = orders[index];
            final data = doc.data() as Map<String, dynamic>;
            final orderId = doc.id;
            final status = (data['orderStatus'] ?? data['status'] ?? '').toString();

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: GFCard(
                elevation: 5,
                color: AppThemeArabic.clientSurface,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('رقم الطلب: ${data['orderId'] ?? orderId}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text('العميل: ${data['clientName'] ?? 'غير معروف'}'),
                    const SizedBox(height: 6),
                    Text('الإجمالي: ${data['total'] ?? 0} ج.س'),
                    const SizedBox(height: 12),

                    // زر الإجراءات بناءً على الحالة
                    _buildActionButton(context, status, orderId),

                    const SizedBox(height: 8),
                    GFButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CourierOrderDetailsScreen(
                              orderId: orderId,
                              driverId: driverId,
                            ),
                          ),
                        );
                      },
                      text: 'عرض تفاصيل الطلب',
                      icon: const Icon(Icons.description),
                      color: AppThemeArabic.clientPrimary,
                      fullWidthButton: true,
                      size: GFSize.MEDIUM,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActionButton(BuildContext context, String status, String orderId) {
    String? buttonText;
    String? newStatus;

    switch (status) {
      case 'courier_assigned':
      case 'pickup_ready':
      case 'جاهز للتوصيل':
        buttonText = 'تم الاستلام من المطعم';
        newStatus = 'picked_up';
        break;
      case 'picked_up':
      case 'قيد التوصيل':
        buttonText = 'وصلت إلى العميل';
        newStatus = 'arrived_to_client';
        break;
      case 'arrived_to_client':
      case 'وصل إلى العميل':
        buttonText = 'وصلت إلى العميل';
        newStatus = 'delivered';
        break;
    }

    if (buttonText == null || newStatus == null) return const SizedBox();

    return GFButton(
      onPressed: () async {
        await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
          'orderStatus': newStatus,
          'status': newStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ تم تحديث حالة الطلب إلى "$newStatus"')),
        );
      },
      text: buttonText,
      icon: const Icon(Icons.check_circle),
      color: AppThemeArabic.clientPrimary,
      fullWidthButton: true,
      size: GFSize.LARGE,
      shape: GFButtonShape.pills,
    );
  }
}
