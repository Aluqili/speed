import 'package:flutter/material.dart';

/// يحوّل رابط الجذر (index.json) إلى رابط الصفحة الرئيسية (home.json)
String deriveHomeUrlFromRoot(String root) {
  final uri = Uri.tryParse(root);
  if (uri != null && uri.path.endsWith('index.json')) {
    final base = root.substring(0, root.length - 'index.json'.length);
    return '$base' 'home.json';
  }
  return root;
}

/// يحلل لون سداسي إلى Color (يدعم #RRGGBB و #AARRGGBB)
Color? parseColorHex(String s) {
  try {
    String hex = s.trim();
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (hex.length == 6) hex = 'FF' + hex;
    final val = int.parse(hex, radix: 16);
    return Color(val);
  } catch (_) {
    return null;
  }
}