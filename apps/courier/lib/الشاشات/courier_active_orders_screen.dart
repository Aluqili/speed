import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:speedstar_core/speedstar_core.dart'
    show OrderStatusPalette, formatUnifiedOrderCode;

import 'courier_client_contact_card.dart';
import 'courier_confirm_delivery_screen.dart';
import 'courier_order_details_screen.dart';
import 'courier_ui.dart';

class CourierActiveOrdersScreen extends StatelessWidget {
  final String driverId;

  const CourierActiveOrdersScreen({super.key, required this.driverId});

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
    return Scaffold(
      appBar: buildCourierAppBar('الطلبات النشطة'),
      body: CourierPageBackground(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .where('assignedDriverId', isEqualTo: driverId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final orders = (snapshot.data?.docs ?? []).where((d) {
              final m = d.data() as Map<String, dynamic>;
              final status = (m['orderStatus'] ?? m['status'] ?? '').toString();
              return validStatuses.contains(status);
            }).toList();

            if (orders.isEmpty) {
              return const CourierEmptyState(
                title: 'لا توجد طلبات نشطة',
                message: 'عند تعيين طلب جديد لك سيظهر هنا مع إجراءات التنفيذ.',
                icon: Icons.inbox_outlined,
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                CourierHeroCard(
                  title: '${orders.length} طلب جاري',
                  subtitle:
                      'تابع الرحلات الحالية وحدث حالتها بسرعة من هذه الشاشة.',
                  icon: Icons.route_rounded,
                ),
                const SizedBox(height: 16),
                ...orders.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final orderId = doc.id;
                  final status =
                      (data['orderStatus'] ?? data['status'] ?? '').toString();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: CourierSectionCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  formatUnifiedOrderCode(
                                    orderNumber: data['orderNumber'],
                                    orderId: data['orderId'],
                                    docId: orderId,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: OrderStatusPalette.backgroundForStatus(
                                      status),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  OrderStatusPalette.displayText(status),
                                  style: TextStyle(
                                    color: OrderStatusPalette.colorForStatus(
                                        status),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'العميل: ${data['clientName'] ?? 'غير معروف'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          CourierClientContactCard(
                            orderData: data,
                            driverId: driverId,
                            compact: true,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'الإجمالي: ${data['total'] ?? 0} ج.س',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 14),
                          _buildActionButton(context, status, orderId, driverId),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
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
                            icon: const Icon(Icons.description_outlined),
                            label: const Text('عرض تفاصيل الطلب'),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String status,
    String orderId,
    String driverId,
  ) {
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
        buttonText = 'تأكيد التسليم';
        newStatus = 'delivered';
        break;
    }

    if (buttonText == null || newStatus == null) return const SizedBox();

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          if (newStatus == 'delivered') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CourierConfirmDeliveryScreen(
                  orderId: orderId,
                  driverId: driverId,
                ),
              ),
            );
            return;
          }

          await FirebaseFunctions.instanceFor(region: 'me-central1')
              .httpsCallable('courierUpdateOrderStage')
              .call({
            'orderId': orderId,
            'driverId': driverId,
            'stage': newStatus,
          });

          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم تحديث حالة الطلب إلى "$newStatus"')),
          );
        },
        icon: const Icon(Icons.check_circle_rounded),
        label: Text(buttonText),
      ),
    );
  }
}
