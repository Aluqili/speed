import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'courier_ui.dart';

class CourierMapToRestaurantScreen extends StatelessWidget {
  final double restaurantLat;
  final double restaurantLng;
  final String nextStepButtonText;
  final VoidCallback onNext;

  const CourierMapToRestaurantScreen({
    super.key,
    required this.restaurantLat,
    required this.restaurantLng,
    required this.nextStepButtonText,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final location = LatLng(restaurantLat, restaurantLng);

    return Scaffold(
      appBar: buildCourierAppBar('الذهاب إلى المطعم'),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: location, zoom: 15),
            markers: {
              Marker(
                markerId: const MarkerId('restaurant'),
                position: location,
              ),
            },
            zoomControlsEnabled: false,
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: SafeArea(
              top: false,
              child: CourierSectionCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      onPressed: onNext,
                      icon: const Icon(Icons.directions_walk_rounded),
                      label: Text(nextStepButtonText),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
