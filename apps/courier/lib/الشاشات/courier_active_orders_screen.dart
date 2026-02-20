import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'courier_order_details_screen.dart';

class CourierActiveOrdersScreen extends StatelessWidget {
  final String driverId;

  const CourierActiveOrdersScreen({Key? key, required this.driverId}) : super(key: key);

  // الحالات المطلوبة للعرض
  static const List<String> validStatuses = [
    'جاهز للتوصيل',
    'وصل إلى المطعم',
    'قيد التوصيل',
    'وصل إلى العميل',
    'طلبك قد وصل',
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('assignedDriverId', isEqualTo: driverId)
          .where('status', whereIn: validStatuses)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: GFLoader(type: GFLoaderType.circle));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('لا توجد طلبات نشطة حالياً.'));
        }

        final orders = snapshot.data!.docs;

        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final doc = orders[index];
            final data = doc.data() as Map<String, dynamic>;
            final orderId = doc.id;
            final status = data['status'] ?? '';

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: GFCard(
                elevation: 5,
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
                      color: GFColors.SECONDARY,
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
      case 'جاهز للتوصيل':
        buttonText = 'اذهب إلى موقع المطعم';
        newStatus = 'وصل إلى المطعم';
        break;
      case 'وصل إلى المطعم':
        buttonText = 'وصلت إلى المطعم';
        newStatus = 'قيد التوصيل';
        break;
      case 'قيد التوصيل':
        buttonText = 'اذهب إلى موقع العميل';
        newStatus = 'وصل إلى العميل';
        break;
      case 'وصل إلى العميل':
        buttonText = 'وصلت إلى العميل';
        newStatus = 'طلبك قد وصل';
        break;
      case 'طلبك قد وصل':
        buttonText = 'تم التوصيل';
        newStatus = 'تم التوصيل';
        break;
    }

    if (buttonText == null || newStatus == null) return const SizedBox();

    return GFButton(
      onPressed: () async {
        await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
          'status': newStatus,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ تم تحديث حالة الطلب إلى "$newStatus"')),
        );
      },
      text: buttonText,
      icon: const Icon(Icons.check_circle),
      color: GFColors.SUCCESS,
      fullWidthButton: true,
      size: GFSize.LARGE,
      shape: GFButtonShape.pills,
    );
  }
}
