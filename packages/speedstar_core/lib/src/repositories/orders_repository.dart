import 'package:cloud_firestore/cloud_firestore.dart';

/// مستودع الطلبات: فصل الوصول لقاعدة البيانات عن واجهة المستخدم.
class OrdersRepository {
  final FirebaseFirestore _db;
  OrdersRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  Future<DocumentSnapshot<Map<String, dynamic>>> fetchById(String orderId) {
    return _db.collection('orders').doc(orderId).get();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchById(String orderId) {
    return _db.collection('orders').doc(orderId).snapshots();
  }

  Future<void> updateFields(String orderId, Map<String, dynamic> fields) async {
    await _db.collection('orders').doc(orderId).update(fields);
  }
}
