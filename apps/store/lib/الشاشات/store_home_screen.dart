import 'package:flutter/material.dart';

import 'restaurant_home_screen.dart';

class StoreHomeScreen extends StatelessWidget {
  final String storeId;

  const StoreHomeScreen({super.key, required this.storeId});

  @override
  Widget build(BuildContext context) {
    return StoreDashboardScreen(restaurantId: storeId);
  }
}
