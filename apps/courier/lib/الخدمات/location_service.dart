import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  LocationService._();

  static final LocationService instance = LocationService._();
  static const MethodChannel _nativeChannel =
      MethodChannel('speedstar_courier/location_service');

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _ordersSub;
  String? _driverId;
  String? _activeOrderId;
  double? _lastLat;
  double? _lastLng;
  DateTime? _lastWriteAt;
  static const double _minimumWriteDistanceMeters = 20;
  static const Duration _minimumWriteInterval = Duration(seconds: 20);

  static const Set<String> _activeStatuses = {
    'courier_assigned',
    'pickup_ready',
    'picked_up',
    'arrived_to_client',
    'جاهز للتوصيل',
    'قيد التوصيل',
    'وصل إلى العميل',
  };

  Future<void> startLocationUpdates(String driverId) async {
    final id = driverId.trim();
    if (id.isEmpty) return;

    if (_driverId == id && _positionSub != null) return;
    await stopLocationUpdates(stopNativeService: false);
    _driverId = id;

    final ok = await _ensureLocationPermission();
    if (!ok) return;

    _listenForActiveOrder(id);
    final usesNativeTracking = !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        await _startNativeForegroundService(id);

    try {
      final current = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!usesNativeTracking) {
        await _writePosition(current, force: true);
      }
    } catch (_) {
      // Stream updates will retry when a fix is available.
    }

    if (usesNativeTracking) return;

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
      ),
    ).listen((position) {
      unawaited(_writePosition(position));
    });
  }

  Future<bool> _startNativeForegroundService(String driverId) async {
    try {
      await _nativeChannel.invokeMethod('startForegroundTracking', {
        'driverId': driverId,
      });
      return true;
    } catch (_) {
      // Flutter stream remains active when the native service is unavailable.
      return false;
    }
  }

  void _listenForActiveOrder(String driverId) {
    _ordersSub?.cancel();
    _ordersSub = _firestore
        .collection('orders')
        .where('assignedDriverId', isEqualTo: driverId)
        .snapshots()
        .listen((snapshot) {
      final activeDocs = snapshot.docs.where((doc) {
        final data = doc.data();
        final status = (data['orderStatus'] ?? data['status'] ?? '').toString();
        return _activeStatuses.contains(status);
      }).toList()
        ..sort((a, b) {
          final aMs = _timestampMs(a.data()['acceptedAt']) ??
              _timestampMs(a.data()['updatedAt']) ??
              0;
          final bMs = _timestampMs(b.data()['acceptedAt']) ??
              _timestampMs(b.data()['updatedAt']) ??
              0;
          return bMs.compareTo(aMs);
        });

      _activeOrderId = activeDocs.isEmpty ? null : activeDocs.first.id;
    });
  }

  int? _timestampMs(dynamic value) {
    if (value is Timestamp) return value.toDate().millisecondsSinceEpoch;
    if (value is DateTime) return value.millisecondsSinceEpoch;
    if (value is int) return value;
    return null;
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<void> _writePosition(Position position, {bool force = false}) async {
    final id = _driverId;
    if (id == null || id.isEmpty) return;

    final lat = position.latitude;
    final lng = position.longitude;
    final now = DateTime.now();

    if (!force && _lastLat != null && _lastLng != null) {
      final movedMeters = Geolocator.distanceBetween(
        _lastLat!,
        _lastLng!,
        lat,
        lng,
      );
      final elapsedMs =
          now.difference(_lastWriteAt ?? DateTime(1970)).inMilliseconds;
      if (movedMeters < _minimumWriteDistanceMeters &&
          elapsedMs < _minimumWriteInterval.inMilliseconds) {
        return;
      }
    }

    final point = GeoPoint(lat, lng);
    final locationMap = {
      'lat': lat,
      'lng': lng,
      'latitude': lat,
      'longitude': lng,
      'accuracy': position.accuracy,
      'heading': position.heading,
      'speed': position.speed,
    };

    final driverPatch = {
      'location': point,
      'currentLocation': locationMap,
      'lastLocation': point,
      'latitude': lat,
      'longitude': lng,
      'lastLocationUpdate': FieldValue.serverTimestamp(),
      'lastUpdated': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _firestore.collection('drivers').doc(id).set(
          driverPatch,
          SetOptions(merge: true),
        );

    final orderId = _activeOrderId;
    if (orderId != null && orderId.isNotEmpty) {
      await _firestore.collection('orders').doc(orderId).set({
        'driverLocation': point,
        'driverCurrentLocation': locationMap,
        'driverLat': lat,
        'driverLng': lng,
        'driverLocationUpdatedAt': FieldValue.serverTimestamp(),
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    _lastLat = lat;
    _lastLng = lng;
    _lastWriteAt = now;
  }

  Future<void> stopLocationUpdates({bool stopNativeService = true}) async {
    await _positionSub?.cancel();
    await _ordersSub?.cancel();
    if (stopNativeService) {
      try {
        await _nativeChannel.invokeMethod('stopForegroundTracking');
      } catch (_) {}
    }
    _positionSub = null;
    _ordersSub = null;
    _driverId = null;
    _activeOrderId = null;
    _lastLat = null;
    _lastLng = null;
    _lastWriteAt = null;
  }
}
