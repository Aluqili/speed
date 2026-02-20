import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import '../services/order_service.dart';

class StoreOrderActions extends StatelessWidget {
  final String orderId;
  const StoreOrderActions({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('إجراءات المطعم', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            GFButton(
              onPressed: () async {
                try {
                  await OrderService.approveByRestaurant(orderId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم بدء التجهيز')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('فشل بدء التجهيز: $e')),
                    );
                  }
                }
              },
              text: 'بدء التجهيز',
              color: GFColors.PRIMARY,
            ),
          ],
        ),
      ),
    );
  }
}
