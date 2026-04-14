import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speedstar_core/speedstar_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:speedstar_core/src/auth/login_screen_ar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'firebase_options.dart' as dev_firebase;
import 'firebase_options_prod.dart' as prod_firebase;
import 'الشاشات/courier_main_screen.dart';
import 'الشاشات/courier_link_request_screen.dart';
import 'الخدمات/push_notification_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CourierApp());
}

class CourierApp extends StatelessWidget {
  const CourierApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeController.instance;
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeController.themeMode,
      builder: (context, mode, _) {
        return ValueListenableBuilder<Color?>(
          valueListenable: themeController.accentSeed,
          builder: (context, seed, __) {
            final theme = seed != null
                ? AppThemeArabic.fromSeed(seed)
                : AppThemeArabic.courierTheme;
            final darkTheme = seed != null
                ? AppThemeArabic.fromSeed(seed, dark: true)
                : AppThemeArabic.courierDarkTheme;
            return MaterialApp(
              title: 'SpeedStar Courier',
              theme: theme,
              darkTheme: darkTheme,
              themeMode: mode,
              home: const _InitGateCourier(),
            );
          },
        );
      },
    );
  }
}

class _InitGateCourier extends StatefulWidget {
  const _InitGateCourier();
  @override
  State<_InitGateCourier> createState() => _InitGateCourierState();
}

class _InitGateCourierState extends State<_InitGateCourier> {
  static const String _firebaseEnv =
      String.fromEnvironment('FIREBASE_ENV', defaultValue: 'dev');

  late Future<void> _initFuture;
  bool _maintenanceMode = false;
  String _maintenanceMessage = 'التطبيق تحت الصيانة. حاول لاحقًا.';
  bool _forceUpdateRequired = false;
  String _forceUpdateMessage =
      'يتوفر إصدار أحدث من التطبيق لتحسين الأداء والاستقرار. الرجاء التحديث للمتابعة.';
  String _updateUrl = '';
  int _currentBuildNumber = 0;
  int _minBuildNumber = 0;

  @override
  void initState() {
    super.initState();
    _initFuture = _safeInit();
  }

  Future<void> _safeInit() async {
    try {
      final firebaseOptions = _firebaseEnv == 'prod'
          ? prod_firebase.DefaultFirebaseOptions.currentPlatform
          : dev_firebase.DefaultFirebaseOptions.currentPlatform;
      await Firebase.initializeApp(
        options: firebaseOptions,
      );
      await PushNotificationService.instance.initialize();
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: Duration.zero,
        ),
      );
      final defaults = <String, Object>{
        ...OpsRuntimeConfig.defaultFlagsFor('courier'),
        ...AppUpdateConfig.defaultFlagsFor('courier'),
        'accent_seed': 'E85D2A',
        'courier_root_url': '',
        'courier_maintenance_mode': false,
        'courier_maintenance_message': 'التطبيق تحت الصيانة. حاول لاحقًا.',
        'pricing_driver_delivery_base_fee': 4000.0,
        'pricing_driver_delivery_base_distance_km': 6.0,
        'pricing_driver_delivery_extra_per_km': 500.0,
      };
      await rc.setDefaults(defaults);
      await rc.fetchAndActivate();
      final accent = rc.getString('accent_seed');
      _maintenanceMode = rc.getBool('courier_maintenance_mode');
      final update = await AppUpdateConfig.fromRemoteConfig(
        rc,
        appKey: 'courier',
      );
      _forceUpdateRequired = update.forceUpdateRequired;
      _forceUpdateMessage = update.message;
      _updateUrl = update.updateUrl;
      _currentBuildNumber = update.currentBuildNumber;
      _minBuildNumber = update.minBuildNumber;
      final maintenanceText =
          rc.getString('courier_maintenance_message').trim();
      if (maintenanceText.isNotEmpty) {
        _maintenanceMessage = maintenanceText;
      }
      if (accent.isNotEmpty) {
        final seed = parseColorHex(accent);
        ThemeController.instance.setAccentSeed(seed);
      }
    } catch (e) {
      debugPrint('Firebase init failed: $e');
    }
  }

  // تم نقل تحليل اللون إلى الحزمة المشتركة عبر parseColorHex

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _InitSplash(
            title: 'SpeedStar Courier',
            subtitle: 'انطلق بسرعة وخلك جاهز لأي طلب ⚡',
            imageAsset: 'assets/branding/app_icon_courier.png.jpeg',
            accent: Color(0xFFE85D2A),
          );
        }
        if (_maintenanceMode) {
          return _MaintenanceScreen(message: _maintenanceMessage);
        }
        if (_forceUpdateRequired) {
          return _ForceUpdateScreen(
            message: _forceUpdateMessage,
            updateUrl: _updateUrl,
            currentBuildNumber: _currentBuildNumber,
            minBuildNumber: _minBuildNumber,
            onRetry: () {
              setState(() {
                _initFuture = _safeInit();
              });
            },
          );
        }
        return LoginGate(
          unauthenticatedBuilder: (_) => const _CourierUnauthenticatedScreen(),
          signedIn: const _CourierHomeByAuthUser(),
        );
      },
    );
  }
}

class _InitSplash extends StatelessWidget {
  const _InitSplash({
    required this.title,
    required this.subtitle,
    required this.imageAsset,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final String imageAsset;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF4EE), Colors.white],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(36),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.18),
                        blurRadius: 30,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Image.asset(imageAsset, fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(
                    strokeWidth: 3.2,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CourierUnauthenticatedScreen extends StatelessWidget {
  const _CourierUnauthenticatedScreen();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('مندوب SpeedStar')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'مرحبًا بك في تطبيق المندوب',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'إذا لديك حساب مندوب ادخل مباشرة، أو أنشئ طلب حساب جديد لإرساله للإدارة.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreenArabic(
                              allowRegister: false,
                              allowGoogleSignIn: false,
                              allowPhoneSignIn: false,
                              allowGuestSignIn: false,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.login),
                      label: const Text('تسجيل الدخول'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CourierLinkRequestScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.motorcycle),
                      label: const Text('إنشاء حساب مندوب جديد'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CourierHomeByAuthUser extends StatelessWidget {
  const _CourierHomeByAuthUser();

  Future<Map<String, dynamic>?> _resolveDriver(User user) async {
    final drivers = FirebaseFirestore.instance.collection('drivers');

    final direct = await drivers.doc(user.uid).get();
    if (direct.exists) {
      final data = direct.data() ?? {};
      return {
        'id': user.uid,
        'approvalStatus': data['approvalStatus'] ?? '',
        'isApproved': data['isApproved'] == true,
      };
    }

    final candidates = <MapEntry<String, dynamic>>[
      MapEntry('ownerUid', user.uid),
      MapEntry('ownerId', user.uid),
      MapEntry('userId', user.uid),
      MapEntry('uid', user.uid),
      if ((user.email ?? '').isNotEmpty) MapEntry('email', user.email),
    ];

    for (final candidate in candidates) {
      final query = await drivers
          .where(candidate.key, isEqualTo: candidate.value)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final matched = query.docs.first;
        if (candidate.key != 'ownerUid') {
          await matched.reference
              .set({'ownerUid': user.uid}, SetOptions(merge: true));
        }
        final data = matched.data();
        return {
          'id': matched.id,
          'approvalStatus': data['approvalStatus'] ?? '',
          'isApproved': data['isApproved'] == true,
        };
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: _resolveDriver(user),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return _DriverLinkStateScreen(
            user: user,
            title: 'تعذر التحقق من بيانات المندوب',
            message: 'حدث خطأ أثناء تحميل بيانات المندوب. حاول مرة أخرى.',
          );
        }

        final resolved = snapshot.data;
        if (resolved == null) {
          return _DriverLinkStateScreen(
            user: user,
            title: 'الحساب غير مربوط بملف مندوب',
            message:
                'لم يتم العثور على ملف مندوب لهذا الحساب. يمكنك إرسال طلب إنشاء حساب مندوب.',
          );
        }

        final approvalStatus = (resolved['approvalStatus'] ?? '').toString();
        final isApproved = resolved['isApproved'] == true;

        if (approvalStatus == 'pending') {
          return _DriverLinkStateScreen(
            user: user,
            title: 'طلب المندوب قيد المراجعة',
            message: 'تم استلام طلبك وسيتم تفعيله بعد موافقة الإدارة.',
            showApplyButton: false,
          );
        }

        if (approvalStatus == 'rejected') {
          return _DriverLinkStateScreen(
            user: user,
            title: 'تم رفض الطلب السابق',
            message: 'يمكنك تعديل البيانات وإعادة إرسال طلب جديد.',
          );
        }

        if (approvalStatus == 'approved' ||
            isApproved ||
            approvalStatus.isEmpty) {
          final courierId = (resolved['id'] ?? user.uid).toString();
          unawaited(PushNotificationService.instance.bindDriver(courierId));
          return CourierMainScreen(courierId: courierId);
        }

        return _DriverLinkStateScreen(
          user: user,
          title: 'حالة الحساب غير مكتملة',
          message: 'يرجى التواصل مع الإدارة لتفعيل حساب المندوب.',
          showApplyButton: false,
        );
      },
    );
  }
}

class _DriverLinkStateScreen extends StatelessWidget {
  const _DriverLinkStateScreen({
    required this.user,
    required this.title,
    required this.message,
    this.showApplyButton = true,
  });

  final User user;
  final String title;
  final String message;
  final bool showApplyButton;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline,
                    size: 48, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                if (showApplyButton)
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CourierLinkRequestScreen(
                            userId: user.uid,
                            email: user.email,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_business),
                    label: const Text('إرسال طلب إنشاء حساب مندوب'),
                  ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('تسجيل الخروج'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeBanner extends StatefulWidget {
  const _ModeBanner({required this.child, required this.message});
  final Widget child;
  final String message;

  @override
  State<_ModeBanner> createState() => _ModeBannerState();
}

class _ModeBannerState extends State<_ModeBanner> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            widget.message,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _MaintenanceScreen extends StatelessWidget {
  const _MaintenanceScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}

class _ForceUpdateScreen extends StatelessWidget {
  const _ForceUpdateScreen({
    required this.message,
    required this.updateUrl,
    required this.currentBuildNumber,
    required this.minBuildNumber,
    required this.onRetry,
  });

  final String message;
  final String updateUrl;
  final int currentBuildNumber;
  final int minBuildNumber;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.system_update_alt_rounded, size: 42),
                      const SizedBox(height: 12),
                      const Text(
                        'يلزم تحديث التطبيق',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 15),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'إصدارك الحالي: $currentBuildNumber • الحد الأدنى المطلوب: $minBuildNumber',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                      if (updateUrl.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        SelectableText(
                          updateUrl,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final uri = Uri.tryParse(updateUrl.trim());
                            if (uri == null) return;
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          },
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: const Text('فتح رابط التحديث'),
                        ),
                      ],
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('تحقق مرة أخرى'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CourierSettingsScreen extends StatelessWidget {
  const CourierSettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = ThemeController.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ValueListenableBuilder<ThemeMode>(
        valueListenable: controller.themeMode,
        builder: (context, mode, _) {
          return ListView(
            children: [
              RadioListTile<ThemeMode>(
                title: const Text('حسب النظام'),
                value: ThemeMode.system,
                groupValue: mode,
                onChanged: (m) => controller.setThemeMode(m!),
              ),
              RadioListTile<ThemeMode>(
                title: const Text('فاتح'),
                value: ThemeMode.light,
                groupValue: mode,
                onChanged: (m) => controller.setThemeMode(m!),
              ),
              RadioListTile<ThemeMode>(
                title: const Text('داكن'),
                value: ThemeMode.dark,
                groupValue: mode,
                onChanged: (m) => controller.setThemeMode(m!),
              ),
            ],
          );
        },
      ),
    );
  }
}
