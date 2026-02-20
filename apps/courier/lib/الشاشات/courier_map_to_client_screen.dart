import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:getwidget/getwidget.dart';

class CourierMapToClientScreen extends StatelessWidget {
  final double clientLat;
  final double clientLng;
  final String nextStepButtonText;
  final VoidCallback onNext;

  const CourierMapToClientScreen({
    Key? key,
    required this.clientLat,
    required this.clientLng,
    required this.nextStepButtonText,
    required this.onNext,
  }) : super(key: key);

  void _openGoogleMaps() async {
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$clientLat,$clientLng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final LatLng location = LatLng(clientLat, clientLng);

    return Scaffold(
      appBar: GFAppBar(
        title: const Text('الذهاب إلى العميل'),
        backgroundColor: GFColors.PRIMARY,
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: location, zoom: 15),
              markers: {
                Marker(markerId: const MarkerId('client'), position: location),
              },
              zoomControlsEnabled: false,
            ),
          ),
          const SizedBox(height: 12),
          GFButton(
            onPressed: _openGoogleMaps,
            text: 'فتح الموقع في خرائط Google',
            icon: const Icon(Icons.map),
            color: GFColors.INFO,
            shape: GFButtonShape.pills,
            fullWidthButton: true,
          ),
          const SizedBox(height: 12),
          GFButton(
            onPressed: onNext,
            text: nextStepButtonText,
            icon: const Icon(Icons.directions_walk),
            color: GFColors.SUCCESS,
            shape: GFButtonShape.pills,
            fullWidthButton: true,
            size: GFSize.LARGE,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
