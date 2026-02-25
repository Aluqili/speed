import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:getwidget/getwidget.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';

class ClientOrderTrackingScreen extends StatefulWidget {
  final String orderId;
  const ClientOrderTrackingScreen({Key? key, required this.orderId}) : super(key: key);

  @override
  State<ClientOrderTrackingScreen> createState() => _ClientOrderTrackingScreenState();
}

class _ClientOrderTrackingScreenState extends State<ClientOrderTrackingScreen> {
  StreamSubscription<DocumentSnapshot>? _orderSub;
  StreamSubscription<DocumentSnapshot>? _driverSub;
  LatLng? _clientLocation;
  LatLng? _driverLocation;
  String? _driverName;
  bool _hasNotifiedArrival = false;
  GoogleMapController? _mapController;

  static const Color primaryColor = AppThemeArabic.clientPrimary;
  static const Color backgroundColor = AppThemeArabic.clientBackground;

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _listenToOrder();
  }

  Future<void> _initNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _notificationsPlugin.initialize(
      settings: const InitializationSettings(android: android),
    );
  }

  void _listenToOrder() {
    final ref = FirebaseFirestore.instance.collection('orders').doc(widget.orderId);

    _orderSub = ref.snapshots().listen((snap) {
      final data = snap.data();
      if (data == null) return;

      final rawStatus = ((data['orderStatus'] ?? data['status']) as String? ?? '').trim();
      final orderStatus = _normalizeStatus(rawStatus);

      if (orderStatus == 'delivered' && !_hasNotifiedArrival) {
        _hasNotifiedArrival = true;
        _showArrivalNotification();
      }

      final clientLoc = data['clientLocation'];
      if (clientLoc is GeoPoint) {
        _clientLocation = LatLng(clientLoc.latitude, clientLoc.longitude);
      }

      final driverId = data['assignedDriverId'];
      if ((orderStatus == 'picked_up' || orderStatus == 'arrived_to_client') && driverId != null) {
        _driverSub?.cancel();
        _driverSub = FirebaseFirestore.instance
            .collection('drivers')
            .doc(driverId)
            .snapshots()
            .listen((dSnap) {
          final dData = dSnap.data();
          if (dData != null) {
            _driverName = dData['name'];
            final currentLocation = dData['currentLocation'];
            final location = dData['location'];
            if (currentLocation is Map &&
                currentLocation['lat'] != null &&
                currentLocation['lng'] != null) {
              _driverLocation = LatLng(
                (currentLocation['lat'] as num).toDouble(),
                (currentLocation['lng'] as num).toDouble(),
              );
            } else if (location is GeoPoint) {
              _driverLocation = LatLng(location.latitude, location.longitude);

              if (_mapController != null) {
                _mapController!.animateCamera(CameraUpdate.newLatLng(_driverLocation!));
              }
            }
          }
          setState(() {});
        });
      }

      setState(() {});
    });
  }

  Future<void> _showArrivalNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'arrival_channel',
      'إشعارات الوصول',
      channelDescription: 'تنبيهات وصول الطلبات لدى العميل',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );
    await _notificationsPlugin.show(
      id: 0,
      title: '📦 وصل طلبك',
      body: 'تم توصيل طلبك بنجاح.',
      notificationDetails: const NotificationDetails(android: androidDetails),
    );
  }

  @override
  void dispose() {
    _orderSub?.cancel();
    _driverSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _ClientOrderTrackingScreenState.backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          centerTitle: true,
          title: const Text('تتبع الطلب', style: TextStyle(color: _ClientOrderTrackingScreenState.primaryColor, fontWeight: FontWeight.bold, fontSize: 20, fontFamily: 'Tajawal')),
          iconTheme: const IconThemeData(color: _ClientOrderTrackingScreenState.primaryColor),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
          ),
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .doc(widget.orderId)
              .snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: GFLoader(type: GFLoaderType.circle));
            }
            if (!snap.hasData || !snap.data!.exists) {
              return const Center(child: Text('لا توجد بيانات لهذا الطلب.'));
            }

            final data = snap.data!.data()! as Map<String, dynamic>;
            final rawStatus = ((data['orderStatus'] ?? data['status']) as String? ?? '').trim();
            final orderStatus = _normalizeStatus(rawStatus);
            final total = (data['totalWithDelivery'] as num?)?.toDouble() ?? 0.0;
            final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
            int currentStep = _statusSteps.indexOf(orderStatus);
            if (currentStep < 0) currentStep = 0;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if ((orderStatus == 'picked_up' || orderStatus == 'arrived_to_client') &&
                    _driverLocation != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_driverName != null)
                        Text('🚚 المندوب: $_driverName',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 250,
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: _driverLocation!,
                            zoom: 14,
                          ),
                          onMapCreated: (controller) => _mapController = controller,
                          markers: {
                            Marker(markerId: const MarkerId('driver'), position: _driverLocation!),
                            if (_clientLocation != null)
                              Marker(markerId: const MarkerId('client'), position: _clientLocation!),
                          },
                          polylines: {
                            if (_clientLocation != null)
                              Polyline(
                                polylineId: const PolylineId('route'),
                                points: [_driverLocation!, _clientLocation!],
                                width: 4,
                                color: primaryColor,
                              ),
                          },
                          gestureRecognizers: {
                            Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
                          },
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 16),
                Text('📦 رقم الطلب: ${widget.orderId}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 8),
                Text('💰 الإجمالي: ${total.toStringAsFixed(2)} ج.س'),
                const SizedBox(height: 16),

                Text('🔁 تقدم الطلب',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
                const SizedBox(height: 12),
                Column(
                  children: List.generate(_statusSteps.length, (i) {
                    final label = _statusStepText(_statusSteps[i]);
                    final done = i < currentStep;
                    final active = i == currentStep;
                    final color = done
                        ? Colors.green
                        : active
                            ? primaryColor
                            : Colors.grey;
                    final icon = done
                        ? Icons.check_circle
                        : active
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(children: [
                          Icon(icon, color: color),
                          const SizedBox(width: 12),
                          Text(label,
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                                  color: color)),
                        ]),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 24),
                Text('🍽️ الأصناف:', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...items.map((item) => ListTile(
                      leading: const Icon(Icons.restaurant_menu, color: primaryColor),
                      title: Text(item['name'] ?? ''),
                      subtitle: Text('x${item['quantity']} — ${item['price']} ج.س'),
                    )),
              ],
            );
          },
        ),
      ),
    );
  }
}

const List<String> _statusSteps = [
  'store_pending',
  'courier_searching',
  'courier_assigned',
  'picked_up',
  'arrived_to_client',
  'delivered',
  'cancelled',
];

String _normalizeStatus(String status) {
  switch (status) {
    case 'انتظار الدفع':
    case 'store_pending':
    case 'قيد المراجعة':
      return 'store_pending';
    case 'courier_searching':
    case 'قيد التجهيز':
      return 'courier_searching';
    case 'courier_offer_pending':
    case 'courier_assigned':
    case 'pickup_ready':
    case 'جاهز للتوصيل':
      return 'courier_assigned';
    case 'picked_up':
    case 'قيد التوصيل':
      return 'picked_up';
    case 'arrived_to_client':
    case 'وصل إلى العميل':
      return 'arrived_to_client';
    case 'delivered':
    case 'تم التوصيل':
      return 'delivered';
    case 'cancelled':
    case 'store_rejected':
    case 'ملغي':
      return 'cancelled';
    default:
      return 'store_pending';
  }
}

String _statusStepText(String status) {
  switch (status) {
    case 'store_pending':
      return 'قيد المراجعة';
    case 'courier_searching':
      return 'جاري البحث عن مندوب';
    case 'courier_assigned':
      return 'تم تعيين مندوب';
    case 'picked_up':
      return 'الطلب في الطريق';
    case 'arrived_to_client':
      return 'وصل المندوب للموقع';
    case 'delivered':
      return 'تم التوصيل';
    case 'cancelled':
      return 'ملغي';
    default:
      return status;
  }
}
