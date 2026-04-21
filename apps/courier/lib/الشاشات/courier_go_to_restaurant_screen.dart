import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:getwidget/getwidget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'dart:math' as math;
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';
import 'package:speedstar_core/speedstar_core.dart' show formatUnifiedOrderCode;
import '../helpers/courier_runtime_helpers.dart';

import 'chat_screen.dart';
import 'courier_go_to_client_screen.dart';

class CourierGoToRestaurantScreen extends StatelessWidget {
  final String orderId;
  final String driverId;

  const CourierGoToRestaurantScreen({
    Key? key,
    required this.orderId,
    required this.driverId,
  }) : super(key: key);

  Future<void> _openGoogleMaps(BuildContext context, LatLng location) async {
    final Uri url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${location.latitude},${location.longitude}&travelmode=driving');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تعذر فتح خرائط Google على هذا الجهاز')),
    );
  }

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

  Future<bool> _confirmPickup(BuildContext context) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الاستلام'),
        content: const Text('هل أنت متأكد أنك استلمت الطلب من المطعم؟'),
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

  String _generateChatId(String user1, String user2) {
    final sorted = [user1, user2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  Future<void> _openClientChat(
    BuildContext context,
    Map<String, dynamic> orderData,
  ) async {
    final clientId = (orderData['clientId'] ?? '').toString().trim();
    if (clientId.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('لا يمكن فتح الدردشة لعدم توفر معرف العميل')),
      );
      return;
    }

    final doc = await FirebaseFirestore.instance
        .collection('drivers')
        .doc(driverId)
        .get();
    final driverName = (doc.data()?['name'] ?? 'مندوب').toString();

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          currentUserId: driverId,
          otherUserId: clientId,
          currentUserRole: 'driver',
          chatId: _generateChatId(driverId, clientId),
          currentUserName: driverName,
        ),
      ),
    );
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
              'العميل', (orderData['clientName'] ?? 'غير معروف').toString()),
          _detailRow('المطعم',
              (orderData['restaurantName'] ?? 'غير معروف').toString()),
          _detailRow('طريقة الدفع', paymentMethod),
          _detailRow('الإجمالي', '$totalWithDelivery ج.س'),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'العناصر',
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ),
          const SizedBox(height: 6),
          if (items.isEmpty)
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
      backgroundColor: AppThemeArabic.courierBackground,
      appBar: AppBar(
        title: const Text(
          'الذهاب إلى المطعم',
          style: TextStyle(
              color: AppThemeArabic.courierPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 20,
              fontFamily: 'Tajawal'),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppThemeArabic.courierPrimary),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
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
          final String restaurantName =
              (orderData['restaurantName'] ?? '').toString().trim().isNotEmpty
                  ? orderData['restaurantName'].toString().trim()
                  : 'اسم غير معروف';

          final restaurantLocationRaw = orderData['restaurantLocation'];
          final clientLocationRaw = orderData['clientLocation'];

          final double? restaurantLat = (orderData['restaurantLat'] as num?)
                  ?.toDouble() ??
              (restaurantLocationRaw is GeoPoint
                  ? restaurantLocationRaw.latitude
                  : (restaurantLocationRaw is Map<String, dynamic>
                      ? (restaurantLocationRaw['lat'] as num?)?.toDouble() ??
                          (restaurantLocationRaw['latitude'] as num?)
                              ?.toDouble()
                      : null));
          final double? restaurantLng = (orderData['restaurantLng'] as num?)
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
          final bool hasClientLocation = clientLat != null && clientLng != null;

          final LatLng? restaurantLocation = hasRestaurantLocation
              ? LatLng(restaurantLat, restaurantLng)
              : null;
          final LatLng? clientLocation =
              hasClientLocation ? LatLng(clientLat, clientLng) : null;
          final double? driverLat =
              (orderData['driverLat'] as num?)?.toDouble();
          final double? driverLng =
              (orderData['driverLng'] as num?)?.toDouble();
          final LatLng? driverLocation = driverLat != null && driverLng != null
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
                title: 'المرحلة 1 من 3 · التوجه للمطعم',
                subtitle: 'عند وصولك للمطعم واستلام الطلب اضغط «استلام الطلب»',
                icon: Icons.store_mall_directory_outlined,
              ),
              const SizedBox(height: 12),
              _buildOrderDetails(orderData),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _openClientChat(context, orderData),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('الدردشة مع العميل'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemeArabic.courierAccent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (driverToRestaurantKm != null)
                    Chip(
                      label: Text(
                        'يبعد المطعم عنك: ${courierFormatDistance(driverToRestaurantKm)}',
                      ),
                    ),
                  if (restaurantToClientKm != null)
                    Chip(
                      label: Text(
                        'يبعد العميل عن المطعم: ${courierFormatDistance(restaurantToClientKm)}',
                      ),
                    ),
                  if (driverFee > 0)
                    Chip(
                      label: Text(
                        'رسوم التوصيل: ${courierFormatMoney(driverFee)} ج.س',
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
                            zoom: hasClientLocation ? 12 : 15,
                          ),
                          markers: buildCourierTripMarkers(
                            restaurantLocation: restaurantLocation,
                            clientLocation: clientLocation,
                            icons: iconSnap.data,
                          ),
                          polylines: clientLocation == null
                              ? const {}
                              : {
                                  Polyline(
                                    polylineId:
                                        const PolylineId('restaurant_client'),
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
                              if (clientLocation != null) clientLocation,
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
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.storefront_rounded, size: 16),
                          SizedBox(width: 6),
                          Text('المطعم'),
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
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_rounded, size: 16),
                          SizedBox(width: 6),
                          Text('العميل'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.center,
                  child: Material(
                    color: AppThemeArabic.courierPrimary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () =>
                          _openGoogleMaps(context, restaurantLocation!),
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Icon(
                          Icons.navigation_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'لا توجد إحداثيات للمطعم في الطلب، لذلك لا يمكن عرض الخريطة حالياً.',
                    style: TextStyle(color: Colors.black87),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              GFButton(
                onPressed: () async {
                  final confirmed = await _confirmPickup(context);
                  if (!confirmed) return;
                  await FirebaseFirestore.instance
                      .collection('orders')
                      .doc(orderId)
                      .update({
                    'orderStatus': 'picked_up',
                    'status': 'picked_up',
                    'pickedUpAt': FieldValue.serverTimestamp(),
                    'updatedAt': FieldValue.serverTimestamp(),
                    if (clientLat != null) 'clientLat': clientLat,
                    if (clientLng != null) 'clientLng': clientLng,
                    if (restaurantLat != null) 'restaurantLat': restaurantLat,
                    if (restaurantLng != null) 'restaurantLng': restaurantLng,
                  });
                  await _saveCurrentStage('going_to_client');
                  if (!context.mounted) return;
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => CourierGoToClientScreen(
                        orderId: orderId,
                        clientLocation: clientLocation,
                        driverId: driverId,
                      ),
                    ),
                  );
                },
                text: 'استلام الطلب',
                icon: const Icon(Icons.check_circle),
                color: AppThemeArabic.courierAccent,
                shape: GFButtonShape.pills,
                fullWidthButton: true,
                size: GFSize.LARGE,
                textStyle:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ],
          );
        },
      ),
    );
  }
}
