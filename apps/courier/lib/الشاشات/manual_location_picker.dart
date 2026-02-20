import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ManualLocationPicker extends StatefulWidget {
  final LatLng initialLocation;
  const ManualLocationPicker({Key? key, required this.initialLocation}) : super(key: key);

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
      appBar: AppBar(title: const Text('تحديد الموقع يدويًا')),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _pickedLocation, zoom: 15),
            onTap: (latLng) {
              setState(() {
                _pickedLocation = latLng;
              });
            },
            markers: {
              Marker(
                markerId: const MarkerId('picked'),
                position: _pickedLocation,
                infoWindow: const InfoWindow(title: 'موقعك المختار'),
              ),
            },
          ),
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('تأكيد الموقع'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(context, _pickedLocation);
              },
            ),
          ),
        ],
      ),
    );
  }
}
