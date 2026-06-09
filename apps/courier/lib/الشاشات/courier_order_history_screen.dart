import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:speedstar_core/speedstar_core.dart'
    show OrderStatusPalette, formatUnifiedOrderCode;

import 'courier_ui.dart';

class CourierOrderHistoryScreen extends StatelessWidget {
  final String driverId;

  const CourierOrderHistoryScreen({super.key, required this.driverId});

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is! Timestamp) return 'غير معروف';
    final dt = timestamp.toDate();
    return '${dt.day}/${dt.month}/${dt.year} - ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildCourierAppBar('سجل الطلبات'),
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
              return status == 'delivered' || status == 'تم التوصيل';
            }).toList();

            if (orders.isEmpty) {
              return const CourierEmptyState(
                title: 'لا يوجد سجل مكتمل بعد',
                message: 'ستظهر هنا الطلبات التي أنهيتها بنجاح مع وقت التسليم.',
                icon: Icons.inventory_2_outlined,
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                CourierHeroCard(
                  title: '${orders.length} طلب مكتمل',
                  subtitle: 'راجع طلباتك السابقة ووقت الإنجاز لكل رحلة.',
                  icon: Icons.history_rounded,
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
                          _HistoryRow(
                            label: 'المطعم',
                            value: (data['restaurantName'] ?? 'غير معروف')
                                .toString(),
                          ),
                          const SizedBox(height: 8),
                          _HistoryRow(
                            label: 'العميل',
                            value:
                                (data['clientName'] ?? 'غير متوفر').toString(),
                          ),
                          const SizedBox(height: 8),
                          _HistoryRow(
                            label: 'وقت التسليم',
                            value: _formatTimestamp(data['deliveredAt']),
                          ),
                          const SizedBox(height: 8),
                          _HistoryRow(
                            label: 'الإجمالي',
                            value: '${data['total'] ?? 0} ج.س',
                          ),
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                showDragHandle: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => Directionality(
                                  textDirection: TextDirection.rtl,
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: CourierSectionCard(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const CourierSectionTitle(
                                            title: 'تفاصيل الطلب',
                                            subtitle:
                                                'بيانات أساسية للطلب الذي تم تسليمه.',
                                          ),
                                          const SizedBox(height: 16),
                                          _HistoryRow(
                                            label: 'العميل',
                                            value: (data['clientName'] ??
                                                    'غير متوفر')
                                                .toString(),
                                          ),
                                          const SizedBox(height: 8),
                                          _HistoryRow(
                                            label: 'الهاتف',
                                            value: (data['clientPhone'] ??
                                                    'غير متاح')
                                                .toString(),
                                          ),
                                          const SizedBox(height: 8),
                                          _HistoryRow(
                                            label: 'رسوم التوصيل',
                                            value:
                                                '${data['deliveryFee'] ?? 0} ج.س',
                                          ),
                                          const SizedBox(height: 12),
                                          const Text(
                                            'الأصناف',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          ...((data['items'] ?? [])
                                                  as List<dynamic>)
                                              .map(
                                            (item) => Padding(
                                              padding:
                                                  const EdgeInsets.only(bottom: 6),
                                              child: Text(
                                                '- ${item['name']} × ${item['quantity']}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.visibility_outlined),
                            label: const Text('عرض التفاصيل'),
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

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
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
          width: 92,
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
