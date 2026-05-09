import 'package:cloud_firestore/cloud_firestore.dart';

/// خدمة نقاط المكافآت للعميل
class RewardsService {
  static const _pointsPerHundred = 1; // نقطة واحدة لكل 100 وحدة عملة

  /// جلب رصيد النقاط الحالي
  static Stream<int> pointsStream(String clientId) {
    return FirebaseFirestore.instance
      .collection('clients')
        .doc(clientId)
        .snapshots()
        .map((snap) => (snap.data()?['points'] as num?)?.toInt() ?? 0);
  }

  /// جلب سجل النقاط
  static Stream<List<Map<String, dynamic>>> pointsHistoryStream(
      String clientId) {
    return FirebaseFirestore.instance
        .collection('clients')
        .doc(clientId)
        .collection('pointsHistory')
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }

  /// حساب النقاط من مبلغ الطلب
  static int calculatePoints(double orderAmount) {
    return (orderAmount / 100).floor() * _pointsPerHundred;
  }

  /// قيمة النقاط كخصم (100 نقطة = 100 وحدة عملة)
  static double pointsToDiscount(int points) => points.toDouble();

  /// الحد الأدنى للاستبدال
  static const int minRedeemPoints = 100;

  /// النقاط المطلوبة للمستوى التالي
  static int nextLevelPoints(int currentPoints) {
    if (currentPoints < 500) return 500;
    if (currentPoints < 1000) return 1000;
    if (currentPoints < 2500) return 2500;
    return 5000;
  }

  /// اسم المستوى الحالي
  static String levelName(int points) {
    if (points >= 2500) return 'ذهبي';
    if (points >= 1000) return 'فضي';
    if (points >= 500) return 'برونزي';
    return 'مبتدئ';
  }
}
