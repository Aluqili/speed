import 'package:cloud_firestore/cloud_firestore.dart';
import 'order_workflow_models_ar.dart';

/// خدمة دورة الطلب السحابية: تُحمّل مخطط الانتقالات وتتعامل مع طلبات الانتقال.
/// يُنصح بتنفيذ التحقق الحقيقي في Cloud Functions لضمان الأمان.
class OrderWorkflowServiceArabic {
  final FirebaseFirestore _db;
  List<TransitionSpecArabic> _transitions = const [];

  OrderWorkflowServiceArabic({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  /// يُتوقع الوثيقة: { transitions: [ {action, from, to, allowedRoles: []}, ... ] }
  Future<void> load() async {
    try {
      final doc = await _db.collection('workflows').doc('orders').get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        final list = List<Map<String, dynamic>>.from(data['transitions'] ?? []);
        _transitions = list.map(TransitionSpecArabic.fromJson).toList();
      }
    } catch (_) {
      _transitions = const [];
    }
  }

  /// العثور على انتقال بحسب الإجراء.
  TransitionSpecArabic? findByAction(String action) {
    try {
      return _transitions.firstWhere((t) => t.action == action);
    } catch (_) {
      return null;
    }
  }

  /// العثور على انتقال بحسب الإجراء + الحالة الحالية.
  TransitionSpecArabic? findByActionFrom(String action, String from) {
    try {
      return _transitions.firstWhere(
        (t) => t.action == action && t.from == from,
      );
    } catch (_) {
      return null;
    }
  }

  /// طلب انتقال (يُسجّل في مجموعة requests ليتعامل معها Cloud Functions).
  Future<void> requestTransition({
    required String orderId,
    required String action,
    required String actorRole,
    required String actorId,
    String? currentStatus,
  }) async {
    final spec = currentStatus == null
        ? findByAction(action)
        : findByActionFrom(action, currentStatus);
    if (spec == null) {
      throw Exception('Transition not found');
    }
    if (!spec.allowedRoles.contains(actorRole)) {
      throw Exception('Role not allowed for this action');
    }
    await _db.collection('orderTransitionRequests').add({
      'orderId': orderId,
      'action': action,
      'from': spec.from,
      'to': spec.to,
      'actorRole': actorRole,
      'actorId': actorId,
      if (currentStatus != null) 'currentStatus': currentStatus,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
