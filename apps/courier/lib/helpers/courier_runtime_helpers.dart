import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';

class CourierMarkerIcons {
  const CourierMarkerIcons({
    required this.restaurant,
    required this.client,
    required this.driver,
  });

  final BitmapDescriptor restaurant;
  final BitmapDescriptor client;
  final BitmapDescriptor driver;
}

Future<CourierMarkerIcons>? _courierMarkerIconsFuture;

double courierToDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String courierFormatMoney(num value) {
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
}

String courierFormatDistance(double? km) {
  if (km == null || !km.isFinite) return 'غير متاح';
  if (km < 1) return '${(km * 1000).round()} م';
  return '${km.toStringAsFixed(1)} كم';
}

double courierHaversineKm(LatLng from, LatLng to) {
  const earthRadiusKm = 6371.0;
  final dLat = _deg2rad(to.latitude - from.latitude);
  final dLng = _deg2rad(to.longitude - from.longitude);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_deg2rad(from.latitude)) *
          math.cos(_deg2rad(to.latitude)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusKm * c;
}

double _deg2rad(double deg) => deg * (math.pi / 180);

Set<Marker> buildCourierTripMarkers({
  LatLng? restaurantLocation,
  LatLng? clientLocation,
  LatLng? driverLocation,
  bool showDriverMarker = false,
  CourierMarkerIcons? icons,
}) {
  return {
    if (restaurantLocation != null)
      Marker(
        markerId: const MarkerId('restaurant'),
        position: restaurantLocation,
        infoWindow: const InfoWindow(title: 'المطعم'),
        icon: icons?.restaurant ??
            BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueOrange,
            ),
      ),
    if (clientLocation != null)
      Marker(
        markerId: const MarkerId('client'),
        position: clientLocation,
        infoWindow: const InfoWindow(title: 'العميل'),
        icon: icons?.client ??
            BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRose,
            ),
      ),
    if (showDriverMarker && driverLocation != null)
      Marker(
        markerId: const MarkerId('driver'),
        position: driverLocation,
        infoWindow: const InfoWindow(title: 'موقع المندوب'),
        icon: icons?.driver ??
            BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure,
            ),
      ),
  };
}

Future<CourierMarkerIcons> loadCourierMarkerIcons() {
  return _courierMarkerIconsFuture ??= _createCourierMarkerIcons();
}

Future<CourierMarkerIcons> _createCourierMarkerIcons() async {
  return CourierMarkerIcons(
    restaurant: await _buildCourierMarkerIcon(
      icon: Icons.storefront_rounded,
      backgroundColor: AppThemeArabic.courierPrimary,
    ),
    client: await _buildCourierMarkerIcon(
      icon: Icons.person_rounded,
      backgroundColor: AppThemeArabic.courierAccent,
    ),
    driver: await _buildCourierMarkerIcon(
      icon: Icons.navigation_rounded,
      backgroundColor: const Color(0xFF1D4ED8),
    ),
  );
}

Future<BitmapDescriptor> _buildCourierMarkerIcon({
  required IconData icon,
  required Color backgroundColor,
  Color iconColor = Colors.white,
}) async {
  const size = 124.0;
  const iconSize = 56.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final center = Offset(size / 2, size / 2);

  final shadowPaint = Paint()
    ..color = Colors.black.withValues(alpha: 0.14)
    ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 10);
  canvas.drawCircle(center.translate(0, 8), 34, shadowPaint);

  final outerPaint = Paint()..color = Colors.white;
  canvas.drawCircle(center, 34, outerPaint);

  final fillPaint = Paint()..color = backgroundColor;
  canvas.drawCircle(center, 28, fillPaint);

  final iconTextPainter = TextPainter(textDirection: TextDirection.ltr);
  iconTextPainter.text = TextSpan(
    text: String.fromCharCode(icon.codePoint),
    style: TextStyle(
      fontSize: iconSize,
      fontFamily: icon.fontFamily,
      package: icon.fontPackage,
      color: iconColor,
    ),
  );
  iconTextPainter.layout();
  iconTextPainter.paint(
    canvas,
    Offset(
      center.dx - (iconTextPainter.width / 2),
      center.dy - (iconTextPainter.height / 2),
    ),
  );

  final image = await recorder.endRecording().toImage(
        size.toInt(),
        size.toInt(),
      );
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  final bytes = byteData?.buffer.asUint8List() ?? Uint8List(0);
  return BitmapDescriptor.fromBytes(bytes);
}

String normalizeCourierPhone(String rawPhone) {
  const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
  const englishDigits = '0123456789';

  var normalized = rawPhone.trim();
  for (var index = 0; index < arabicDigits.length; index++) {
    normalized =
        normalized.replaceAll(arabicDigits[index], englishDigits[index]);
  }

  normalized = normalized.replaceAll(RegExp(r'[^0-9+]'), '');
  if (normalized.startsWith('00')) {
    normalized = '+${normalized.substring(2)}';
  }
  if (normalized.startsWith('249') && !normalized.startsWith('+249')) {
    normalized = '+$normalized';
  }
  if (normalized.startsWith('0') && normalized.length == 10) {
    normalized = '+249${normalized.substring(1)}';
  }
  if (!normalized.startsWith('+') && normalized.length == 9) {
    normalized = '+249$normalized';
  }

  return normalized;
}

Future<bool> launchCourierPhoneCall(
  BuildContext context,
  String rawPhone,
) async {
  final normalized = normalizeCourierPhone(rawPhone);
  final rawDigits = rawPhone.replaceAll(RegExp(r'[^0-9+]'), '');
  final candidates = <String>{
    if (rawDigits.isNotEmpty) rawDigits,
    if (normalized.isNotEmpty) normalized,
    if (normalized.startsWith('+')) normalized.substring(1),
  };

  if (candidates.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('رقم الهاتف غير متوفر أو غير صالح')),
    );
    return false;
  }

  final schemes = ['tel', 'telprompt'];
  for (final candidate in candidates) {
    for (final scheme in schemes) {
      final uri = Uri(scheme: scheme, path: candidate);
      try {
        if (await launchUrl(uri,
            mode: LaunchMode.externalNonBrowserApplication)) {
          return true;
        }
      } catch (_) {}
      try {
        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          return true;
        }
      } catch (_) {}
    }
  }

  if (!context.mounted) return false;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: AppThemeArabic.courierTextPrimary,
      content: const Text('تعذر فتح الاتصال من هذا الجهاز أو الرقم غير مدعوم'),
    ),
  );
  return false;
}
