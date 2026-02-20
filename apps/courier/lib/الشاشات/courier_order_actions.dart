import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CourierOrderActions extends StatelessWidget {
  final String orderId;
  const CourierOrderActions({super.key, required this.orderId});

  static Future<void> _driverGoToClient(String orderId, String driverId) {
    return FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'assignedDriverId': driverId,
      'orderStatus': 'قيد التوصيل',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> _driverCompleteDelivery(String orderId) {
    return FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'orderStatus': 'تم التوصيل',
      'deliveredAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
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
                  final driverId = await _currentDriverId();
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
              color: GFColors.WARNING,
            ),
            const SizedBox(height: 8),
            GFButton(
              onPressed: () async {
                try {
                  await _driverCompleteDelivery(orderId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم تسليم الطلب')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('فشل التسليم: $e')),
                    );
                  }
                }
              },
              text: 'تم التسليم',
              color: GFColors.SUCCESS,
            ),
          ],
        ),
      ),
    );
  }
}
