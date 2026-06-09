import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:speedstar_core/speedstar_core.dart'
    show OrderStatusPalette, formatUnifiedOrderCode;

import 'courier_order_details_screen.dart';
import 'courier_ui.dart';

class CourierNewOrdersScreen extends StatelessWidget {
  final String driverId;

  const CourierNewOrdersScreen({super.key, required this.driverId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildCourierAppBar('العروض الجديدة'),
      body: CourierPageBackground(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .where('offerDriverIds', arrayContains: driverId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const CourierEmptyState(
                title: 'لا توجد عروض متاحة الآن',
                message: 'ستظهر هنا الطلبات الجديدة القريبة منك عند توفرها.',
                icon: Icons.local_shipping_outlined,
              );
            }

            final orders = snapshot.data!.docs.where((d) {
              final m = d.data() as Map<String, dynamic>;
              final status = (m['orderStatus'] ?? m['status'] ?? '').toString();
              return status == 'courier_offer_pending';
            }).toList();

            if (orders.isEmpty) {
              return const CourierEmptyState(
                title: 'لا توجد عروض متاحة الآن',
                message: 'كل العروض الحالية إما انتهت أو تم استلامها من مندوب آخر.',
                icon: Icons.hourglass_empty_rounded,
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                CourierHeroCard(
                  title: '${orders.length} عرض متاح',
                  subtitle: 'راجع التفاصيل بسرعة واقبل العرض المناسب قبل انتهاء المهلة.',
                  icon: Icons.notifications_active_rounded,
                ),
                const SizedBox(height: 16),
                ...orders.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status =
                      (data['orderStatus'] ?? data['status'] ?? '').toString();
                  final orderCode = formatUnifiedOrderCode(
                    orderNumber: data['orderNumber'],
                    orderId: data['orderId'],
                    docId: doc.id,
                  );
                  final restaurantName =
                      (data['restaurantName'] ?? 'غير معروف').toString();

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
                                  orderCode,
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
                          _OfferRow(
                            label: 'العميل',
                            value:
                                (data['clientName'] ?? 'غير معروف').toString(),
                          ),
                          const SizedBox(height: 8),
                          _OfferRow(
                            label: 'المطعم',
                            value: restaurantName,
                          ),
                          const SizedBox(height: 8),
                          _OfferRow(
                            label: 'الإجمالي',
                            value: '${data['totalWithDelivery'] ?? data['total'] ?? 0} ج.س',
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CourierOrderDetailsScreen(
                                      orderId: doc.id,
                                      driverId: driverId,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.visibility_outlined),
                              label: const Text('عرض التفاصيل'),
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

class _OfferRow extends StatelessWidget {
  const _OfferRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF7A6857),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
