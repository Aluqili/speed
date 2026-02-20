import 'package:cloud_firestore/cloud_firestore.dart';

class PromocodeService {
  // إضافة رمز ترويجي جديد من لوحة تحكم الأدمن
  Future<void> addPromocodeByAdmin({
    required String code,
    required String discountType, // 'percent' أو 'fixed'
    required num discountValue,
    required bool isActive,
    required DateTime expiryDate,
    String? restaurantId,
    num? minOrder,
    int? maxUsage,
    int? maxUsagePerUser,
    String? itemName,
    bool onlyForNewOrders = false,
  }) async {
    await _col.add({
      'code': code,
      'discountType': discountType,
      'discountValue': discountValue,
      'isActive': isActive,
      'expiryDate': Timestamp.fromDate(expiryDate),
      'restaurantId': restaurantId ?? '',
      'minOrder': minOrder,
      'maxUsage': maxUsage,
      'maxUsagePerUser': maxUsagePerUser,
      'createdBy': 'admin',
      'usedCount': 0,
      'usersUsed': {},
      if (itemName != null && itemName.isNotEmpty) 'itemName': itemName,
      'onlyForNewOrders': onlyForNewOrders,
    });
  }
  final _col = FirebaseFirestore.instance.collection('promocodes');

  // التحقق من صلاحية الرمز
  Future<Map<String, dynamic>?> validatePromocode({
    required String code,
    required String userId,
    required num orderTotal,
    required String restaurantId,
  }) async {
    final snap = await _col.where('code', isEqualTo: code).limit(1).get();
    if (snap.docs.isEmpty) return null;
    final promo = snap.docs.first.data();

    // تحقق من التفعيل وتاريخ الانتهاء
    if (!(promo['isActive'] ?? false)) return null;
    final expiry = promo['expiryDate'];
    if (expiry != null && expiry is Timestamp && expiry.toDate().isBefore(DateTime.now())) return null;

    // تحقق من المطعم إذا كان العرض خاص
    if (promo['restaurantId'] != null && promo['restaurantId'] != '' && promo['restaurantId'] != restaurantId) return null;

    // تحقق من الحد الأدنى للطلب
    if (promo['minOrder'] != null && orderTotal < promo['minOrder']) return null;

    // تحقق من عدد مرات الاستخدام الكلي
    if (promo['maxUsage'] != null && promo['usedCount'] != null && promo['usedCount'] >= promo['maxUsage']) return null;

    // تحقق من عدد مرات الاستخدام لكل مستخدم
    if (promo['maxUsagePerUser'] != null && promo['usersUsed'] != null) {
      final userUsed = promo['usersUsed'][userId] ?? 0;
      if (userUsed >= promo['maxUsagePerUser']) return null;
    }

    return promo;
  }

  // تحديث عدد مرات الاستخدام
  Future<void> incrementUsage(String code, String userId) async {
    final snap = await _col.where('code', isEqualTo: code).limit(1).get();
    if (snap.docs.isEmpty) return;
    final doc = snap.docs.first;
    final data = doc.data();
    final usedCount = (data['usedCount'] ?? 0) + 1;
    final usersUsed = Map<String, int>.from(data['usersUsed'] ?? {});
    usersUsed[userId] = (usersUsed[userId] ?? 0) + 1;
    await doc.reference.update({
      'usedCount': usedCount,
      'usersUsed': usersUsed,
    });
  }

  // إضافة رمز جديد (للاستخدام في لوحة التحكم)
  Future<void> addPromocode(Map<String, dynamic> promo) async {
    await _col.add(promo);
  }
}