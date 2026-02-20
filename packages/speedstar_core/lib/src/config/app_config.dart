import 'dart:convert';
import 'package:http/http.dart' as http;

/// إعدادات التطبيق لقراءة عرض SDUI عن بُعد أو استخدام بديل محلي.
class AppConfig {
  final Uri? remoteViewUrl;
  final String? fallbackViewJson;

  const AppConfig({this.remoteViewUrl, this.fallbackViewJson});

  Future<Map<String, dynamic>> loadView() async {
    if (remoteViewUrl != null) {
      try {
        final res = await http.get(remoteViewUrl!);
        if (res.statusCode == 200) {
          return json.decode(res.body) as Map<String, dynamic>;
        }
      } catch (_) {}
    }
    if (fallbackViewJson != null) {
      return json.decode(fallbackViewJson!) as Map<String, dynamic>;
    }
    return {
      'nodes': [
        {'type': 'text', 'text': 'تعذر تحميل الصفحة'},
        {'type': 'spacer', 'height': 8},
        {'type': 'text', 'text': 'تحقق من الاتصال أو الرابط'},
      ],
    };
  }
}
