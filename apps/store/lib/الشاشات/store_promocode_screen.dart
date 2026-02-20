import 'package:flutter/material.dart';

class StorePromocodeScreen extends StatelessWidget {
  final String restaurantId;
  const StorePromocodeScreen({Key? key, required this.restaurantId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة رموز المطعم'),
        centerTitle: true,
      ),
      body: Center(
        child: Text('شاشة إدارة رموز المطعم قيد التطوير', style: TextStyle(fontSize: 18)),
      ),
    );
  }
}
