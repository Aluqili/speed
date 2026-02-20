import 'package:flutter/material.dart';

class StoreOrdersHistoryScreen extends StatelessWidget {
  final String restaurantId;
  const StoreOrdersHistoryScreen({Key? key, required this.restaurantId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل الطلبات'),
        centerTitle: true,
      ),
      body: Center(
        child: Text('شاشة سجل الطلبات قيد التطوير', style: TextStyle(fontSize: 18)),
      ),
    );
  }
}
