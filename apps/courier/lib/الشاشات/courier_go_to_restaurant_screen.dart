import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:getwidget/getwidget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'dart:math' as math;
import 'package:speedstar_core/Ø§Ù„Ø«ÙŠÙ…/Ø«ÙŠÙ…_Ø§Ù„ØªØ·Ø¨ÙŠÙ‚.dart';
import 'package:speedstar_core/speedstar_core.dart' show formatUnifiedOrderCode;
import '../helpers/courier_runtime_helpers.dart';

import 'courier_client_contact_card.dart';
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

  Future<void> _openGoogleMaps(BuildContext context, LatLng location) async {
    final Uri url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${location.latitude},${location.longitude}&travelmode=driving');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ØªØ¹Ø°Ø± ÙØªØ­ Ø®Ø±Ø§Ø¦Ø· Google Ø¹Ù„Ù‰ Ù‡Ø°Ø§ Ø§Ù„Ø¬Ù‡Ø§Ø²')),
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
      ),
      ),
    );
  }

  Future<bool> _confirmPickup(BuildContext context) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ØªØ£ÙƒÙŠØ¯ Ø§Ù„Ø§Ø³ØªÙ„Ø§Ù…'),
        content: const Text('Ù‡Ù„ Ø£Ù†Øª Ù…ØªØ£ÙƒØ¯ Ø£Ù†Ùƒ Ø§Ø³ØªÙ„Ù…Øª Ø§Ù„Ø·Ù„Ø¨ Ù…Ù† Ø§Ù„Ù…Ø·Ø¹Ù…ØŸ'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Ø¥Ù„ØºØ§Ø¡'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ØªØ£ÙƒÙŠØ¯ Ø§Ù„Ø§Ø³ØªÙ„Ø§Ù…'),
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
    final paymentMethod = (orderData['paymentMethod'] ?? 'ØºÙŠØ± Ù…Ø­Ø¯Ø¯').toString();
    final totalWithDelivery =
        (orderData['totalWithDelivery'] ?? orderData['total'] ?? 0).toString();

    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        title: const Text(
          'ØªÙØ§ØµÙŠÙ„ Ø§Ù„Ø·Ù„Ø¨',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        collapsedTextColor: Colors.black87,
        textColor: Colors.black87,
        iconColor: Colors.black87,
        collapsedIconColor: Colors.black87,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _detailRow(
            'Ø±Ù‚Ù… Ø§Ù„Ø·Ù„Ø¨',
            formatUnifiedOrderCode(
              orderNumber: orderData['orderNumber'],
              orderId: orderData['orderId'],
              docId: orderId,
            ),
          ),
          _detailRow(
              'Ø§Ù„Ø¹Ù…ÙŠÙ„', (orderData['clientName'] ?? 'ØºÙŠØ± Ù…Ø¹Ø±ÙˆÙ').toString()),
          _detailRow('Ø§Ù„Ù…Ø·Ø¹Ù…',
              (orderData['restaurantName'] ?? 'ØºÙŠØ± Ù…Ø¹Ø±ÙˆÙ').toString()),
          _detailRow('Ø·Ø±ÙŠÙ‚Ø© Ø§Ù„Ø¯ÙØ¹', paymentMethod),
          _detailRow('Ø§Ù„Ø¥Ø¬Ù…Ø§Ù„ÙŠ', '$totalWithDelivery Ø¬.Ø³'),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Ø§Ù„Ø¹Ù†Ø§ØµØ±',
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ),
          const SizedBox(height: 6),
          if (items.isEmpty)
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Ù„Ø§ ØªÙˆØ¬Ø¯ Ø¹Ù†Ø§ØµØ±',
                style: TextStyle(color: Colors.black87),
              ),
            )
          else
            ...items.map((item) {
              final map = (item is Map<String, dynamic>)
                  ? item
                  : Map<String, dynamic>.from(item as Map);
              final name = (map['name'] ?? 'Ø¹Ù†ØµØ±').toString();
              final qty = (map['quantity'] ?? 1).toString();
              return Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'â€¢ $name Ã— $qty',
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
      appBar: buildCourierAppBar('الذهاب إلى المطعم'),
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
                  'Ø­Ø¯Ø« Ø®Ø·Ø£ Ø£Ø«Ù†Ø§Ø¡ ØªØ­Ù…ÙŠÙ„ Ø§Ù„Ø·Ù„Ø¨. Ø­Ø§ÙˆÙ„ Ø¥Ø¹Ø§Ø¯Ø© ÙØªØ­ Ø§Ù„Ø´Ø§Ø´Ø©.',
                  style: TextStyle(color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(
              child: Text(
                'Ø§Ù„Ø·Ù„Ø¨ ØºÙŠØ± Ù…ÙˆØ¬ÙˆØ¯ Ø£Ùˆ ØªØ¹Ø°Ø± ØªØ­Ù…ÙŠÙ„ Ø¨ÙŠØ§Ù†Ø§ØªÙ‡',
                style: TextStyle(color: Colors.black87),
              ),
            );
          }

          final orderData = snapshot.data!;
          final String restaurantName =
              (orderData['restaurantName'] ?? '').toString().trim().isNotEmpty
                  ? orderData['restaurantName'].toString().trim()
                  : 'Ø§Ø³Ù… ØºÙŠØ± Ù…Ø¹Ø±ÙˆÙ';

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
                title: 'Ø§Ù„Ù…Ø±Ø­Ù„Ø© 1 Ù…Ù† 3 Â· Ø§Ù„ØªÙˆØ¬Ù‡ Ù„Ù„Ù…Ø·Ø¹Ù…',
                subtitle: 'Ø¹Ù†Ø¯ ÙˆØµÙˆÙ„Ùƒ Ù„Ù„Ù…Ø·Ø¹Ù… ÙˆØ§Ø³ØªÙ„Ø§Ù… Ø§Ù„Ø·Ù„Ø¨ Ø§Ø¶ØºØ· Â«Ø§Ø³ØªÙ„Ø§Ù… Ø§Ù„Ø·Ù„Ø¨Â»',
                icon: Icons.store_mall_directory_outlined,
              ),
              const SizedBox(height: 12),
              _buildOrderDetails(orderData),
              const SizedBox(height: 12),
              CourierClientContactCard(
                orderData: orderData,
                driverId: driverId,
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
                        'ÙŠØ¨Ø¹Ø¯ Ø§Ù„Ù…Ø·Ø¹Ù… Ø¹Ù†Ùƒ: ${courierFormatDistance(driverToRestaurantKm)}',
                      ),
                    ),
                  if (restaurantToClientKm != null)
                    Chip(
                      label: Text(
                        'ÙŠØ¨Ø¹Ø¯ Ø§Ù„Ø¹Ù…ÙŠÙ„ Ø¹Ù† Ø§Ù„Ù…Ø·Ø¹Ù…: ${courierFormatDistance(restaurantToClientKm)}',
                      ),
                    ),
                  if (driverFee > 0)
                    Chip(
                      label: Text(
                        'Ø±Ø³ÙˆÙ… Ø§Ù„ØªÙˆØµÙŠÙ„: ${courierFormatMoney(driverFee)} Ø¬.Ø³',
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
                          Text('Ø§Ù„Ù…Ø·Ø¹Ù…'),
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
                          Text('Ø§Ù„Ø¹Ù…ÙŠÙ„'),
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
                    'Ù„Ø§ ØªÙˆØ¬Ø¯ Ø¥Ø­Ø¯Ø§Ø«ÙŠØ§Øª Ù„Ù„Ù…Ø·Ø¹Ù… ÙÙŠ Ø§Ù„Ø·Ù„Ø¨ØŒ Ù„Ø°Ù„Ùƒ Ù„Ø§ ÙŠÙ…ÙƒÙ† Ø¹Ø±Ø¶ Ø§Ù„Ø®Ø±ÙŠØ·Ø© Ø­Ø§Ù„ÙŠØ§Ù‹.',
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
                confirmPickup: _confirmPickup,
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
      await FirebaseFunctions.instanceFor(region: 'me-central1')
          .httpsCallable('courierUpdateOrderStage')
          .call({
        'orderId': widget.orderId,
        'driverId': widget.driverId,
        'stage': 'picked_up',
      });
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .set({
        if (widget.clientLat != null) 'clientLat': widget.clientLat,
        if (widget.clientLng != null) 'clientLng': widget.clientLng,
        if (widget.restaurantLat != null) 'restaurantLat': widget.restaurantLat,
        if (widget.restaurantLng != null) 'restaurantLng': widget.restaurantLng,
      }, SetOptions(merge: true));
      await widget.saveNextStage();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CourierGoToClientScreen(
            orderId: widget.orderId,
            clientLocation: widget.clientLocation,
            driverId: widget.driverId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ØªØ¹Ø°Ø± ØªØ³Ø¬ÙŠÙ„ Ø§Ù„Ø§Ø³ØªÙ„Ø§Ù…: $e')),
      );
    } finally {
      if (mounted) setState(() => _confirmingPickup = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GFButton(
      onPressed: _handlePickup,
      text: _confirmingPickup ? 'Ø¬Ø§Ø±ÙŠ Ø§Ù„Ø§Ø³ØªÙ„Ø§Ù…...' : 'Ø§Ø³ØªÙ„Ø§Ù… Ø§Ù„Ø·Ù„Ø¨',
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


