import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';

import 'courier_ui.dart';

class CourierEarningsScreen extends StatefulWidget {
  final String driverId;

  const CourierEarningsScreen({super.key, required this.driverId});

  @override
  State<CourierEarningsScreen> createState() => _CourierEarningsScreenState();
}

class _CourierEarningsScreenState extends State<CourierEarningsScreen> {
  double totalEarnings = 0;
  int totalOrders = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEarnings();
  }

  Future<void> _loadEarnings() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('orders')
        .where('assignedDriverId', isEqualTo: widget.driverId)
        .get();

    double earnings = 0;
    int orders = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final status = (data['orderStatus'] ?? data['status'] ?? '').toString();
      if (status != 'delivered' && status != 'تم التوصيل') continue;
      final feeSource = data['deliveryFeeForDriver'] ?? data['deliveryFee'] ?? 0;
      final deliveryFee = feeSource is num
          ? feeSource.toDouble()
          : double.tryParse(feeSource.toString()) ?? 0;
      earnings += deliveryFee;
      orders++;
    }

    if (!mounted) return;
    setState(() {
      totalEarnings = earnings;
      totalOrders = orders;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildCourierAppBar('أرباحي'),
      body: CourierPageBackground(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  CourierHeroCard(
                    title: '${totalEarnings.toStringAsFixed(2)} ج.س',
                    subtitle: 'إجمالي العائد من الطلبات المكتملة حتى الآن.',
                    icon: Icons.payments_rounded,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: CourierMetricCard(
                          label: 'طلبات مكتملة',
                          value: '$totalOrders',
                          icon: Icons.task_alt_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CourierMetricCard(
                          label: 'متوسط العائد',
                          value: totalOrders == 0
                              ? '0'
                              : (totalEarnings / totalOrders).toStringAsFixed(1),
                          icon: Icons.trending_up_rounded,
                          tone: AppThemeArabic.courierAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  CourierSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CourierSectionTitle(
                          title: 'ملخص الأداء',
                          subtitle:
                              'عرض سريع يساعدك على فهم نشاطك واتجاه أرباحك.',
                        ),
                        const SizedBox(height: 16),
                        _SummaryRow(
                          label: 'إجمالي الأرباح',
                          value: '${totalEarnings.toStringAsFixed(2)} ج.س',
                        ),
                        const SizedBox(height: 10),
                        _SummaryRow(
                          label: 'عدد الطلبات المنجزة',
                          value: '$totalOrders طلب',
                        ),
                        const SizedBox(height: 10),
                        _SummaryRow(
                          label: 'متوسط العائد لكل طلب',
                          value: totalOrders == 0
                              ? '0 ج.س'
                              : '${(totalEarnings / totalOrders).toStringAsFixed(2)} ج.س',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      setState(() => isLoading = true);
                      await _loadEarnings();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم تحديث بيانات الأرباح')),
                      );
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('تحديث الأرباح'),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppThemeArabic.courierTextSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: AppThemeArabic.courierTextPrimary,
          ),
        ),
      ],
    );
  }
}
