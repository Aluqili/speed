import 'package:flutter/material.dart';

class CourierOrderProcessScreen extends StatelessWidget {
  final String orderId;
  final String stage;
  const CourierOrderProcessScreen({Key? key, required this.orderId, required this.stage}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('معالجة الطلب')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('طلب رقم: $orderId', style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 16),
            Text('المرحلة الحالية: $stage', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                // هنا يمكن إضافة منطق تغيير حالة الطلب أو تحديثه
                Navigator.pop(context);
              },
              child: const Text('إنهاء الطلب / العودة'),
            ),
          ],
        ),
      ),
    );
  }
}
