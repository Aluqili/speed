import 'package:cloud_firestore/cloud_firestore.dart';

/// خدمة الأقسام: التحكم في إظهار/إخفاء أقسام التطبيق لكل دور.
class SectionsServiceArabic {
  final FirebaseFirestore _db;
  Map<String, List<String>> _sectionsByRole = const {};

  SectionsServiceArabic({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  /// يُتوقع مخطط الوثيقة: { 'client': ['home','orders'], 'courier': [...], 'store': [...] }
  Future<void> load() async {
    try {
      final doc = await _db.collection('config').doc('sections').get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        _sectionsByRole = {
          for (final entry in data.entries)
            entry.key: List<String>.from(entry.value as List)
        };
      }
    } catch (_) {
      _sectionsByRole = const {};
    }
  }

  /// الأقسام الظاهرة لدور معين.
  List<String> visibleSections(String role) {
    return _sectionsByRole[role] ?? const [];
  }

  /// هل القسم ظاهر لدور معين.
  bool isSectionVisible(String role, String section) {
    return visibleSections(role).contains(section);
  }
}
