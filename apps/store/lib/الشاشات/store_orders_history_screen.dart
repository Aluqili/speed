import 'package:flutter/material.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';

class StoreOrdersHistoryScreen extends StatelessWidget {
  final String restaurantId;
  const StoreOrdersHistoryScreen({Key? key, required this.restaurantId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeArabic.clientBackground,
      appBar: AppBar(
        title: const Text('سجل الطلبات'),
        centerTitle: true,
      ),
      body: Center(
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
          child: const Padding(
            padding: EdgeInsets.all(20),
            child: Text('شاشة سجل الطلبات قيد التطوير', style: TextStyle(fontSize: 18)),
          ),
        ),
      ),
    );
  }
}
