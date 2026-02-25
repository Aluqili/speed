import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';
import 'store_order_details_screen.dart';

const Set<String> _activeStoreStatuses = {
  'store_pending',
  'courier_searching',
  'courier_offer_pending',
  'courier_assigned',
  'pickup_ready',
  'picked_up',
  'arrived_to_client',
  'قيد المراجعة',
  'قيد التجهيز',
  'قيد التوصيل',
  'بانتظار المطعم',
  'انتظار الدفع',
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
      return 'تم الاستلام من المطعم';
    case 'arrived_to_client':
      return 'وصل المندوب للعميل';
    case 'delivered':
      return 'تم التوصيل';
    case 'store_rejected':
      return 'مرفوض من المتجر';
    case 'cancelled':
      return 'ملغي';
    default:
      return status.isEmpty ? '—' : status;
  }
}

class StoreCurrentOrdersScreen extends StatelessWidget {
  final String restaurantId;
  const StoreCurrentOrdersScreen({super.key, required this.restaurantId});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppThemeArabic.clientBackground,
        appBar: AppBar(
          title: const Text('الطلبات الحالية', style: TextStyle(color: AppThemeArabic.clientPrimary, fontWeight: FontWeight.bold, fontSize: 20, fontFamily: 'Tajawal')),
          backgroundColor: Colors.white,
          centerTitle: true,
          elevation: 1,
          iconTheme: const IconThemeData(color: AppThemeArabic.clientPrimary),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
          ),
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
            final docs = (snapshot.data?.docs ?? []).where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return _activeStoreStatuses.contains(_getOrderStatus(data));
            }).toList()
              ..sort((a, b) {
                final ta = (a['createdAt'] as Timestamp?);
                final tb = (b['createdAt'] as Timestamp?);
                if (ta != null && tb != null) return tb.compareTo(ta);
                return 0;
              });

            if (docs.isEmpty) {
              return const Center(child: Text('لا توجد طلبات حالياً'));
            }
            return ListView.separated(
              itemCount: docs.length,
              separatorBuilder: (_, __) => const Divider(height: 0),
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final orderId = docs[index].id;
                final status = _displayOrderStatus(_getOrderStatus(data));
                final clientName = data['clientName'] ?? 'عميل';
                final total = data['total'] ?? 0;
                return ListTile(
                  title: Text('طلب $orderId — $clientName'),
                  subtitle: Text('الحالة: $status — الإجمالي: $total'),
                  trailing: const Icon(Icons.chevron_left),
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
                );
              },
            );
          },
        ),
      ),
    );
  }
}
