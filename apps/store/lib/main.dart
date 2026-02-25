import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:speedstar_core/src/config/remote_helpers.dart';
import 'package:speedstar_core/speedstar_core.dart';
import 'package:speedstar_core/src/auth/login_gate.dart';
import 'package:speedstar_core/src/auth/login_screen_ar.dart';
import 'الشاشات/store_home_screen.dart';
import 'الشاشات/store_link_request_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StoreApp());
}

class StoreApp extends StatelessWidget {
  const StoreApp({super.key});

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
                : AppThemeArabic.storeTheme;
            final darkTheme = seed != null
                ? AppThemeArabic.fromSeed(seed, dark: true)
                : AppThemeArabic.storeDarkTheme;
            return MaterialApp(
              title: 'SpeedStar Store',
              theme: theme,
              darkTheme: darkTheme,
              themeMode: mode,
              home: const _InitGate(),
            );
          },
        );
      },
    );
  }
}

class _InitGate extends StatefulWidget {
  const _InitGate();
  @override
  State<_InitGate> createState() => _InitGateState();
}

class _InitGateState extends State<_InitGate> {
  late Future<void> _initFuture;
  bool _maintenanceMode = false;
  String _maintenanceMessage = 'التطبيق تحت الصيانة. حاول لاحقًا.';

  @override
  void initState() {
    super.initState();
    _initFuture = _safeInit();
  }

  Future<void> _safeInit() async {
    try {
      await Firebase.initializeApp();
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: Duration.zero,
        ),
      );
      final defaults = <String, Object>{
        ...OpsRuntimeConfig.defaultFlagsFor('store'),
        'accent_seed': 'E85D2A',
        'store_maintenance_mode': false,
        'store_maintenance_message': 'التطبيق تحت الصيانة. حاول لاحقًا.',
      };
      await rc.setDefaults(defaults);
      await rc.fetchAndActivate();
      final accent = rc.getString('accent_seed');
      _maintenanceMode = rc.getBool('store_maintenance_mode');
      final maintenanceText = rc.getString('store_maintenance_message').trim();
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
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (_maintenanceMode) {
          return _MaintenanceScreen(message: _maintenanceMessage);
        }
        return LoginGate(
          unauthenticatedBuilder: (_) => const _StoreUnauthenticatedScreen(),
          signedIn: ChangeNotifierProvider(
            create: (_) => CartProvider(),
            child: const _StoreHomeByAuthUser(),
          ),
        );
      },
    );
  }
}

class _StoreUnauthenticatedScreen extends StatelessWidget {
  const _StoreUnauthenticatedScreen();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('متجر SpeedStar')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'مرحبًا بك في تطبيق المتجر',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'إذا لديك حساب متجر ادخل مباشرة، أو أنشئ طلب متجر جديد لإرساله للإدارة.',
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
                            builder: (_) => const StoreLinkRequestScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.store),
                      label: const Text('إنشاء حساب متجر جديد'),
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

class _StoreHomeByAuthUser extends StatelessWidget {
  const _StoreHomeByAuthUser();

  Future<Map<String, dynamic>?> _resolveRestaurant(User user) async {
    final restaurants = FirebaseFirestore.instance.collection('restaurants');
    final applications = FirebaseFirestore.instance.collection('restaurantApplications');

    final direct = await restaurants.doc(user.uid).get();
    if (direct.exists) {
      final data = direct.data() ?? {};
      final status = (data['approvalStatus'] ?? '').toString();
      final isApproved = data['isApproved'] == true;
      return {
        'id': user.uid,
        'approvalStatus': status,
        'isApproved': isApproved,
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
      final query = await restaurants
          .where(candidate.key, isEqualTo: candidate.value)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        final matched = query.docs.first;
        final data = matched.data();
        final status = (data['approvalStatus'] ?? '').toString();
        final isApproved = data['isApproved'] == true;
        return {
          'id': matched.id,
          'approvalStatus': status,
          'isApproved': isApproved,
        };
      }
    }

    final applicationDoc = await applications.doc(user.uid).get();
    if (applicationDoc.exists) {
      final data = applicationDoc.data() ?? {};
      return {
        'id': user.uid,
        'approvalStatus': data['approvalStatus'] ?? data['status'] ?? 'pending',
        'isApproved': false,
      };
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
      future: _resolveRestaurant(user),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return _MissingRestaurantScreen(
            user: user,
            title: 'تعذر التحقق من بيانات المتجر',
            message:
                'حدث خطأ أثناء تحميل بيانات المتجر. تحقق من الاتصال ثم أعد المحاولة.',
          );
        }

        final resolved = snapshot.data;
        if (resolved == null) {
          return _MissingRestaurantScreen(
            user: user,
            title: 'المتجر غير مربوط بهذا الحساب',
            message:
                'لم يتم العثور على متجر مرتبط بالحساب الحالي.\nتأكد من ربط المطعم بحقل ownerUid أو email أو userId في مجموعة restaurants.',
          );
        }

        final approvalStatus = (resolved['approvalStatus'] ?? '').toString();
        final isApproved = resolved['isApproved'] == true;
        if (approvalStatus == 'pending') {
          return _MissingRestaurantScreen(
            user: user,
            title: 'طلب المتجر قيد المراجعة',
            message: 'تم استلام طلبك وسيتم تفعيله بعد موافقة الإدارة.',
            showApplyButton: false,
          );
        }

        if (approvalStatus == 'rejected') {
          return _MissingRestaurantScreen(
            user: user,
            title: 'تم رفض الطلب السابق',
            message: 'يمكنك تعديل البيانات وإعادة إرسال طلب جديد.',
          );
        }

        if (approvalStatus != 'approved' && !isApproved) {
          return _MissingRestaurantScreen(
            user: user,
            title: 'حساب المتجر غير مفعل بعد',
            message: 'لا يمكن دخول لوحة المتجر قبل موافقة الإدارة على الطلب.',
            showApplyButton: false,
          );
        }

        return StoreHomeScreen(storeId: (resolved['id'] ?? '').toString());
      },
    );
  }
}

class _MissingRestaurantScreen extends StatelessWidget {
  const _MissingRestaurantScreen({
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
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.store_mall_directory_outlined,
                  size: 56, color: Colors.deepOrange),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 18),
              if (showApplyButton)
                ElevatedButton.icon(
                  onPressed: () async {
                    final sent = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StoreLinkRequestScreen(
                          userId: user.uid,
                          email: user.email ?? '',
                        ),
                      ),
                    );
                    if (sent == true && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('تم إرسال الطلب، سيتم مراجعته من الإدارة'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.store),
                  label: const Text('إنشاء/إعادة إرسال طلب متجر'),
                ),
              if (showApplyButton) const SizedBox(height: 10),
              ElevatedButton.icon(
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

class StoreSettingsScreen extends StatelessWidget {
  const StoreSettingsScreen({super.key});
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
