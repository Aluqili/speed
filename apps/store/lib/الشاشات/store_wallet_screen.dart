import 'package:flutter/material.dart';

class StoreWalletScreen extends StatelessWidget {
  final String restaurantId;
  const StoreWalletScreen({Key? key, required this.restaurantId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('محفظة المطعم'),
        centerTitle: true,
      ),
      body: Center(
        child: Text('شاشة محفظة المطعم قيد التطوير', style: TextStyle(fontSize: 18)),
      ),
    );
  }
}
