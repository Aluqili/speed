import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
        final restaurantLat = (orderData['restaurantLat'] as num).toDouble();
        final restaurantLng = (orderData['restaurantLng'] as num).toDouble();

        // جلب جميع السائقين للتشكيل في قائمة الانتظار
        final driversSnapshot = await FirebaseFirestore.instance
            .collection('drivers')
            .get();

        List<Map<String, dynamic>> driverList = [];
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

        if (driverList.isEmpty) {
          GFToast.showToast(
            '🚫 لا يوجد سائقون للتعيين حالياً',
            context,
            toastPosition: GFToastPosition.BOTTOM,
          );
          return;
        }

        driverList.sort((a, b) => a['distance'].compareTo(b['distance']));
        final driverQueue = driverList.map((d) => d['id'] as String).toList();

        await FirebaseFirestore.instance
            .collection('orders')
            .doc(orderDocId)
            .update({
          'driverQueue': driverQueue,
        });

        // إضافة التغيير عبر الخدمة الموحدة للحالة دون تغيير المنطق القديم
        await OrderService.approveByRestaurant(orderDocId);

        Navigator.of(context).pop();
        GFToast.showToast(
          '✅ تم تحويل الطلب إلى "قيد التجهيز"',
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
    final status = orderData['status'] ?? '';
    final assignedDriverId = orderData['assignedDriverId'] as String?;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('📄 تفاصيل الطلب'),
          backgroundColor: const Color(0xFFF57C00),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              GFCard(
                padding: const EdgeInsets.all(16),
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
                              color: Color(0xFFF57C00)),
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

              if (status == 'قيد المراجعة')
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
                            .update({'status': 'ملغي'});
                        Navigator.of(context).pop();
                        GFToast.showToast('❌ تم إلغاء الطلب', context);
                      },
                      text: 'رفض الطلب',
                      color: GFColors.DANGER,
                    ),
                  ],
                ),

              if (status == 'قيد التجهيز')
                assignedDriverId != null
                    ? GFButton(
                        onPressed: () async {
                          final docId =
                              orderData['docId'] ?? orderData['orderId'];
                          await FirebaseFirestore.instance
                              .collection('orders')
                              .doc(docId)
                              .update({'readyByRestaurant': true, 'status': 'جاهز للتوصيل'});
                          GFToast.showToast('✅ تم تجهيز الطلب', context);
                          Navigator.of(context).pop();
                        },
                        text: 'جاهز للتوصيل',
                        color: const Color(0xFFF57C00),
                        fullWidthButton: true,
                      )
                    : Center(
                        child: Text('⏳ في انتظار تعيين مندوب…',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 16)),
                      ),

              if (status == 'جاهز للتوصيل')
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
