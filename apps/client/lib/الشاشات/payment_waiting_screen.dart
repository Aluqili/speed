// lib/screens/payment_waiting_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:getwidget/getwidget.dart';

import 'client_order_details_screen.dart';

class PaymentWaitingScreen extends StatelessWidget {
  final String orderId;
  const PaymentWaitingScreen({Key? key, required this.orderId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final orderRef = FirebaseFirestore.instance.collection('orders').doc(orderId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('بانتظار موافقة الأدمن'),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: orderRef.snapshots(),
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Center(child: GFLoader(type: GFLoaderType.circle));
          }
          final data = snap.data!.data() as Map<String, dynamic>;
          final status = (data['status'] as String?)?.toLowerCase() ?? '';

          if (status == 'paid') {
            // الأدمن وافق: انتقل لتفاصيل الطلب
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => ClientOrderDetailsScreen(orderId: orderId),
                ),
              );
            });
            return const SizedBox.shrink();
          }

          // غير ذلك، نبقى في وضع الانتظار
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                GFLoader(type: GFLoaderType.circle),
                SizedBox(height: 16),
                Text(
                  'في انتظار موافقة الأدمن على إيصال الدفع...\nسيتم التحديث تلقائيًا.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
