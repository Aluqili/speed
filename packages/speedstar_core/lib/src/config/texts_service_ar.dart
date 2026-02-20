import 'package:cloud_firestore/cloud_firestore.dart';

/// خدمة النصوص الديناميكية: تعديل أي نص سحابياً بدون تحديث المتجر.
class TextsServiceArabic {
  final FirebaseFirestore _db;
  Map<String, Map<String, String>> _texts = const {};

  TextsServiceArabic({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  /// يُتوقع مخطط الوثيقة: { 'ar': {key: text}, 'en': {key: text} }
  Future<void> load() async {
    try {
      final doc = await _db.collection('config').doc('texts').get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        _texts = {
          for (final entry in data.entries)
            entry.key: Map<String, String>.from(entry.value as Map)
        };
      }
    } catch (_) {
      _texts = const {};
    }
  }

  /// الحصول على نص بحسب المفتاح واللغة.
  String getText(String key, {String lang = 'ar', String fallback = ''}) {
    final byLang = _texts[lang];
    if (byLang == null) return fallback;
    return byLang[key] ?? fallback;
  }
}
