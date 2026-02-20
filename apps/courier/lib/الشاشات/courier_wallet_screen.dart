import 'package:flutter/material.dart';

class CourierWalletScreen extends StatelessWidget {
  final String driverId;
  const CourierWalletScreen({Key? key, required this.driverId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('محفظة المندوب')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_balance_wallet, size: 80, color: Colors.amber),
            const SizedBox(height: 20),
            const Text('رصيدك الحالي: 0 ج.س', style: TextStyle(fontSize: 22)),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('رجوع'),
            ),
          ],
        ),
      ),
    );
  }
}
