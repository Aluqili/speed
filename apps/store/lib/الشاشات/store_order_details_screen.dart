import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';
import '../services/order_service.dart';
import 'store_order_actions.dart';

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
        final driversSnapshot = await FirebaseFirestore.instance
            .collection('drivers')
            .get();

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
    final clientName = orderData['clientName'] ?? 'غير معروف';
    final orderId = orderData['docId'] ?? orderData['orderId'] ?? '—';
    final status = (orderData['orderStatus'] ?? orderData['status'] ?? '').toString();
    final assignedDriverId = orderData['assignedDriverId'] as String?;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppThemeArabic.clientBackground,
        appBar: AppBar(
          title: const Text('تفاصيل الطلب', style: TextStyle(color: AppThemeArabic.clientPrimary, fontWeight: FontWeight.bold, fontSize: 20, fontFamily: 'Tajawal')),
          backgroundColor: Colors.white,
          centerTitle: true,
          elevation: 1,
          iconTheme: const IconThemeData(color: AppThemeArabic.clientPrimary),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              GFCard(
                boxFit: BoxFit.cover,
                padding: const EdgeInsets.all(16),
                elevation: 2,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📦 رقم الطلب: $orderId',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('👤 اسم العميل: $clientName',
                        style: const TextStyle(fontSize: 16)),
                    const Divider(height: 30),
                    ...items.map((item) => ListTile(
                          leading: const Icon(Icons.restaurant_menu,
                          color: AppThemeArabic.clientPrimary),
                          title: Text(item['name']),
                          subtitle: Text(
                              'الكمية: ${item['quantity']} × السعر: ${item['price']}'),

                          trailing: Text(
                              '${item['quantity'] * item['price']} ج.س'),
                        )),
                    const Divider(height: 30),
                    Text('💰 الإجمالي: $total ج.س',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (orderId != '—') StoreOrderActions(orderId: orderId),

              if (status == 'store_pending' || status == 'قيد المراجعة')
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

              if (status == 'courier_searching' ||
                  status == 'courier_offer_pending' ||
                  status == 'courier_assigned' ||
                  status == 'قيد التجهيز')
                assignedDriverId != null
                    ? GFButton(
                        onPressed: () async {
                          final docId =
                              orderData['docId'] ?? orderData['orderId'];
                          await FirebaseFirestore.instance
                              .collection('orders')
                              .doc(docId)
                              .update({
                            'readyByRestaurant': true,
                            'orderStatus': 'pickup_ready',
                            'status': 'pickup_ready',
                            'updatedAt': FieldValue.serverTimestamp(),
                          });
                          GFToast.showToast('✅ تم تجهيز الطلب', context);
                          Navigator.of(context).pop();
                        },
                        text: 'جاهز للتوصيل',
                        color: AppThemeArabic.clientPrimary,
                        fullWidthButton: true,
                      )
                    : Center(
                        child: Text('⏳ في انتظار تعيين مندوب…',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 16)),
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
