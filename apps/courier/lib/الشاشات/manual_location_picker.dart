import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'courier_ui.dart';

class ManualLocationPicker extends StatefulWidget {
  final LatLng initialLocation;

  const ManualLocationPicker({super.key, required this.initialLocation});

  @override
  State<ManualLocationPicker> createState() => _ManualLocationPickerState();
}

class _ManualLocationPickerState extends State<ManualLocationPicker> {
  late LatLng _pickedLocation;

  @override
  void initState() {
    super.initState();
    _pickedLocation = widget.initialLocation;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildCourierAppBar('تحديد الموقع يدويًا'),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _pickedLocation,
              zoom: 15,
            ),
            onTap: (latLng) => setState(() => _pickedLocation = latLng),
            markers: {
              Marker(
                markerId: const MarkerId('picked'),
                position: _pickedLocation,
                infoWindow: const InfoWindow(title: 'موقعك المختار'),
              ),
            },
          ),
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: SafeArea(
              top: false,
              child: CourierSectionCard(
                padding: const EdgeInsets.all(12),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('تأكيد الموقع'),
                  onPressed: () => Navigator.pop(context, _pickedLocation),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
