import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';

class CourierEarningsScreen extends StatefulWidget {
  final String driverId;

  const CourierEarningsScreen({Key? key, required this.driverId}) : super(key: key);

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

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final status = (data['orderStatus'] ?? data['status'] ?? '').toString();
      if (status != 'delivered' && status != 'تم التوصيل') continue;
      final deliveryFee = (data['deliveryFeeForDriver'] ?? 0).toDouble();
      earnings += deliveryFee;
      orders++;
    }

    setState(() {
      totalEarnings = earnings;
      totalOrders = orders;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeArabic.clientBackground,
      appBar: AppBar(
        title: const Text('أرباحي', style: TextStyle(color: AppThemeArabic.clientPrimary, fontWeight: FontWeight.bold, fontSize: 20, fontFamily: 'Tajawal')),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 1,
        iconTheme: const IconThemeData(color: AppThemeArabic.clientPrimary),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
        ),
      ),
      body: isLoading
          ? const Center(child: GFLoader(type: GFLoaderType.circle))
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  GFCard(
                    elevation: 8,
                    color: AppThemeArabic.clientSurface,
                    padding: const EdgeInsets.all(24),
                    borderRadius: BorderRadius.circular(16),
                    content: Column(
                      children: [
                        const Text(
                          'مجموع الأرباح',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${totalEarnings.toStringAsFixed(2)} ج.س',
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                        const SizedBox(height: 24),
                        const Divider(thickness: 1),
                        const SizedBox(height: 16),
                        const Text(
                          'عدد الطلبات المنفذة',
                          style: TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$totalOrders طلب',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  GFButton(
                    onPressed: () {
                      _loadEarnings(); // 🔄 تحديث الأرباح بالضغط
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم تحديث البيانات')),
                      );
                    },
                    text: 'تحديث الأرباح',
                    color: AppThemeArabic.clientPrimary,
                    size: GFSize.LARGE,
                    fullWidthButton: true,
                    shape: GFButtonShape.pills,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
    );
  }
}
