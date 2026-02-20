import 'package:cloud_firestore/cloud_firestore.dart';

class OrderService {
  static Future<void> approveByRestaurant(String orderId) async {
    await FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .update({'status': 'قيد التجهيز'});
  }
}
