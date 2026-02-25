import 'package:cloud_firestore/cloud_firestore.dart';

class OrderService {
  OrderService._();
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<void> approveByRestaurant(String orderId) async {
    await _db.collection('orders').doc(orderId).update({
      'orderStatus': 'courier_searching',
      'status': 'courier_searching',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> driverGoToClient(String orderId, String driverId) async {
    await _db.collection('orders').doc(orderId).update({
      'orderStatus': 'picked_up',
      'status': 'picked_up',
      'assignedDriverId': driverId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> driverCompleteDelivery(String orderId) async {
    await _db.collection('orders').doc(orderId).update({
      'orderStatus': 'delivered',
      'status': 'delivered',
      'deliveredAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> cancelOrder(String orderId, {String? reason}) async {
    await _db.collection('orders').doc(orderId).update({
      'orderStatus': 'cancelled',
      'status': 'cancelled',
      'updatedAt': FieldValue.serverTimestamp(),
      if (reason != null) 'cancelReason': reason,
    });
  }
}
