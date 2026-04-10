import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';
import 'package:speedstar_core/speedstar_core.dart' show formatUnifiedOrderCode;
import '../services/order_service.dart';
import 'store_order_actions.dart';

const Set<String> _storeNewStatuses = {
  'store_pending',
  'قيد المراجعة',
  'بانتظار المطعم',
  'courier_searching',
  'courier_offer_pending',
  'courier_assigned',
  'قيد التجهيز',
  'pickup_ready',
  'جاهز للتوصيل',
};

String _storeStatusLabel(String status) {
  switch (status) {
    case 'store_pending':
    case 'قيد المراجعة':
    case 'بانتظار المطعم':
      return 'قيد المراجعة';
    case 'courier_searching':
    case 'courier_offer_pending':
    case 'قيد التجهيز':
      return 'جاري تجهيز الطلب والبحث عن مندوب';
    case 'courier_assigned':
      return 'تم تعيين مندوب';
    case 'pickup_ready':
    case 'جاهز للتوصيل':
      return 'جاهز للاستلام من المندوب';
    case 'picked_up':
    case 'arrived_to_client':
    case 'delivered':
    case 'وصل إلى العميل':
    case 'تم التوصيل':
      return 'تم الاستلام من المطعم';
    case 'store_rejected':
      return 'مرفوض من المتجر';
    case 'cancelled':
    case 'ملغي':
      return 'ملغي';
    default:
      return status.isEmpty ? '—' : status;
  }
}

Color _statusChipColor(String status) {
  if (status == 'store_rejected' || status == 'cancelled' || status == 'ملغي') {
    return Colors.red;
  }
  if (status == 'picked_up' ||
      status == 'arrived_to_client' ||
      status == 'delivered' ||
      status == 'وصل إلى العميل' ||
      status == 'تم التوصيل') {
    return Colors.green;
  }
  if (status == 'pickup_ready' || status == 'جاهز للتوصيل') {
    return Colors.blueGrey;
  }
  return AppThemeArabic.clientPrimary;
}

class StoreOrderDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> orderData;

  const StoreOrderDetailsScreen({
    Key? key,
    required this.orderData,
  }) : super(key: key);

  Future<void> _updateOrderStatusToPreparing(BuildContext context) async {
    try {
      final orderDocId = orderData['docId'] ?? orderData['orderId'];
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final restaurantId = orderData['restaurantId'];

      if (orderDocId != null && currentUid == restaurantId) {
        final restaurantLat = (orderData['restaurantLat'] as num?)?.toDouble();
        final restaurantLng = (orderData['restaurantLng'] as num?)?.toDouble();

        // جلب جميع السائقين للتشكيل في قائمة الانتظار
        final driversSnapshot =
            await FirebaseFirestore.instance.collection('drivers').get();

        List<Map<String, dynamic>> driverList = [];
        if (restaurantLat != null && restaurantLng != null) {
          for (var doc in driversSnapshot.docs) {
            final data = doc.data();
            final loc = data['location'];
            if (loc is GeoPoint) {
              final dx = loc.latitude - restaurantLat;
              final dy = loc.longitude - restaurantLng;
              driverList.add({
                'id': doc.id,
                'distance': dx * dx + dy * dy,
              });
            }
          }
        }

        if (driverList.isNotEmpty) {
          driverList.sort((a, b) => a['distance'].compareTo(b['distance']));
          final driverQueue = driverList.map((d) => d['id'] as String).toList();
          await FirebaseFirestore.instance
              .collection('orders')
              .doc(orderDocId)
              .update({
            'driverQueue': driverQueue,
          });
        }

        // إضافة التغيير عبر الخدمة الموحدة للحالة دون تغيير المنطق القديم
        await OrderService.approveByRestaurant(orderDocId);

        Navigator.of(context).pop();
        GFToast.showToast(
          '✅ تم قبول الطلب وبدء البحث عن مندوب',
          context,
          toastPosition: GFToastPosition.BOTTOM,
        );
      } else {
        GFToast.showToast(
          '⚠️ لا تملك صلاحية تعديل هذا الطلب',
          context,
          toastPosition: GFToastPosition.BOTTOM,
        );
      }
    } catch (e) {
      GFToast.showToast(
        '⚠️ حدث خطأ أثناء تحديث الطلب',
        context,
        toastPosition: GFToastPosition.BOTTOM,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = orderData['items'] as List<dynamic>? ?? [];
    final total = orderData['total'] ?? 0;
    final deliveryFee = orderData['deliveryFee'] ?? 0;
    final largeOrderFee = orderData['largeOrderFee'] ?? 0;
    final totalWithDelivery =
        orderData['totalWithDelivery'] ?? (total + deliveryFee + largeOrderFee);
    final clientName = orderData['clientName'] ?? 'غير معروف';
    final orderId = orderData['docId'] ?? orderData['orderId'] ?? '—';
    final unifiedOrderCode = formatUnifiedOrderCode(
      orderNumber: orderData['orderNumber'],
      orderId: orderData['orderId'],
      docId: orderData['docId'],
    );
    final status =
        (orderData['orderStatus'] ?? orderData['status'] ?? '').toString();
    final assignedDriverId = orderData['assignedDriverId'] as String?;
    final hasAssignedDriver = (assignedDriverId ?? '').trim().isNotEmpty;
    final showReadyAction = status == 'courier_searching' ||
        status == 'courier_offer_pending' ||
        status == 'courier_assigned' ||
        status == 'قيد التجهيز';

    final showAcceptReject = status == 'store_pending' ||
        status == 'قيد المراجعة' ||
        status == 'بانتظار المطعم';

    final storePerspectiveDone = !_storeNewStatuses.contains(status);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppThemeArabic.clientBackground,
        appBar: AppBar(
          title: const Text('تفاصيل الطلب'),
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            unifiedOrderCode,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppThemeArabic.clientPrimary,
                              fontFamily: 'Tajawal',
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _statusChipColor(status)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _storeStatusLabel(status),
                            style: TextStyle(
                              color: _statusChipColor(status),
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Tajawal',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '👤 اسم العميل: $clientName',
                      style:
                          const TextStyle(fontSize: 16, fontFamily: 'Tajawal'),
                    ),
                    if ((orderData['clientPhone'] ?? '')
                        .toString()
                        .trim()
                        .isNotEmpty)
                      Text(
                        '📞 هاتف العميل: ${orderData['clientPhone']}',
                        style: const TextStyle(
                            fontSize: 14, color: Colors.black54),
                      ),
                    const Divider(height: 30),
                    const Text(
                      'عناصر الطلب',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...items.map((item) {
                      final qty = item['quantity'] ?? 0;
                      final price = item['price'] ?? 0;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppThemeArabic.clientSurface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.restaurant_menu,
                              color: AppThemeArabic.clientPrimary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${item['name'] ?? 'صنف'} × $qty',
                                style: const TextStyle(fontFamily: 'Tajawal'),
                              ),
                            ),
                            Text(
                              '${(qty * price)} ج.س',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Tajawal'),
                            ),
                          ],
                        ),
                      );
                    }),
                    const Divider(height: 30),
                    Text(
                      '💰 الإجمالي الأساسي: $total ج.س',
                      style: const TextStyle(fontFamily: 'Tajawal'),
                    ),
                    Text(
                      '🚚 رسوم التوصيل: $deliveryFee ج.س',
                      style: const TextStyle(fontFamily: 'Tajawal'),
                    ),
                    if (largeOrderFee != 0)
                      Text(
                        '📦 رسوم الطلبات الكبيرة: $largeOrderFee ج.س',
                        style: const TextStyle(fontFamily: 'Tajawal'),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      '💳 الإجمالي النهائي: $totalWithDelivery ج.س',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (storePerspectiveDone)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '✅ من منظور المتجر: الطلب انتهى عند الاستلام من المطعم، ولا يلزمك تتبّع الحالات اللاحقة.',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                ),
              if (orderId != '—' && !storePerspectiveDone) ...[
                const SizedBox(height: 12),
                StoreOrderActions(orderId: orderId),
              ],
              if (showAcceptReject)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GFButton(
                      onPressed: () => _updateOrderStatusToPreparing(context),
                      text: 'قبول الطلب',
                      color: GFColors.SUCCESS,
                    ),
                    GFButton(
                      onPressed: () async {
                        final docId =
                            orderData['docId'] ?? orderData['orderId'];
                        await FirebaseFirestore.instance
                            .collection('orders')
                            .doc(docId)
                            .update({
                          'orderStatus': 'store_rejected',
                          'status': 'store_rejected',
                          'updatedAt': FieldValue.serverTimestamp(),
                        });
                        Navigator.of(context).pop();
                        GFToast.showToast('❌ تم إلغاء الطلب', context);
                      },
                      text: 'رفض الطلب',
                      color: GFColors.DANGER,
                    ),
                  ],
                ),
              if (showReadyAction)
                GFButton(
                  onPressed: () async {
                    final docId = orderData['docId'] ?? orderData['orderId'];
                    await FirebaseFirestore.instance
                        .collection('orders')
                        .doc(docId)
                        .update({
                      'readyByRestaurant': true,
                      'orderStatus': hasAssignedDriver
                          ? 'pickup_ready'
                          : 'courier_searching',
                      'status': hasAssignedDriver
                          ? 'pickup_ready'
                          : 'courier_searching',
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                    GFToast.showToast(
                      hasAssignedDriver
                          ? '✅ تم تجهيز الطلب وإرسال إشعار للمندوب'
                          : '✅ تم تجهيز الطلب وسيتم البحث عن مندوب تلقائيًا',
                      context,
                    );
                    Navigator.of(context).pop();
                  },
                  text: hasAssignedDriver ? 'جاهز للتوصيل' : 'جاهز وابدأ البحث',
                  color: AppThemeArabic.clientPrimary,
                  fullWidthButton: true,
                ),
              if (status == 'pickup_ready' || status == 'جاهز للتوصيل')
                const Center(
                  child: Text(
                    '✅ تم تجهيز الطلب - في انتظار المندوب',
                    style: TextStyle(color: Colors.blueGrey, fontSize: 16),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
