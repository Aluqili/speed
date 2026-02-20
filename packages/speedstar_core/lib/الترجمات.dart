/// الترجمات العامة للتطبيق (عربي/إنجليزي) مع أمثلة افتراضية.
///
/// بدون اعتماد خارجي؛ استخدم `TextsServiceArabic` للسحابة، وهذه خريطة محلية كـ fallback.
class LocalTextsArabic {
  static const Map<String, Map<String, String>> keys = {
        'ar': {
          'settings': 'الإعدادات',
          'language': 'اللغة',
          'notifications': 'الإشعارات',
          'about_app': 'حول التطبيق',
          'app_info': 'معلومات عن SpeedStar',
          'name': 'الاسم',
          'phone': 'الهاتف',
          'email': 'البريد الإلكتروني',
          'arabic': 'العربية',
          'english': 'الإنجليزية',
          'choose_language': 'اختر اللغة',
          'enable_notifications': 'تشغيل/إيقاف التنبيهات',
          'notification_on': 'تم تفعيل الإشعارات ✅',
          'notification_off': 'تم إيقاف الإشعارات ❌',
          'app_version':
              'إصدار 1.0.0\nتطبيق لتوصيل الطلبات بسرعة وكفاءة في السودان.',
          'ok': 'تم',
        },
        'en': {
          'settings': 'Settings',
          'language': 'Language',
          'notifications': 'Notifications',
          'about_app': 'About App',
          'app_info': 'About SpeedStar',
          'name': 'Name',
          'phone': 'Phone',
          'email': 'Email',
          'arabic': 'Arabic',
          'english': 'English',
          'choose_language': 'Choose Language',
          'enable_notifications': 'Enable/Disable Notifications',
          'notification_on': 'Notifications enabled ✅',
          'notification_off': 'Notifications disabled ❌',
          'app_version': 'Version 1.0.0\nA fast food delivery app for Sudan.',
          'ok': 'OK',
        },
      };

  /// جلب نص محلي بحسب المفتاح واللغة.
  static String t(String key, {String lang = 'ar', String fallback = ''}) {
    return keys[lang]?[key] ?? fallback;
  }
}
