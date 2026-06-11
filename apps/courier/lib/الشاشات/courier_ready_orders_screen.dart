import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:speedstar_core/speedstar_core.dart'
    show OrderStatusPalette, formatUnifiedOrderCode;

import 'courier_client_contact_card.dart';
import 'courier_ui.dart';

class CourierReadyOrdersScreen extends StatelessWidget {
  final String driverId;

  const CourierReadyOrdersScreen({super.key, required this.driverId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildCourierAppBar('الطلبات الجاهزة'),
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

            final orders = (snapshot.data?.docs ?? []).where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final status =
                  (data['orderStatus'] ?? data['status'] ?? '').toString();
              return status == 'pickup_ready' || status == 'جاهز للتوصيل';
            }).toList();

            if (orders.isEmpty) {
              return const CourierEmptyState(
                title: 'لا توجد طلبات جاهزة',
                message:
                    'عند تجهيز الطلبات المخصصة لك في المطعم ستظهر هنا مباشرة.',
                icon: Icons.inventory_2_outlined,
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                CourierHeroCard(
                  title: '${orders.length} طلب جاهز',
                  subtitle: 'ابدأ الاستلام من المطعم ثم انتقل مباشرة لرحلة العميل.',
                  icon: Icons.storefront_rounded,
                ),
                const SizedBox(height: 16),
                ...orders.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
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
                                    docId: doc.id,
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
                            'العميل: ${data['clientName'] ?? 'غير متوفر'}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 10),
                          CourierClientContactCard(
                            orderData: data,
                            driverId: driverId,
                            compact: true,
                            showPhone: true,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'المبلغ: ${data['totalWithDelivery'] ?? 0} ج.س',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                try {
                                  await FirebaseFunctions.instanceFor(
                                          region: 'me-central1')
                                      .httpsCallable('courierUpdateOrderStage')
                                      .call({
                                    'orderId': doc.id,
                                    'driverId': driverId,
                                    'stage': 'picked_up',
                                  });
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('تم تسجيل استلام الطلب'),
                                    ),
                                  );
                                } catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('تعذر تحديث الطلب: $e'),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.delivery_dining_rounded),
                              label: const Text('تم استلام الطلب'),
                            ),
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
}
