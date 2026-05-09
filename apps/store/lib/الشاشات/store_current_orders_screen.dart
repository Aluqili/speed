import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';
import 'package:speedstar_core/speedstar_core.dart' show formatUnifiedOrderCode;
import 'store_order_details_screen.dart';

const Set<String> _newStoreStatuses = {
  'payment_review',
  'store_pending',
  'courier_searching',
  'courier_offer_pending',
  'courier_assigned',
  'pickup_ready',
  'قيد المراجعة',
  'قيد التجهيز',
  'جاهز للتوصيل',
  'بانتظار المطعم',
  'انتظار الدفع',
};

const Set<String> _finishedStoreStatuses = {
  'picked_up',
  'arrived_to_client',
  'delivered',
  'store_rejected',
  'cancelled',
  'وصل إلى العميل',
  'تم التوصيل',
  'ملغي',
};

String _getOrderStatus(Map<String, dynamic> data) {
  return (data['orderStatus'] ?? data['status'] ?? '').toString().trim();
}

String _displayOrderStatus(String status) {
  switch (status) {
    case 'store_pending':
      return 'قيد المراجعة';
    case 'payment_review':
      return 'بانتظار مراجعة الدفع';
    case 'courier_searching':
      return 'جاري البحث عن مندوب';
    case 'courier_offer_pending':
      return 'بانتظار رد المندوب';
    case 'courier_assigned':
      return 'تم تعيين مندوب';
    case 'pickup_ready':
      return 'جاهز للاستلام';
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

DateTime _extractOrderDate(DocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>;
  final ts = data['createdAt'];
  if (ts is Timestamp) return ts.toDate();
  return DateTime.fromMillisecondsSinceEpoch(0);
}

Color _statusColor(String status) {
  if (status == 'store_rejected' || status == 'cancelled' || status == 'ملغي') {
    return Colors.red;
  }
  if (_finishedStoreStatuses.contains(status)) return Colors.green;
  if (status == 'pickup_ready' || status == 'جاهز للتوصيل') {
    return Colors.blueGrey;
  }
  if (status == 'payment_review' || status == 'انتظار الدفع') {
    return Colors.orange;
  }
  return AppThemeArabic.storePrimary;
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
  final discountAmount = _storeDiscountAmount(data);
  final net = subtotal - discountAmount;
  return net < 0 ? 0 : net;
}

class StoreCurrentOrdersScreen extends StatelessWidget {
  final String restaurantId;
  const StoreCurrentOrdersScreen({super.key, required this.restaurantId});

  Widget _sectionHeader(String title, int count, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppThemeArabic.storePrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppThemeArabic.storePrimary),
          const SizedBox(width: 8),
          Text(
            '$title ($count)',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontFamily: 'Tajawal',
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderTile(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final orderId = doc.id;
    final status = _getOrderStatus(data);
    final receivable = _storeReceivable(data);
    final hasStoreDiscount = _storeDiscountAmount(data) > 0;
    final unifiedOrderCode = formatUnifiedOrderCode(
      orderNumber: data['orderNumber'],
      orderId: data['orderId'],
      docId: orderId,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _statusColor(status).withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StoreOrderDetailsScreen(orderData: {
                'docId': orderId,
                ...data,
              }),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _statusColor(status).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child:
                        Icon(Icons.receipt_long, color: _statusColor(status)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          unifiedOrderCode,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Tajawal',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasStoreDiscount
                              ? 'صافي المتجر بعد الخصم'
                              : 'مستحق المتجر من هذا الطلب',
                          style: const TextStyle(
                              color: AppThemeArabic.storeTextSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _displayOrderStatus(status),
                      style: TextStyle(
                        color: _statusColor(status),
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppThemeArabic.storeBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.payments_outlined, size: 18),
                    const SizedBox(width: 8),
                    Text('المستحق ${_formatAmount(receivable)} ج.س'),
                    const Spacer(),
                    const Icon(Icons.chevron_left),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyBox(String text) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.grey, fontFamily: 'Tajawal'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppThemeArabic.storeBackground,
        appBar: AppBar(
          title: const Text('الطلبات الحالية'),
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
            final allDocs = (snapshot.data?.docs ?? []).toList()
              ..sort((a, b) =>
                  _extractOrderDate(b).compareTo(_extractOrderDate(a)));

            final newDocs = allDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return _newStoreStatuses.contains(_getOrderStatus(data));
            }).toList();

            final finishedDocs = allDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final status = _getOrderStatus(data);
              return _finishedStoreStatuses.contains(status) ||
                  (!_newStoreStatuses.contains(status) && status.isNotEmpty);
            }).toList();

            if (newDocs.isEmpty && finishedDocs.isEmpty) {
              return const Center(child: Text('لا توجد طلبات حالياً'));
            }

            return Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      _summaryCard(
                          'طلبات جديدة',
                          '${newDocs.length}',
                          AppThemeArabic.storePrimary,
                          Icons.local_fire_department_outlined),
                      const SizedBox(width: 10),
                      _summaryCard('منتهية', '${finishedDocs.length}',
                          Colors.green, Icons.check_circle_outline),
                      const SizedBox(width: 10),
                      _summaryCard('كل الطلبات', '${allDocs.length}',
                          Colors.orange, Icons.receipt_long),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _sectionHeader(
                      'الطلبات الجديدة', newDocs.length, Icons.fiber_new),
                  const SizedBox(height: 8),
                  Expanded(
                    child: newDocs.isEmpty
                        ? _emptyBox('لا توجد طلبات جديدة الآن')
                        : ListView.builder(
                            itemCount: newDocs.length,
                            itemBuilder: (context, index) =>
                                _orderTile(context, newDocs[index]),
                          ),
                  ),
                  const SizedBox(height: 10),
                  _sectionHeader(
                    'الطلبات المنتهية من منظور المتجر',
                    finishedDocs.length,
                    Icons.check_circle_outline,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: finishedDocs.isEmpty
                        ? _emptyBox('لا توجد طلبات منتهية بعد')
                        : ListView.builder(
                            itemCount: finishedDocs.length,
                            itemBuilder: (context, index) =>
                                _orderTile(context, finishedDocs[index]),
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
