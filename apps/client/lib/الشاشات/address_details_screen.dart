import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class AddressDetailsScreen extends StatelessWidget {
  final String addressName;
  final double latitude;
  final double longitude;

  const AddressDetailsScreen({
    Key? key,
    required this.addressName,
    required this.latitude,
    required this.longitude,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final LatLng addressLocation = LatLng(latitude, longitude);

    return Scaffold(
      appBar: AppBar(
        title: Text(addressName),
        backgroundColor: Colors.amber[400],
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: addressLocation,
                zoom: 16,
              ),
              markers: {
                Marker(
                  markerId: const MarkerId('selectedAddress'),
                  position: addressLocation,
                  infoWindow: InfoWindow(title: addressName),
                ),
              },
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('اسم العنوان: $addressName', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text('الإحداثيات:', style: TextStyle(fontSize: 16, color: Colors.grey[700])),
                const SizedBox(height: 5),
                Text('Latitude: $latitude', style: const TextStyle(fontSize: 16)),
                Text('Longitude: $longitude', style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
