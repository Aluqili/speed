import 'package:cloud_firestore/cloud_firestore.dart';

class OrderService {
  OrderService._();
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<void> approveByRestaurant(String orderId) async {
    await _db.collection('orders').doc(orderId).update({
      'status': 'قيد التجهيز',
    });
  }

  static Future<void> driverGoToClient(String orderId, String driverId) async {
    await _db.collection('orders').doc(orderId).update({
      'status': 'قيد التوصيل',
      'assignedDriverId': driverId,
    });
  }

  static Future<void> driverCompleteDelivery(String orderId) async {
    await _db.collection('orders').doc(orderId).update({
      'status': 'تم التوصيل',
    });
  }

  static Future<void> cancelOrder(String orderId, {String? reason}) async {
    await _db.collection('orders').doc(orderId).update({
      'status': 'ملغي',
      if (reason != null) 'cancelReason': reason,
    });
  }
}
