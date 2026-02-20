/// إدارة الطلبات: اعتماد، إسناد، إكمال، وإلغاء.
import 'package:cloud_firestore/cloud_firestore.dart';

class OrdersManagerArabic {
  OrdersManagerArabic._();
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// اعتماد الطلب من المتجر.
  static Future<void> approveByRestaurant(String orderId) async {
    await _db.collection('orders').doc(orderId).update({
      'status': 'قيد التجهيز',
    });
  }

  /// انتقال المندوب إلى العميل مع إسناد المندوب.
  static Future<void> driverGoToClient(String orderId, String driverId) async {
    await _db.collection('orders').doc(orderId).update({
      'status': 'قيد التوصيل',
      'assignedDriverId': driverId,
    });
  }

  /// إكمال عملية التوصيل.
  static Future<void> driverCompleteDelivery(String orderId) async {
    await _db.collection('orders').doc(orderId).update({
      'status': 'تم التوصيل',
    });
  }

  /// إلغاء الطلب مع سبب اختياري.
  static Future<void> cancelOrder(String orderId, {String? reason}) async {
    await _db.collection('orders').doc(orderId).update({
      'status': 'ملغي',
      if (reason != null) 'cancelReason': reason,
    });
  }
}
