import 'dart:async';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RouteEstimate {
  const RouteEstimate({
    required this.distanceKm,
    required this.durationMinutes,
    required this.isRoadRoute,
    this.encodedPolyline = '',
  });

  final double distanceKm;
  final int durationMinutes;
  final bool isRoadRoute;
  final String encodedPolyline;

  List<LatLng> get polylinePoints =>
      RouteEstimateService._decodePolyline(encodedPolyline);
}

class RouteEstimateService {
  static final _functions =
      FirebaseFunctions.instanceFor(region: 'me-central1');
  static final Map<String, RouteEstimate> _cache = {};

  static Future<RouteEstimate> estimate({
    required LatLng origin,
    required LatLng destination,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final key = _cacheKey(origin, destination);
    final cached = _cache[key];
    if (cached != null) return cached;

    try {
      final callable = _functions.httpsCallable('estimateRoute');
      final result = await callable.call({
        'origin': {'lat': origin.latitude, 'lng': origin.longitude},
        'destination': {
          'lat': destination.latitude,
          'lng': destination.longitude,
        },
      }).timeout(timeout);

      final data = Map<String, dynamic>.from(result.data as Map);
      final estimate = RouteEstimate(
        distanceKm: ((data['distanceKm'] ?? 0) as num).toDouble(),
        durationMinutes: ((data['durationMinutes'] ?? 1) as num).ceil(),
        isRoadRoute: data['isRoadRoute'] == true,
        encodedPolyline: (data['encodedPolyline'] ?? '').toString(),
      );
      _cache[key] = estimate;
      return estimate;
    } catch (_) {
      final fallbackDistance = _haversineKm(origin, destination);
      return RouteEstimate(
        distanceKm: fallbackDistance,
        durationMinutes: max(1, (fallbackDistance / 25 * 60).ceil()),
        isRoadRoute: false,
      );
    }
  }

  static String _cacheKey(LatLng a, LatLng b) {
    String r(double v) => v.toStringAsFixed(4);
    return '${r(a.latitude)},${r(a.longitude)}:${r(b.latitude)},${r(b.longitude)}';
  }

  static double _haversineKm(LatLng a, LatLng b) {
    double toRad(double deg) => deg * pi / 180;
    final dLat = toRad(b.latitude - a.latitude);
    final dLng = toRad(b.longitude - a.longitude);
    final x = pow(sin(dLat / 2), 2) +
        cos(toRad(a.latitude)) * cos(toRad(b.latitude)) * pow(sin(dLng / 2), 2);
    return 2 * asin(sqrt(x)) * 6371;
  }

  static List<LatLng> _decodePolyline(String encoded) {
    if (encoded.isEmpty) return const [];
    final points = <LatLng>[];
    var index = 0;
    var lat = 0;
    var lng = 0;

    while (index < encoded.length) {
      var shift = 0;
      var result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20 && index < encoded.length);
      lat += (result & 1) != 0 ? ~(result >> 1) : result >> 1;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20 && index < encoded.length);
      lng += (result & 1) != 0 ? ~(result >> 1) : result >> 1;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }
}
