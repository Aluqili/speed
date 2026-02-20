import 'package:cloud_firestore/cloud_firestore.dart';

/// خدمة أعلام الميزات (Feature Flags): تفعيل/إيقاف الأقسام والميزات سحابياً.
class FeatureFlagsServiceArabic {
  final FirebaseFirestore _db;
  Map<String, dynamic> _flags = const {};

  FeatureFlagsServiceArabic({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  /// تحميل الأعلام من مسار `config/feature_flags` (وثيقة مفاتيح/قيم).
  Future<void> load() async {
    try {
      final doc = await _db.collection('config').doc('feature_flags').get();
      if (doc.exists) {
        _flags = doc.data() ?? {};
      }
    } catch (_) {
      _flags = const {};
    }
  }

  /// التحقق من تفعيل علم محدد.
  bool isEnabled(String key, {bool defaultValue = false}) {
    final v = _flags[key];
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) return v.toLowerCase() == 'true';
    return defaultValue;
  }

  /// قراءة قيمة عامة (قد تكون نص/رقم/منطقي).
  T? get<T>(String key) {
    final v = _flags[key];
    return v is T ? v : null;
  }
}
