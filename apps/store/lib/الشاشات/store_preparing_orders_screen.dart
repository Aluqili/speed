import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:speedstar_core/speedstar_core.dart' show formatUnifiedOrderCode;
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';

const Set<String> _preparingStatuses = {
  'courier_searching',
  'courier_offer_pending',
  'courier_assigned',
  'قيد التجهيز',
};

String _getOrderStatus(Map<String, dynamic> data) {
  return (data['orderStatus'] ?? data['status'] ?? '').toString().trim();
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

num _itemQuantity(dynamic rawItem) {
  if (rawItem is! Map) return 0;
  final value = rawItem['quantity'] ?? rawItem['qty'] ?? 1;
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '') ?? 0;
}

String _itemName(dynamic rawItem) {
  if (rawItem is! Map) return 'صنف';
  final name = (rawItem['name'] ?? rawItem['title'] ?? 'صنف').toString().trim();
  return name.isEmpty ? 'صنف' : name;
}

Map<String, dynamic> _promoDetails(Map<String, dynamic> data) {
  final promo = data['promocode'];
  if (promo is Map<String, dynamic>) return promo;
  if (promo is Map) {
    return promo.map((key, value) => MapEntry(key.toString(), value));
  }
  return const {};
}

num _storeDiscountAmount(Map<String, dynamic> data) {
  final restaurantId = (data['restaurantId'] ?? '').toString().trim();
  final promo = _promoDetails(data);
  final promoRestaurantId = (promo['restaurantId'] ?? '').toString().trim();
  final scope = (promo['discountScope'] ?? '').toString().trim();
  final discountAmount = _safeNum(data['discountAmount']);
  if (restaurantId.isEmpty || promoRestaurantId != restaurantId) return 0;
  if (scope == 'delivery_fee' || discountAmount <= 0) return 0;
  return discountAmount;
}

num _storeReceivable(Map<String, dynamic> data) {
  final subtotal = _safeNum(data['total']);
  final net = subtotal - _storeDiscountAmount(data);
  return net < 0 ? 0 : net;
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

List<String> _itemNotesSummary(Map<String, dynamic> data) {
  final items = data['items'];
  if (items is! List) return const [];
  return items
      .map((item) {
        final name = _itemName(item);
        final quantity = _itemQuantity(item);
        final notes = _itemSpecialNotes(item);
        return notes.isEmpty ? '' : '${_formatAmount(quantity)} × $name: $notes';
      })
      .where((entry) => entry.isNotEmpty)
      .toList();
}

List<String> _itemSummaryLines(Map<String, dynamic> data) {
  final items = data['items'];
  if (items is! List) return const [];
  return items
      .map((item) => '${_formatAmount(_itemQuantity(item))} × ${_itemName(item)}')
      .take(3)
      .toList();
}

class StorePreparingOrdersScreen extends StatelessWidget {
  final String restaurantId;

  const StorePreparingOrdersScreen({super.key, required this.restaurantId});

  Future<void> _markReady(String orderId, bool hasAssignedDriver) async {
    await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'readyByRestaurant': true,
      'orderStatus': hasAssignedDriver ? 'pickup_ready' : 'courier_searching',
      'status': hasAssignedDriver ? 'pickup_ready' : 'courier_searching',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppThemeArabic.storeBackground,
        appBar: AppBar(
          title: const Text('الطلبات قيد التجهيز'),
          centerTitle: true,
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .where('restaurantId', isEqualTo: restaurantId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final orders = (snapshot.data?.docs ?? []).where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return _preparingStatuses.contains(_getOrderStatus(data));
            }).toList();

            if (orders.isEmpty) {
              return const Center(
                child: Text('لا توجد طلبات قيد التجهيز حالياً'),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final doc = orders[index];
                final data = doc.data() as Map<String, dynamic>;
                final assignedDriverId =
                    (data['assignedDriverId'] ?? '').toString().trim();
                final hasAssignedDriver = assignedDriverId.isNotEmpty;
                final receivable = _storeReceivable(data);
                final discount = _storeDiscountAmount(data);
                final itemCount =
                    data['items'] is List ? (data['items'] as List).length : 0;
                final itemSummary = _itemSummaryLines(data);
                final totalQuantity = data['items'] is List
                    ? (data['items'] as List)
                        .fold<num>(0, (sum, item) => sum + _itemQuantity(item))
                    : 0;
                final itemNotes = _itemNotesSummary(data);
                final orderCode = formatUnifiedOrderCode(
                  orderNumber: data['orderNumber'],
                  orderId: data['orderId'],
                  docId: doc.id,
                );

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color:
                          AppThemeArabic.storePrimary.withValues(alpha: 0.12),
                    ),
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
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppThemeArabic.storePrimary
                                  .withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.inventory_2_outlined,
                              color: AppThemeArabic.storePrimary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  orderCode,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'تفاصيل التحضير فقط - بيانات العميل مخفية',
                                  style: TextStyle(
                                    color: AppThemeArabic.storeTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _MetaChip(
                              icon: Icons.shopping_bag_outlined,
                              label:
                                  '$itemCount أصناف / ${_formatAmount(totalQuantity)} قطعة',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _MetaChip(
                              icon: Icons.payments_outlined,
                              label: '${_formatAmount(receivable)} ج.س',
                            ),
                          ),
                        ],
                      ),
                      if (discount > 0) ...[
                        const SizedBox(height: 8),
                        _MetaChip(
                          icon: Icons.local_offer_outlined,
                          label:
                              'بعد خصم ممول من المتجر ${_formatAmount(discount)} ج.س',
                        ),
                      ],
                      if (itemSummary.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppThemeArabic.storeBackground,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ملخص الأصناف',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppThemeArabic.storeTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...itemSummary.map(
                                (line) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(line),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (itemNotes.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppThemeArabic.storeAccent
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.sticky_note_2_outlined,
                                    size: 18,
                                    color: AppThemeArabic.storeAccent,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'ملاحظات الأصناف',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppThemeArabic.storeTextPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ...itemNotes.map(
                                (note) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    note,
                                    style: const TextStyle(
                                      color: AppThemeArabic.storeTextPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () async {
                            await _markReady(doc.id, hasAssignedDriver);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  hasAssignedDriver
                                      ? 'تم تجهيز الطلب وإشعار المندوب'
                                      : 'تم تجهيز الطلب وسيستمر البحث عن مندوب',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.check_circle_outline_rounded),
                          label: Text(
                            hasAssignedDriver
                                ? 'تأكيد الجاهزية للاستلام'
                                : 'جاهز ومتابعة البحث عن مندوب',
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppThemeArabic.storeBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppThemeArabic.storePrimary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
