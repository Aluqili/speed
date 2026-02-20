import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'login_screen_ar.dart';

/// بوابة بسيطة: إن لم يكن المستخدم مسجلاً، تُظهر شاشة تسجيل الدخول.
class LoginGate extends StatelessWidget {
  const LoginGate({super.key, required this.signedIn});

  final Widget signedIn;

  @override
  Widget build(BuildContext context) {
    // تأكيد تهيئة Firebase قبل الاستماع للحالة
    if (Firebase.apps.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    try {
      return StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) {
          final user = snap.data;
          if (user == null) {
            return const LoginScreenArabic();
          }
          return signedIn;
        },
      );
    } catch (_) {
      // في حال حدوث خطأ مبكر من المزود، نظهر شاشة الدخول كحل آمن
      return const LoginScreenArabic();
    }
  }
}
