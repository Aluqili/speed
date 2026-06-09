import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';

import 'courier_confirm_delivery_screen.dart';

class CourierOrderActions extends StatelessWidget {
  final String orderId;
  const CourierOrderActions({super.key, required this.orderId});

  static Future<void> _driverGoToClient(String orderId, String driverId) async {
    await FirebaseFunctions.instanceFor(region: 'me-central1')
        .httpsCallable('courierUpdateOrderStage')
        .call({
      'orderId': orderId,
      'driverId': driverId,
      'stage': 'picked_up',
    });
  }

  Future<String?> _assignedDriverId() async {
    final doc =
        await FirebaseFirestore.instance.collection('orders').doc(orderId).get();
    final data = doc.data() ?? <String, dynamic>{};
    final assignedDriverId = (data['assignedDriverId'] ?? '').toString().trim();
    return assignedDriverId.isEmpty ? null : assignedDriverId;
  }

  Future<String?> _currentDriverId() async {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('إجراءات المندوب', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            GFButton(
              onPressed: () async {
                try {
                  final driverId =
                      await _assignedDriverId() ?? await _currentDriverId();
                  if (driverId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('يجب تسجيل الدخول كمندوب')),
                    );
                    return;
                  }
                  await _driverGoToClient(orderId, driverId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('المندوب في الطريق إلى العميل')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('فشل التحديث: $e')),
                    );
                  }
                }
              },
              text: 'الذهاب إلى العميل',
              color: AppThemeArabic.clientPrimary,
            ),
            const SizedBox(height: 8),
            GFButton(
              onPressed: () async {
                try {
                  final driverId =
                      await _assignedDriverId() ?? await _currentDriverId();
                  if (driverId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('يجب تسجيل الدخول كمندوب')),
                    );
                    return;
                  }
                  if (!context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CourierConfirmDeliveryScreen(
                        orderId: orderId,
                        driverId: driverId,
                      ),
                    ),
                  );
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('تعذر فتح إثبات التسليم: $e')),
                    );
                  }
                }
              },
              text: 'تم التسليم',
              color: AppThemeArabic.clientSuccess,
            ),
          ],
        ),
      ),
    );
  }
}
