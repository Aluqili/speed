import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';
import 'package:speedstar_core/speedstar_core.dart' show formatUnifiedOrderCode;
import 'store_order_details_screen.dart';

const Set<String> _newStoreStatuses = {
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
  return AppThemeArabic.clientPrimary;
}

class StoreCurrentOrdersScreen extends StatelessWidget {
  final String restaurantId;
  const StoreCurrentOrdersScreen({super.key, required this.restaurantId});

  num _resolveDisplayedTotal(Map<String, dynamic> data) {
    final total = (data['total'] as num?) ?? 0;
    final deliveryFee = (data['deliveryFee'] as num?) ?? 0;
    final largeOrderFee = (data['largeOrderFee'] as num?) ?? 0;
    return (data['totalWithDelivery'] as num?) ??
        (total + deliveryFee + largeOrderFee);
  }

  Widget _sectionHeader(String title, int count, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppThemeArabic.clientPrimary),
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
    );
  }

  Widget _orderTile(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final orderId = doc.id;
    final status = _getOrderStatus(data);
    final clientName = data['clientName'] ?? 'عميل';
    final total = _resolveDisplayedTotal(data);
    final unifiedOrderCode = formatUnifiedOrderCode(
      orderNumber: data['orderNumber'],
      orderId: data['orderId'],
      docId: orderId,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: ListTile(
        title: Text(
          unifiedOrderCode,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Tajawal',
          ),
        ),
        subtitle: Text(
          'العميل: $clientName • الإجمالي: $total ج.س',
          style: const TextStyle(fontFamily: 'Tajawal'),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
        backgroundColor: AppThemeArabic.clientBackground,
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
