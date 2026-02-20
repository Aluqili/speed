import 'package:flutter/material.dart';

import 'driver_main_screen.dart';

class CourierMainScreen extends StatelessWidget {
  final String courierId;

  const CourierMainScreen({super.key, required this.courierId});

  @override
  Widget build(BuildContext context) {
    return CourierDashboardScreen(driverId: courierId);
  }
}
