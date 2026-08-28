import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'courier_ui.dart';

class CourierMapToClientScreen extends StatelessWidget {
  final double clientLat;
  final double clientLng;
  final String nextStepButtonText;
  final VoidCallback onNext;

  const CourierMapToClientScreen({
    super.key,
    required this.clientLat,
    required this.clientLng,
    required this.nextStepButtonText,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final location = LatLng(clientLat, clientLng);

    return Scaffold(
      appBar: buildCourierAppBar('الذهاب إلى العميل'),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: location, zoom: 15),
            markers: {
              Marker(markerId: const MarkerId('client'), position: location),
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
