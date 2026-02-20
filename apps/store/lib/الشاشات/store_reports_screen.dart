import 'package:flutter/material.dart';

class StoreReportsScreen extends StatelessWidget {
  final String restaurantId;
  const StoreReportsScreen({Key? key, required this.restaurantId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير والإحصائيات'),
        centerTitle: true,
      ),
      body: Center(
        child: Text('شاشة التقارير قيد التطوير', style: TextStyle(fontSize: 18)),
      ),
    );
  }
}
