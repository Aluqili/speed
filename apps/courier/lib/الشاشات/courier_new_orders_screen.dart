import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:speedstar_core/speedstar_core.dart' show formatUnifiedOrderCode;
import '../helpers/courier_runtime_helpers.dart';

import 'courier_go_to_restaurant_screen.dart';
import 'courier_order_details_screen.dart';
import 'courier_ui.dart';

class CourierNewOrdersScreen extends StatefulWidget {
  final String driverId;

  const CourierNewOrdersScreen({super.key, required this.driverId});

  @override
  State<CourierNewOrdersScreen> createState() => _CourierNewOrdersScreenState();
}

class _CourierNewOrdersScreenState extends State<CourierNewOrdersScreen> {
  final Set<String> _processingOrderIds = <String>{};

  String get _courierAuthUid =>
      FirebaseAuth.instance.currentUser?.uid ?? widget.driverId;

  bool _isProcessing(String orderId) => _processingOrderIds.contains(orderId);

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _distanceText(Map<String, dynamic> data) {
    final roadKm = _toDouble(data['routeDistanceKm']);
    final km = roadKm > 0 ? roadKm : _toDouble(data['distanceKm']);
    if (km <= 0) return 'غير متاح';
    if (km < 1) return '${(km * 1000).round()} م';
    return '${km.toStringAsFixed(1)} كم';
  }

  String _etaText(Map<String, dynamic> data) {
    final eta = _toInt(data['estimatedDeliveryMinutes']);
    if (eta > 0) return '$eta دقيقة';
    final route = _toInt(data['routeDurationMinutes']);
    if (route > 0) return '$route دقيقة';
    return 'غير متاح';
  }

  String _firstText(List<dynamic> values, {String fallback = 'لم يحدد الاسم'}) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text != 'غير معروف' && text != 'غير متوفر') {
        return text;
      }
    }
    return fallback;
  }

  String _serviceLabel(Map<String, dynamic> data) {
    final source = (data['orderSource'] ?? '').toString();
    if (source == 'client_parcel_delivery') return 'وصلها';
    if (source == 'store_batch_delivery') return 'رحلة مجمعة';
    if (source == 'store_direct_delivery') return 'توصيل مباشر';
    return 'طلب متجر';
  }

  Future<void> _acceptOffer(String orderId) async {
    if (_isProcessing(orderId)) return;
    setState(() {
      _processingOrderIds.add(orderId);
    });
    try {
      await courierInvokeCallable(
        'courierRespondToOffer',
        {
          'orderId': orderId,
          'driverId': widget.driverId,
          'decision': 'accept',
        },
        timeout: const Duration(seconds: 12),
        maxAttempts: 2,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم قبول العرض بنجاح')),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CourierGoToRestaurantScreen(
            orderId: orderId,
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
              fallback: 'تعذر قبول العرض الآن. حاول مرة أخرى.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingOrderIds.remove(orderId);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildCourierAppBar('العروض المتاحة'),
      body: CourierPageBackground(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .where('offerDriverOwnerUids', arrayContains: _courierAuthUid)
              .where('orderStatus', isEqualTo: 'courier_offer_pending')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const CourierEmptyState(
                title: 'حسابك نشط بانتظار ظهور الطلبات',
                message: 'ستظهر هنا الطلبات الجديدة القريبة منك فور توفرها.',
                icon: Icons.local_shipping_outlined,
              );
            }

            final orders = snapshot.data!.docs.where((d) {
              final m = d.data() as Map<String, dynamic>;
              final status = (m['orderStatus'] ?? m['status'] ?? '').toString();
              return status == 'courier_offer_pending';
            }).toList()
              ..sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;
                final aTs = aData['createdAt'];
                final bTs = bData['createdAt'];
                final aMs = aTs is Timestamp
                    ? aTs.millisecondsSinceEpoch
                    : (aTs is num ? aTs.toInt() : 0);
                final bMs = bTs is Timestamp
                    ? bTs.millisecondsSinceEpoch
                    : (bTs is num ? bTs.toInt() : 0);
                return bMs.compareTo(aMs);
              });

            if (orders.isEmpty) {
              return const CourierEmptyState(
                title: 'حسابك نشط بانتظار ظهور الطلبات',
                message:
                    'كل العروض الحالية إما انتهت أو تم استلامها من مندوب آخر.',
                icon: Icons.hourglass_empty_rounded,
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                CourierHeroCard(
                  title: '${orders.length} عرض متاح',
                  subtitle: 'راجع العروض القريبة واختر المناسب لك.',
                  icon: Icons.notifications_active_rounded,
                ),
                const SizedBox(height: 16),
                ...orders.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final orderCode = formatUnifiedOrderCode(
                    orderNumber: data['orderNumber'],
                    orderId: data['orderId'],
                    docId: doc.id,
                  );
                  final restaurantName = _firstText([
                    data['restaurantName'],
                    data['storeName'],
                    data['pickupName'],
                  ], fallback: 'نقطة الاستلام');
                  final clientName = _firstText([
                    data['clientName'],
                    data['customerName'],
                    data['recipientName'],
                  ]);
                  final serviceLabel = _serviceLabel(data);
                  final isDirectDelivery =
                      data['orderSource'] == 'store_direct_delivery';
                  final isBatchDelivery =
                      data['orderSource'] == 'store_batch_delivery';
                  final itemsCount = (data['items'] as List?)?.length ?? 0;
                  final batchStopCount =
                      (data['batchStopCount'] as num?)?.toInt() ??
                          ((data['batchStops'] as List?)?.length ?? 0);
                  final batchZones = ((data['batchStops'] as List?) ?? const [])
                      .whereType<Map>()
                      .map((stop) => (stop['zoneName'] ?? '').toString())
                      .where((zone) => zone.trim().isNotEmpty)
                      .toSet()
                      .join('، ');
                  final isProcessing = _isProcessing(doc.id);
                  final total =
                      (data['totalWithDelivery'] ?? data['total'] ?? 0)
                          .toString();
                  final courierEarnings =
                      (data['deliveryFeeForDriver'] ?? data['driverShare'] ?? 0)
                          .toString();
                  final routeNoteText = isBatchDelivery
                      ? 'استلام مجموعة طلبيات من المتجر وتسليمها حسب خط السير'
                      : 'الاستلام من نقطة المتجر والتسليم للعميل';
                  final recipientText = isBatchDelivery
                      ? 'عدد التوقفات: $batchStopCount${batchZones.isNotEmpty ? ' - $batchZones' : ''}'
                      : 'العميل: $clientName';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: CourierSectionCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 11,
                            ),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFF1E8),
                              border: Border(
                                right: BorderSide(
                                  color: AppThemeArabic.courierAccent,
                                  width: 4,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.flash_on_rounded,
                                  color: AppThemeArabic.courierAccent,
                                  size: 19,
                                ),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    orderCode,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                      color: AppThemeArabic.courierTextPrimary,
                                    ),
                                  ),
                                ),
                                Text(
                                  serviceLabel,
                                  style: const TextStyle(
                                    color: AppThemeArabic.courierAccent,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  restaurantName,
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                    color: AppThemeArabic.courierTextPrimary,
                                  ),
                                ),
                                if (isDirectDelivery || isBatchDelivery) ...[
                                  const SizedBox(height: 5),
                                  const Text(
                                    'الاستلام من نقطة المتجر والتسليم للعميل',
                                    style: TextStyle(
                                      color: AppThemeArabic.courierPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                                if (isBatchDelivery) ...[
                                  const SizedBox(height: 5),
                                  Text(
                                    routeNoteText,
                                    style: const TextStyle(
                                      color: AppThemeArabic.courierPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    recipientText,
                                    style: const TextStyle(
                                      color:
                                          AppThemeArabic.courierTextSecondary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  recipientText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppThemeArabic.courierTextSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _OfferMetric(
                                        icon: Icons.payments_outlined,
                                        label: isDirectDelivery
                                            ? 'أجرك'
                                            : 'الإجمالي',
                                        value:
                                            '${isDirectDelivery ? courierEarnings : total} ج.س',
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _OfferMetric(
                                        icon: Icons.route_outlined,
                                        label: 'المسافة',
                                        value: _distanceText(data),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _OfferMetric(
                                        icon: Icons.schedule_rounded,
                                        label: 'الزمن',
                                        value: _etaText(data),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  isDirectDelivery
                                      ? (data['packageDescription']
                                                  ?.toString()
                                                  .trim()
                                                  .isNotEmpty ==
                                              true
                                          ? 'الإرسالية: ${data['packageDescription']}'
                                          : 'إرسالية توصيل مباشر')
                                      : '$itemsCount عناصر في الطلب',
                                  style: const TextStyle(
                                    color: AppThemeArabic.courierTextSecondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: isProcessing
                                            ? null
                                            : () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        CourierOrderDetailsScreen(
                                                      orderId: doc.id,
                                                      driverId: widget.driverId,
                                                    ),
                                                  ),
                                                );
                                              },
                                        icon: const Icon(
                                            Icons.visibility_outlined),
                                        label: const Text('التفاصيل'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: isProcessing
                                            ? null
                                            : () => _acceptOffer(doc.id),
                                        icon: isProcessing
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Icon(Icons.check_rounded),
                                        label: Text(
                                          isProcessing
                                              ? 'جاري الحجز...'
                                              : 'قبول الطلب',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OfferMetric extends StatelessWidget {
  const _OfferMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F6F3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppThemeArabic.courierPrimary),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: AppThemeArabic.courierTextPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppThemeArabic.courierTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
