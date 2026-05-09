import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';
import 'package:speedstar_core/speedstar_core.dart' show formatUnifiedOrderCode;
import '../services/order_service.dart';

const Set<String> _storeNewStatuses = {
  'payment_review',
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
    case 'payment_review':
      return 'بانتظار مراجعة الدفع';
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

num _safeNum(dynamic value) {
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '') ?? 0;
}

String _formatAmount(num value) {
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);
}

Map<String, dynamic> _promoDetails(Map<String, dynamic> orderData) {
  final promo = orderData['promocode'];
  if (promo is Map<String, dynamic>) return promo;
  if (promo is Map) {
    return promo.map(
      (key, value) => MapEntry(key.toString(), value),
    );
  }
  return const {};
}

num _storeDiscountAmount(Map<String, dynamic> orderData) {
  final restaurantId = (orderData['restaurantId'] ?? '').toString().trim();
  final promo = _promoDetails(orderData);
  final promoRestaurantId = (promo['restaurantId'] ?? '').toString().trim();
  final discountScope = (promo['discountScope'] ?? '').toString().trim();
  final discountAmount = _safeNum(orderData['discountAmount']);
  final isStoreOwnedPromo =
      restaurantId.isNotEmpty && promoRestaurantId == restaurantId;

  if (!isStoreOwnedPromo || discountAmount <= 0) {
    return 0;
  }
  if (discountScope == 'delivery_fee') {
    return 0;
  }
  return discountAmount;
}

num _storeReceivable(Map<String, dynamic> orderData) {
  final subtotal = _safeNum(orderData['total']);
  final storeDiscount = _storeDiscountAmount(orderData);
  final receivable = subtotal - storeDiscount;
  return receivable < 0 ? 0 : receivable;
}

String _itemSpecialNotes(dynamic rawItem) {
  if (rawItem is! Map) return '';
  const keys = [
    'notes',
    'note',
    'itemNotes',
    'itemNote',
    'specialInstructions',
    'instructions',
    'customization',
    'customizations',
  ];
  for (final key in keys) {
    final value = rawItem[key];
    if (value is Iterable) {
      final joined = value
          .map((entry) => entry.toString().trim())
          .where((entry) => entry.isNotEmpty)
          .join('، ');
      if (joined.isNotEmpty) return joined;
    }
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return '';
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
        if (!context.mounted) return;

        final updatedSnapshot = await FirebaseFirestore.instance
            .collection('orders')
            .doc(orderDocId)
            .get();
        final updatedOrderData =
            Map<String, dynamic>.from(updatedSnapshot.data() ?? orderData);
        updatedOrderData['docId'] = updatedSnapshot.id;
        GFToast.showToast(
          '✅ تم قبول الطلب وبدء البحث عن مندوب',
          context,
          toastPosition: GFToastPosition.BOTTOM,
        );
        if (!context.mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) =>
                StoreOrderDetailsScreen(orderData: updatedOrderData),
          ),
        );
      } else {
        GFToast.showToast(
          '⚠️ لا تملك صلاحية تعديل هذا الطلب',
          context,
          toastPosition: GFToastPosition.BOTTOM,
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      GFToast.showToast(
        '⚠️ حدث خطأ أثناء تحديث الطلب',
        context,
        toastPosition: GFToastPosition.BOTTOM,
      );
    }
  }

  Future<void> _rejectOrder(BuildContext context) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('رفض الطلب'),
              content: const Text(
                'سيتم إنهاء الطلب من جهة المتجر ولن يعود إلى قائمة الطلبات الجديدة. هل تريد المتابعة؟',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('تأكيد الرفض'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) return;

    final docId = orderData['docId'] ?? orderData['orderId'];
    await FirebaseFirestore.instance.collection('orders').doc(docId).update({
      'orderStatus': 'store_rejected',
      'status': 'store_rejected',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (!context.mounted) return;
    Navigator.of(context).pop();
    GFToast.showToast('تم رفض الطلب', context);
  }

  @override
  Widget build(BuildContext context) {
    final items = orderData['items'] as List<dynamic>? ?? [];
    final subtotal = _safeNum(orderData['total']);
    final storeDiscount = _storeDiscountAmount(orderData);
    final receivable = _storeReceivable(orderData);
    final hasStoreDiscount = storeDiscount > 0;
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
    final orderNote =
        (orderData['notes'] ?? orderData['orderNotes'] ?? '').toString().trim();

    Widget infoPill({
      required IconData icon,
      required String label,
      required String value,
    }) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppThemeArabic.storeSurface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppThemeArabic.storePrimary, size: 18),
              const SizedBox(height: 10),
              Text(
                label,
                style: const TextStyle(
                  color: AppThemeArabic.storeTextSecondary,
                  fontSize: 12,
                  fontFamily: 'Tajawal',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Tajawal',
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget sectionCard({
      required String title,
      required IconData icon,
      required Widget child,
    }) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.black12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppThemeArabic.storePrimary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: AppThemeArabic.storePrimary),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Tajawal',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppThemeArabic.storeBackground,
        appBar: AppBar(
          title: const Text('تفاصيل الطلب'),
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppThemeArabic.storePrimary, Color(0xFF14B8A6)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(26),
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
                              color: Colors.white,
                              fontFamily: 'Tajawal',
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _storeStatusLabel(status),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Tajawal',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'مراجعة سريعة قبل قبول الطلب أو تجهيزه.',
                      style: const TextStyle(
                        fontSize: 14,
                        fontFamily: 'Tajawal',
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        infoPill(
                          icon: Icons.shopping_bag_outlined,
                          label: 'الأصناف',
                          value: '${items.length} عناصر',
                        ),
                        const SizedBox(width: 10),
                        infoPill(
                          icon: Icons.payments_outlined,
                          label:
                              hasStoreDiscount ? 'صافي المتجر' : 'مستحق المتجر',
                          value: '${_formatAmount(receivable)} ج.س',
                        ),
                      ],
                    ),
                    if (hasStoreDiscount) ...[
                      const SizedBox(height: 10),
                      infoPill(
                        icon: Icons.local_offer_outlined,
                        label: 'خصم ممول من المتجر',
                        value: '${_formatAmount(storeDiscount)} ج.س',
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              sectionCard(
                title: 'عناصر الطلب',
                icon: Icons.restaurant_menu_outlined,
                child: Column(
                  children: items.map((item) {
                    final qty = item['quantity'] ?? 0;
                    final price = item['price'] ?? 0;
                    final totalItemPrice = qty * price;
                    final itemNotes = _itemSpecialNotes(item);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppThemeArabic.storeSurface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: AppThemeArabic.storePrimary
                                  .withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.fastfood_rounded,
                              color: AppThemeArabic.storePrimary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name']?.toString() ?? 'صنف',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Tajawal',
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'الكمية: $qty',
                                  style: const TextStyle(
                                    color: AppThemeArabic.storeTextSecondary,
                                    fontFamily: 'Tajawal',
                                  ),
                                ),
                                if (itemNotes.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppThemeArabic.storeAccent
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.sticky_note_2_outlined,
                                          size: 16,
                                          color: AppThemeArabic.storeAccent,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            itemNotes,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: AppThemeArabic
                                                  .storeTextPrimary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Text(
                            '$totalItemPrice ج.س',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Tajawal',
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 18),
              sectionCard(
                title: 'المبلغ المستحق للمتجر',
                icon: Icons.account_balance_wallet_outlined,
                child: Column(
                  children: [
                    _buildMoneyRow(
                      'قيمة أصناف الطلب',
                      '${_formatAmount(subtotal)} ج.س',
                    ),
                    if (hasStoreDiscount)
                      _buildMoneyRow(
                        'خصم المتجر',
                        '- ${_formatAmount(storeDiscount)} ج.س',
                      ),
                    const Divider(height: 26),
                    _buildMoneyRow(
                      hasStoreDiscount
                          ? 'صافي ما يستلمه المتجر'
                          : 'ما يستلمه المتجر',
                      '${_formatAmount(receivable)} ج.س',
                      emphasized: true,
                    ),
                  ],
                ),
              ),
              if (orderNote.isNotEmpty) ...[
                const SizedBox(height: 18),
                sectionCard(
                  title: 'ملاحظات الطلب',
                  icon: Icons.sticky_note_2_outlined,
                  child: Text(
                    orderNote,
                    style: const TextStyle(fontSize: 15, fontFamily: 'Tajawal'),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              if (storePerspectiveDone)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(16),
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
              if (showAcceptReject)
                sectionCard(
                  title: 'قرار المتجر',
                  icon: Icons.rule_folder_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'راجع الأصناف والمبلغ المستحق، ثم اختر الإجراء المناسب للطلب.',
                        style: TextStyle(
                          color: AppThemeArabic.storeTextSecondary,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () =>
                                  _updateOrderStatusToPreparing(context),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF0F9D58),
                                minimumSize: const Size.fromHeight(56),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              icon: const Icon(
                                  Icons.check_circle_outline_rounded),
                              label: const Text('قبول وبدء المعالجة'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _rejectOrder(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade700,
                                side: BorderSide(color: Colors.red.shade200),
                                minimumSize: const Size.fromHeight(56),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                backgroundColor: Colors.red.shade50,
                              ),
                              icon: const Icon(Icons.close_rounded),
                              label: const Text('رفض الطلب'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              if (showReadyAction)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: sectionCard(
                    title: 'تجهيز الطلب',
                    icon: Icons.delivery_dining_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasAssignedDriver
                              ? 'عند اكتمال التحضير سيتم إشعار المندوب مباشرة بالاستلام.'
                              : 'عند اكتمال التحضير سيتم إبقاء الطلب جاهزًا ومتابعة البحث عن مندوب تلقائيًا.',
                          style: const TextStyle(
                            color: AppThemeArabic.storeTextSecondary,
                            fontFamily: 'Tajawal',
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () async {
                              final docId =
                                  orderData['docId'] ?? orderData['orderId'];
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
                              if (!context.mounted) return;
                              final updatedSnapshot = await FirebaseFirestore
                                  .instance
                                  .collection('orders')
                                  .doc(docId)
                                  .get();
                              final updatedOrderData =
                                  Map<String, dynamic>.from(
                                      updatedSnapshot.data() ?? orderData);
                              updatedOrderData['docId'] = updatedSnapshot.id;
                              GFToast.showToast(
                                hasAssignedDriver
                                    ? 'تم تجهيز الطلب وإرسال إشعار للمندوب'
                                    : 'تم تجهيز الطلب وسيتم البحث عن مندوب تلقائيًا',
                                context,
                              );
                              if (!context.mounted) return;
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => StoreOrderDetailsScreen(
                                    orderData: updatedOrderData,
                                  ),
                                ),
                              );
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppThemeArabic.storePrimary,
                              minimumSize: const Size.fromHeight(54),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            icon: const Icon(Icons.inventory_2_outlined),
                            label: Text(
                              hasAssignedDriver
                                  ? 'تأكيد الجاهزية للاستلام'
                                  : 'تأكيد الجاهزية والبحث',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (status == 'pickup_ready' || status == 'جاهز للتوصيل')
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.local_shipping_outlined,
                          color: Colors.blueGrey),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'تم تجهيز الطلب وهو الآن بانتظار استلام المندوب.',
                          style:
                              TextStyle(color: Colors.blueGrey, fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoneyRow(String label, String value, {bool emphasized = false}) {
    final style = TextStyle(
      fontFamily: 'Tajawal',
      fontWeight: emphasized ? FontWeight.w800 : FontWeight.w500,
      fontSize: emphasized ? 18 : 14,
      color: emphasized
          ? AppThemeArabic.storePrimary
          : AppThemeArabic.storeTextPrimary,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}
