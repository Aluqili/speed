import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:getwidget/getwidget.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'dart:math' as math;
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';
import 'package:speedstar_core/speedstar_core.dart' show formatUnifiedOrderCode;
import '../helpers/courier_runtime_helpers.dart';

import 'courier_client_contact_card.dart';
import 'courier_batch_trip_screen.dart';
import 'courier_go_to_client_screen.dart';
import 'courier_ui.dart';

class CourierGoToRestaurantScreen extends StatelessWidget {
  final String orderId;
  final String driverId;

  const CourierGoToRestaurantScreen({
    super.key,
    required this.orderId,
    required this.driverId,
  });

  void _fitCameraToPoints(GoogleMapController controller, List<LatLng> points) {
    if (points.isEmpty) return;
    if (points.length == 1) {
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: points.first, zoom: 15),
        ),
      );
      return;
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points.skip(1)) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80,
      ),
    );
  }

  List<Map<String, dynamic>> _batchStops(Map<String, dynamic> data) {
    return (data['batchStops'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  LatLng? _batchStopLocation(Map<String, dynamic> stop) {
    final lat = courierToDouble(stop['clientLat'] ?? stop['lat']);
    final lng = courierToDouble(stop['clientLng'] ?? stop['lng']);
    if (lat == 0 || lng == 0) return null;
    return LatLng(lat, lng);
  }

  Set<Marker> _buildBatchPickupMarkers({
    required LatLng pickupLocation,
    required List<Map<String, dynamic>> stops,
    required String pickupTitle,
  }) {
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('batch-pickup'),
        position: pickupLocation,
        infoWindow: InfoWindow(title: pickupTitle, snippet: 'نقطة الاستلام'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };
    for (var i = 0; i < stops.length; i += 1) {
      final location = _batchStopLocation(stops[i]);
      if (location == null) continue;
      markers.add(
        Marker(
          markerId: MarkerId('batch-client-$i'),
          position: location,
          infoWindow: InfoWindow(
            title: '${i + 1}. ${stops[i]['clientName'] ?? 'عميل'}',
            snippet: (stops[i]['zoneName'] ?? '').toString(),
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
    }
    return markers;
  }

  Future<bool> _confirmPickup(
    BuildContext context, {
    String pickupTitle = 'المطعم',
  }) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الاستلام'),
        content: Text('هل أنت متأكد أنك استلمت الطلب من $pickupTitle؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('تأكيد الاستلام'),
          ),
        ],
      ),
    );
    return approved == true;
  }

  Future<Map<String, dynamic>?> _fetchOrderData() async {
    final doc = await FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .get();
    if (!doc.exists) return null;

    final data = Map<String, dynamic>.from(doc.data()!);
    try {
      final restaurantId = (data['restaurantId'] ?? '').toString();
      final clientId = (data['clientId'] ?? '').toString();

      final hasRestaurantName =
          (data['restaurantName'] ?? '').toString().trim().isNotEmpty;
      final hasClientName =
          (data['clientName'] ?? '').toString().trim().isNotEmpty;
      final hasRestaurantLat = (data['restaurantLat'] as num?) != null;
      final hasRestaurantLng = (data['restaurantLng'] as num?) != null;
      final hasClientLat = (data['clientLat'] as num?) != null;
      final hasClientLng = (data['clientLng'] as num?) != null;

      if (clientId.isNotEmpty &&
          (!hasClientName || !hasClientLat || !hasClientLng)) {
        DocumentSnapshot<Map<String, dynamic>>? clientDoc;
        final directClientDoc = await FirebaseFirestore.instance
            .collection('clients')
            .doc(clientId)
            .get();
        if (directClientDoc.exists) {
          clientDoc = directClientDoc;
        } else {
          final byOwner = await FirebaseFirestore.instance
              .collection('clients')
              .where('ownerUid', isEqualTo: clientId)
              .limit(1)
              .get();
          if (byOwner.docs.isNotEmpty) {
            clientDoc = byOwner.docs.first;
          } else {
            final byUid = await FirebaseFirestore.instance
                .collection('clients')
                .where('uid', isEqualTo: clientId)
                .limit(1)
                .get();
            if (byUid.docs.isNotEmpty) {
              clientDoc = byUid.docs.first;
            } else {
              final byUserId = await FirebaseFirestore.instance
                  .collection('clients')
                  .where('userId', isEqualTo: clientId)
                  .limit(1)
                  .get();
              if (byUserId.docs.isNotEmpty) {
                clientDoc = byUserId.docs.first;
              }
            }
          }
        }

        if (clientDoc != null && clientDoc.exists) {
          final clientData = clientDoc.data() ?? <String, dynamic>{};
          if (!hasClientName) {
            final clientName =
                (clientData['name'] ?? clientData['fullName'] ?? '')
                    .toString()
                    .trim();
            if (clientName.isNotEmpty) {
              data['clientName'] = clientName;
            }
          }
          if ((data['clientPhone'] ?? '').toString().trim().isEmpty) {
            final clientPhone =
                (clientData['phone'] ?? clientData['phoneNumber'] ?? '')
                    .toString()
                    .trim();
            if (clientPhone.isNotEmpty) {
              data['clientPhone'] = clientPhone;
            }
          }

          if (!hasClientLat || !hasClientLng) {
            final loc = clientData['location'];
            if (loc is GeoPoint) {
              data['clientLat'] = loc.latitude;
              data['clientLng'] = loc.longitude;
            } else if (loc is Map<String, dynamic>) {
              final lat = (loc['lat'] as num?)?.toDouble() ??
                  (loc['latitude'] as num?)?.toDouble();
              final lng = (loc['lng'] as num?)?.toDouble() ??
                  (loc['longitude'] as num?)?.toDouble();
              if (lat != null && lng != null) {
                data['clientLat'] = lat;
                data['clientLng'] = lng;
              }
            }

            if ((data['clientLat'] as num?) == null ||
                (data['clientLng'] as num?) == null) {
              final defaultAddressId =
                  (clientData['defaultAddressId'] ?? '').toString().trim();
              if (defaultAddressId.isNotEmpty) {
                final addressDoc = await FirebaseFirestore.instance
                    .collection('clients')
                    .doc(clientDoc.id)
                    .collection('addresses')
                    .doc(defaultAddressId)
                    .get();
                if (addressDoc.exists) {
                  final addressData = addressDoc.data() ?? <String, dynamic>{};
                  final lat = (addressData['latitude'] as num?)?.toDouble();
                  final lng = (addressData['longitude'] as num?)?.toDouble();
                  if (lat != null && lng != null) {
                    data['clientLat'] = lat;
                    data['clientLng'] = lng;
                  }
                }
              }
            }
          }
        }
      }

      if (restaurantId.isNotEmpty &&
          (!hasRestaurantName || !hasRestaurantLat || !hasRestaurantLng)) {
        DocumentSnapshot<Map<String, dynamic>>? restaurantDoc;
        final directDoc = await FirebaseFirestore.instance
            .collection('restaurants')
            .doc(restaurantId)
            .get();
        if (directDoc.exists) {
          restaurantDoc = directDoc;
        } else {
          final byOwner = await FirebaseFirestore.instance
              .collection('restaurants')
              .where('ownerUid', isEqualTo: restaurantId)
              .limit(1)
              .get();
          if (byOwner.docs.isNotEmpty) {
            restaurantDoc = byOwner.docs.first;
          }
        }

        if (restaurantDoc != null && restaurantDoc.exists) {
          final restaurantData = restaurantDoc.data() ?? <String, dynamic>{};
          if (!hasRestaurantName) {
            final fallbackName = (restaurantData['name'] ??
                    restaurantData['restaurantName'] ??
                    restaurantData['storeName'] ??
                    '')
                .toString()
                .trim();
            if (fallbackName.isNotEmpty) {
              data['restaurantName'] = fallbackName;
            }
          }

          if (!hasRestaurantLat || !hasRestaurantLng) {
            final location = restaurantData['location'];
            if (location is GeoPoint) {
              data['restaurantLat'] = location.latitude;
              data['restaurantLng'] = location.longitude;
            } else if (location is Map<String, dynamic>) {
              final lat = (location['lat'] as num?)?.toDouble();
              final lng = (location['lng'] as num?)?.toDouble();
              if (lat != null && lng != null) {
                data['restaurantLat'] = lat;
                data['restaurantLng'] = lng;
              }
            } else {
              final defaultAddressId =
                  (restaurantData['defaultAddressId'] ?? '').toString().trim();
              if (defaultAddressId.isNotEmpty) {
                final addressDoc = await FirebaseFirestore.instance
                    .collection('restaurants')
                    .doc(restaurantDoc.id)
                    .collection('addresses')
                    .doc(defaultAddressId)
                    .get();
                if (addressDoc.exists) {
                  final addressData = addressDoc.data() ?? <String, dynamic>{};
                  final lat = (addressData['latitude'] as num?)?.toDouble();
                  final lng = (addressData['longitude'] as num?)?.toDouble();
                  if (lat != null && lng != null) {
                    data['restaurantLat'] = lat;
                    data['restaurantLng'] = lng;
                  }
                }
              }
            }
          }
        }
      }

      final driverDoc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .get();
      final driverData = driverDoc.data() ?? <String, dynamic>{};
      final loc = driverData['location'];
      if (loc is GeoPoint) {
        data['driverLat'] = loc.latitude;
        data['driverLng'] = loc.longitude;
      } else if (loc is Map<String, dynamic>) {
        data['driverLat'] = (loc['lat'] as num?)?.toDouble() ??
            (loc['latitude'] as num?)?.toDouble();
        data['driverLng'] = (loc['lng'] as num?)?.toDouble() ??
            (loc['longitude'] as num?)?.toDouble();
      }
    } catch (e) {
      debugPrint('CourierGoToRestaurantScreen enrichment failed: $e');
    }

    return data;
  }

  Future<void> _saveCurrentStage(String stage) async {
    final box = GetStorage();
    box.write('current_order', {
      'orderId': orderId,
      'stage': stage,
    });
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetails(Map<String, dynamic> orderData) {
    final items = (orderData['items'] as List?) ?? const [];
    final paymentMethod = (orderData['paymentMethod'] ?? 'غير محدد').toString();
    final totalWithDelivery =
        (orderData['totalWithDelivery'] ?? orderData['total'] ?? 0).toString();
    final orderSource = (orderData['orderSource'] ?? '').toString();
    final isParcelDelivery = orderSource == 'client_parcel_delivery';
    final isStoreDirectDelivery = orderSource == 'store_direct_delivery';
    final pickupLabel = isParcelDelivery
        ? 'نقطة الاستلام'
        : isStoreDirectDelivery
            ? 'المتجر'
            : 'المطعم';
    final pickupName = isParcelDelivery
        ? 'نقطة الاستلام من العميل'
        : (orderData['restaurantName'] ?? 'نقطة الاستلام').toString();
    final packageDescription =
        (orderData['itemDescription'] ?? orderData['packageDescription'] ?? '')
            .toString()
            .trim();

    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        title: const Text(
          'تفاصيل الطلب',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        collapsedTextColor: Colors.black87,
        textColor: Colors.black87,
        iconColor: Colors.black87,
        collapsedIconColor: Colors.black87,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _detailRow(
            'رقم الطلب',
            formatUnifiedOrderCode(
              orderNumber: orderData['orderNumber'],
              orderId: orderData['orderId'],
              docId: orderId,
            ),
          ),
          _detailRow(
              'العميل', (orderData['clientName'] ?? 'العميل').toString()),
          _detailRow(pickupLabel, pickupName),
          _detailRow('طريقة الدفع', paymentMethod),
          _detailRow('الإجمالي', '$totalWithDelivery ج.س'),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              isParcelDelivery || isStoreDirectDelivery ? 'الإرسالية' : 'العناصر',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ),
          const SizedBox(height: 6),
          if (isParcelDelivery || isStoreDirectDelivery)
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                packageDescription.isEmpty ? 'إرسالية توصيل' : packageDescription,
                style: const TextStyle(color: Colors.black87),
              ),
            )
          else if (items.isEmpty)
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'لا توجد عناصر',
                style: TextStyle(color: Colors.black87),
              ),
            )
          else
            ...items.map((item) {
              final map = (item is Map<String, dynamic>)
                  ? item
                  : Map<String, dynamic>.from(item as Map);
              final name = (map['name'] ?? 'عنصر').toString();
              final qty = (map['quantity'] ?? 1).toString();
              return Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '• $name × $qty',
                  style: const TextStyle(color: Colors.black87),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildJourneyHeader({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor:
                AppThemeArabic.courierPrimary.withValues(alpha: 0.12),
            child: Icon(icon, color: AppThemeArabic.courierPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: buildCourierAppBar('الذهاب إلى نقطة الاستلام'),
      body: CourierPageBackground(
        child: FutureBuilder<Map<String, dynamic>?>(
          future: _fetchOrderData(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'حدث خطأ أثناء تحميل الطلب. حاول إعادة فتح الشاشة.',
                    style: TextStyle(color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data == null) {
              return const Center(
                child: Text(
                  'الطلب غير موجود أو تعذر تحميل بياناته',
                  style: TextStyle(color: Colors.black87),
                ),
              );
            }

            final orderData = snapshot.data!;
            final orderSource = (orderData['orderSource'] ?? '').toString();
            final isParcelDelivery = orderSource == 'client_parcel_delivery';
            final isStoreDirectDelivery = orderSource == 'store_direct_delivery';
            final isStoreBatchDelivery = orderSource == 'store_batch_delivery';
            final List<Map<String, dynamic>> batchStops =
                isStoreBatchDelivery ? _batchStops(orderData) : const [];
            final pickupTitle = isParcelDelivery
                ? 'نقطة الاستلام'
                : isStoreDirectDelivery
                    ? 'المتجر'
                    : isStoreBatchDelivery
                        ? 'المتجر'
                        : 'المطعم';
            final String restaurantName =
                isParcelDelivery
                    ? ((orderData['pickupAddress'] ?? orderData['pickupMapUrl'] ?? '')
                            .toString()
                            .trim()
                            .isNotEmpty
                        ? 'نقطة الاستلام من العميل'
                        : 'نقطة الاستلام')
                    : (orderData['restaurantName'] ?? '').toString().trim().isNotEmpty
                    ? orderData['restaurantName'].toString().trim()
                    : 'نقطة الاستلام';

            final restaurantLocationRaw = isParcelDelivery
                ? (orderData['pickupLocation'] ?? orderData['restaurantLocation'])
                : orderData['restaurantLocation'];
            final clientLocationRaw = orderData['clientLocation'];

            final double? restaurantLat = ((isParcelDelivery
                        ? orderData['pickupLat']
                        : orderData['restaurantLat']) as num?)
                    ?.toDouble() ??
                (restaurantLocationRaw is GeoPoint
                    ? restaurantLocationRaw.latitude
                    : (restaurantLocationRaw is Map<String, dynamic>
                        ? (restaurantLocationRaw['lat'] as num?)?.toDouble() ??
                            (restaurantLocationRaw['latitude'] as num?)
                                ?.toDouble()
                        : null));
            final double? restaurantLng = ((isParcelDelivery
                        ? orderData['pickupLng']
                        : orderData['restaurantLng']) as num?)
                    ?.toDouble() ??
                (restaurantLocationRaw is GeoPoint
                    ? restaurantLocationRaw.longitude
                    : (restaurantLocationRaw is Map<String, dynamic>
                        ? (restaurantLocationRaw['lng'] as num?)?.toDouble() ??
                            (restaurantLocationRaw['longitude'] as num?)
                                ?.toDouble()
                        : null));
            final double? clientLat = (orderData['clientLat'] as num?)
                    ?.toDouble() ??
                (clientLocationRaw is GeoPoint
                    ? clientLocationRaw.latitude
                    : (clientLocationRaw is Map<String, dynamic>
                        ? (clientLocationRaw['lat'] as num?)?.toDouble() ??
                            (clientLocationRaw['latitude'] as num?)?.toDouble()
                        : null));
            final double? clientLng = (orderData['clientLng'] as num?)
                    ?.toDouble() ??
                (clientLocationRaw is GeoPoint
                    ? clientLocationRaw.longitude
                    : (clientLocationRaw is Map<String, dynamic>
                        ? (clientLocationRaw['lng'] as num?)?.toDouble() ??
                            (clientLocationRaw['longitude'] as num?)?.toDouble()
                        : null));

            final bool hasRestaurantLocation =
                restaurantLat != null && restaurantLng != null;
            final bool hasClientLocation =
                clientLat != null && clientLng != null;

            final LatLng? restaurantLocation = hasRestaurantLocation
                ? LatLng(restaurantLat, restaurantLng)
                : null;
            final LatLng? clientLocation =
                hasClientLocation ? LatLng(clientLat, clientLng) : null;
            final batchClientLocations =
                batchStops.map(_batchStopLocation).whereType<LatLng>().toList();
            final batchHasClientLocations = batchClientLocations.isNotEmpty;
            final double? driverLat =
                (orderData['driverLat'] as num?)?.toDouble();
            final double? driverLng =
                (orderData['driverLng'] as num?)?.toDouble();
            final LatLng? driverLocation =
                driverLat != null && driverLng != null
                    ? LatLng(driverLat, driverLng)
                    : null;
            final driverToRestaurantKm =
                (driverLocation != null && restaurantLocation != null)
                    ? courierHaversineKm(driverLocation, restaurantLocation)
                    : null;
            final restaurantToClientKm =
                (restaurantLocation != null && clientLocation != null)
                    ? courierHaversineKm(restaurantLocation, clientLocation)
                    : null;
            final driverFee = courierToDouble(
              orderData['deliveryFeeForDriver'] ?? orderData['deliveryFee'],
            );

            _saveCurrentStage('going_to_restaurant');

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildJourneyHeader(
                  title: isStoreBatchDelivery
                      ? 'المرحلة 1 من 2 · استلام رحلة مجمعة'
                      : 'المرحلة 1 من 3 · التوجه إلى $pickupTitle',
                  subtitle: isStoreBatchDelivery
                      ? 'استلم كل الطلبيات من $pickupTitle مرة واحدة، ثم انتقل لشاشة العملاء.'
                      : 'عند وصولك إلى $pickupTitle واستلام الطلب اضغط «استلام الطلب»',
                  icon: isParcelDelivery
                      ? Icons.call_received_rounded
                      : Icons.store_mall_directory_outlined,
                ),
                const SizedBox(height: 12),
                _buildOrderDetails(orderData),
                const SizedBox(height: 12),
                if (isStoreBatchDelivery) ...[
                  CourierSectionCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'عملاء الرحلة',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${batchStops.length} طلبات داخل رحلة واحدة من نفس نقطة الاستلام.',
                          style: const TextStyle(
                            color: AppThemeArabic.courierTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: batchStops.take(8).map((stop) {
                            final zone =
                                (stop['zoneName'] ?? 'منطقة غير محددة')
                                    .toString();
                            return Chip(
                              label: Text(zone),
                              avatar: const Icon(
                                Icons.person_pin_circle_outlined,
                                size: 18,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  CourierClientContactCard(
                    orderData: orderData,
                    orderId: orderId,
                    driverId: driverId,
                    showPhone: true,
                  ),
                  const SizedBox(height: 12),
                ],
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppThemeArabic.courierSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.store,
                          color: AppThemeArabic.courierPrimary, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          restaurantName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: CourierCompactMetric(
                        icon: Icons.my_location_rounded,
                        label: '$pickupTitle عنك',
                        value: driverToRestaurantKm == null
                            ? 'غير متاح'
                            : courierFormatDistance(driverToRestaurantKm),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CourierCompactMetric(
                        icon: Icons.person_pin_circle_outlined,
                        label: isStoreBatchDelivery
                            ? 'عملاء الرحلة'
                            : 'العميل عن $pickupTitle',
                        value: isStoreBatchDelivery
                            ? '${batchStops.length} طلب'
                            : restaurantToClientKm == null
                                ? 'غير متاح'
                                : courierFormatDistance(restaurantToClientKm),
                        tone: AppThemeArabic.courierAccent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CourierCompactMetric(
                        icon: Icons.payments_outlined,
                        label: 'رسومك',
                        value: driverFee <= 0
                            ? 'غير متاح'
                            : '${courierFormatMoney(driverFee)} ج.س',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (hasRestaurantLocation) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      height: 260,
                      child: FutureBuilder<CourierMarkerIcons>(
                        future: loadCourierMarkerIcons(),
                        builder: (context, iconSnap) {
                          return GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: restaurantLocation!,
                              zoom: (isStoreBatchDelivery
                                          ? batchHasClientLocations
                                          : hasClientLocation)
                                      ? 12
                                      : 15,
                            ),
                            markers: isStoreBatchDelivery
                                ? _buildBatchPickupMarkers(
                                    pickupLocation: restaurantLocation,
                                    stops: batchStops,
                                    pickupTitle: pickupTitle,
                                  )
                                : buildCourierTripMarkers(
                                    restaurantLocation: restaurantLocation,
                                    clientLocation: clientLocation,
                                    icons: iconSnap.data,
                                    pickupLabel: pickupTitle,
                                  ),
                            polylines: isStoreBatchDelivery
                                ? {
                                    if (batchClientLocations.isNotEmpty)
                                      Polyline(
                                        polylineId:
                                            const PolylineId('batch_route'),
                                        points: [
                                          restaurantLocation,
                                          ...batchClientLocations,
                                        ],
                                        color: AppThemeArabic.courierPrimary,
                                        width: 6,
                                      ),
                                  }
                                : clientLocation == null
                                    ? const {}
                                    : {
                                        Polyline(
                                          polylineId: const PolylineId(
                                              'restaurant_client'),
                                          points: [
                                            restaurantLocation,
                                            clientLocation
                                          ],
                                          color: AppThemeArabic.courierPrimary,
                                          width: 6,
                                        ),
                                      },
                            onMapCreated: (controller) {
                              final points = <LatLng>[
                                restaurantLocation,
                                if (isStoreBatchDelivery)
                                  ...batchClientLocations
                                else if (clientLocation != null)
                                  clientLocation,
                              ];
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                _fitCameraToPoints(controller, points);
                              });
                            },
                            zoomControlsEnabled: true,
                            myLocationEnabled: true,
                            myLocationButtonEnabled: true,
                            compassEnabled: true,
                            rotateGesturesEnabled: true,
                            tiltGesturesEnabled: true,
                            mapToolbarEnabled: false,
                            gestureRecognizers: <Factory<
                                OneSequenceGestureRecognizer>>{
                              Factory<OneSequenceGestureRecognizer>(
                                  () => EagerGestureRecognizer()),
                            },
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppThemeArabic.courierPrimary
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.storefront_rounded, size: 16),
                            SizedBox(width: 6),
                            Text(isStoreBatchDelivery
                                ? 'نقطة الاستلام'
                                : pickupTitle),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppThemeArabic.courierAccent
                              .withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person_rounded, size: 16),
                            const SizedBox(width: 6),
                            Text(isStoreBatchDelivery
                                ? 'عملاء الرحلة'
                                : 'العميل'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'لا توجد إحداثيات لـ $pickupTitle في الطلب، لذلك لا يمكن عرض الخريطة حالياً.',
                      style: TextStyle(color: Colors.black87),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                _PickupFromRestaurantButton(
                  orderId: orderId,
                  driverId: driverId,
                  clientLocation: clientLocation,
                  clientLat: clientLat,
                  clientLng: clientLng,
                  restaurantLat: restaurantLat,
                  restaurantLng: restaurantLng,
                  isBatchDelivery: isStoreBatchDelivery,
                  confirmPickup: (context) =>
                      _confirmPickup(context, pickupTitle: pickupTitle),
                  saveNextStage: () => _saveCurrentStage('going_to_client'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PickupFromRestaurantButton extends StatefulWidget {
  const _PickupFromRestaurantButton({
    required this.orderId,
    required this.driverId,
    required this.clientLocation,
    required this.clientLat,
    required this.clientLng,
    required this.restaurantLat,
    required this.restaurantLng,
    required this.isBatchDelivery,
    required this.confirmPickup,
    required this.saveNextStage,
  });

  final String orderId;
  final String driverId;
  final LatLng? clientLocation;
  final double? clientLat;
  final double? clientLng;
  final double? restaurantLat;
  final double? restaurantLng;
  final bool isBatchDelivery;
  final Future<bool> Function(BuildContext context) confirmPickup;
  final Future<void> Function() saveNextStage;

  @override
  State<_PickupFromRestaurantButton> createState() =>
      _PickupFromRestaurantButtonState();
}

class _PickupFromRestaurantButtonState
    extends State<_PickupFromRestaurantButton> {
  bool _confirmingPickup = false;

  Future<void> _handlePickup() async {
    if (_confirmingPickup) return;
    final confirmed = await widget.confirmPickup(context);
    if (!confirmed) return;

    setState(() => _confirmingPickup = true);
    try {
      await courierInvokeCallable(
        'courierUpdateOrderStage',
        {
          'orderId': widget.orderId,
          'driverId': widget.driverId,
          'stage': 'picked_up',
        },
        timeout: const Duration(seconds: 10),
        maxAttempts: 2,
      );
      await widget.saveNextStage();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => widget.isBatchDelivery
              ? CourierBatchTripScreen(
                  orderId: widget.orderId,
                  driverId: widget.driverId,
                )
              : CourierGoToClientScreen(
                  orderId: widget.orderId,
                  clientLocation: widget.clientLocation,
                  driverId: widget.driverId,
                ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            courierFriendlyFunctionsError(
              e,
              fallback:
                  'تعذر تسجيل استلام الطلب. تحقق من الاتصال ثم أعد المحاولة.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _confirmingPickup = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final readyText = widget.isBatchDelivery ? 'استلام الرحلة' : 'استلام الطلب';
    return GFButton(
      onPressed: _handlePickup,
      text: _confirmingPickup ? 'جاري الاستلام...' : readyText,
      icon: _confirmingPickup
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.check_circle),
      color: AppThemeArabic.courierAccent,
      shape: GFButtonShape.pills,
      fullWidthButton: true,
      size: GFSize.LARGE,
      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
    );
  }
}
