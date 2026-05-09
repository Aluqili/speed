import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:speedstar_core/speedstar_core.dart';
import 'package:speedstar_core/src/auth/login_screen_ar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'firebase_options.dart' as dev_firebase;
import 'firebase_options_prod.dart' as prod_firebase;
import 'الشاشات/store_home_screen.dart';
import 'الشاشات/store_link_request_screen.dart';
import 'الشاشات/store_notifications_screen.dart';
import 'الشاشات/store_order_details_screen.dart';
import 'الخدمات/push_notification_service.dart';

const String _firebaseEnv =
    String.fromEnvironment('FIREBASE_ENV', defaultValue: 'dev');

FirebaseOptions _resolveFirebaseOptions() {
  return _firebaseEnv == 'prod'
      ? prod_firebase.DefaultFirebaseOptions.currentPlatform
      : dev_firebase.DefaultFirebaseOptions.currentPlatform;
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: _resolveFirebaseOptions());
  if (message.notification != null) {
    return;
  }
  await PushNotificationService.instance.showRemoteMessageAsLocal(message);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
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
                ? AppThemeArabic.storeFromSeed(seed)
                : AppThemeArabic.storeTheme;
            final darkTheme = seed != null
                ? AppThemeArabic.storeFromSeed(seed, dark: true)
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
      await Firebase.initializeApp(
        options: _resolveFirebaseOptions(),
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
        ...OpsRuntimeConfig.defaultFlagsFor('store'),
        ...AppUpdateConfig.defaultFlagsFor('store'),
        'accent_seed': '0F766E',
        'store_maintenance_mode': false,
        'store_maintenance_message': 'التطبيق تحت الصيانة. حاول لاحقًا.',
      };
      await rc.setDefaults(defaults);
      await rc.fetchAndActivate();
      final accent = rc.getString('accent_seed');
      _maintenanceMode = rc.getBool('store_maintenance_mode');
      final update = await AppUpdateConfig.fromRemoteConfig(
        rc,
        appKey: 'store',
      );
      _forceUpdateRequired = update.forceUpdateRequired;
      _forceUpdateMessage = update.message;
      _updateUrl = update.updateUrl;
      _currentBuildNumber = update.currentBuildNumber;
      _minBuildNumber = update.minBuildNumber;
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
          return const _InitSplash(
            title: 'SpeedStar Store',
            subtitle: 'جاهزين لاستقبال الطلبات بقوة 🔥',
            imageAsset: 'assets/branding/app_icon_store.png.jpeg',
            accent: AppThemeArabic.storePrimary,
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
        return _NotificationPermissionGate(
          child: LoginGate(
            unauthenticatedBuilder: (_) => const _StoreUnauthenticatedScreen(),
            signedIn: ChangeNotifierProvider(
              create: (_) => CartProvider(),
              child: const _StoreHomeByAuthUser(),
            ),
          ),
        );
      },
    );
  }
}

class _NotificationPermissionGate extends StatefulWidget {
  const _NotificationPermissionGate({required this.child});

  final Widget child;

  @override
  State<_NotificationPermissionGate> createState() =>
      _NotificationPermissionGateState();
}

class _NotificationPermissionGateState
    extends State<_NotificationPermissionGate> with WidgetsBindingObserver {
  bool _checking = true;
  bool _requesting = false;
  bool _notificationsAllowed = false;

  bool get _mustEnforce {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshStatus();
    }
  }

  Future<void> _refreshStatus() async {
    if (!_mustEnforce) {
      if (!mounted) return;
      setState(() {
        _notificationsAllowed = true;
        _checking = false;
      });
      return;
    }

    final settings =
        await PushNotificationService.instance.getNotificationSettings();
    if (!mounted) return;
    setState(() {
      _notificationsAllowed =
          settings.authorizationStatus == AuthorizationStatus.authorized;
      _checking = false;
    });
  }

  Future<void> _requestNotifications() async {
    if (_requesting) return;
    setState(() => _requesting = true);
    try {
      final settings =
          await PushNotificationService.instance.requestPermission();
      if (!mounted) return;
      final isAuthorized =
          settings.authorizationStatus == AuthorizationStatus.authorized;
      setState(() {
        _notificationsAllowed = isAuthorized;
      });
      if (!isAuthorized) {
        await openAppSettings();
      }
    } finally {
      if (mounted) {
        setState(() => _requesting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const _InitSplash(
        title: 'SpeedStar Store',
        subtitle: 'جارٍ التحقق من إعدادات التنبيهات',
        imageAsset: 'assets/branding/app_icon_store.png.jpeg',
        accent: AppThemeArabic.storePrimary,
      );
    }

    if (_notificationsAllowed) {
      return widget.child;
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFF3EC), Colors.white],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: AppThemeArabic.storePrimary
                              .withValues(alpha: 0.12),
                          blurRadius: 30,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: AppThemeArabic.storePrimary
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: const Icon(
                            Icons.notifications_active_rounded,
                            color: AppThemeArabic.storePrimary,
                            size: 34,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'تفعيل الإشعارات مطلوب',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'لا يمكن استخدام تطبيق المتجر بدون إشعارات الطلبات. فعّل الإشعارات حتى تصلك الطلبات الجديدة والتنبيهات الحرجة فورًا.',
                          style: TextStyle(
                            height: 1.7,
                            color: Colors.black87,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7F2),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: AppThemeArabic.storePrimary,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'إذا كنت قد رفضت الإذن سابقًا، سيفتح التطبيق الإعدادات لتفعيله يدويًا ثم ارجع هنا مباشرة.',
                                  style: TextStyle(height: 1.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed:
                                _requesting ? null : _requestNotifications,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppThemeArabic.storePrimary,
                              minimumSize: const Size.fromHeight(54),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            icon: _requesting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.notifications_outlined),
                            label: Text(
                              _requesting
                                  ? 'جارٍ فتح الإذن أو الإعدادات...'
                                  : 'تفعيل الإشعارات الآن',
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _refreshStatus,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('تحقق مرة أخرى'),
                          ),
                        ),
                      ],
                    ),
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

  Map<String, dynamic> _resolvedPayload(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final status = (data['approvalStatus'] ?? '').toString();
    final isApproved = data['isApproved'] == true;
    return {
      'id': doc.id,
      'approvalStatus': status,
      'isApproved': isApproved,
    };
  }

  Future<Map<String, dynamic>?> _resolveRestaurantById(
      String restaurantId) async {
    final id = restaurantId.trim();
    if (id.isEmpty) return null;
    final doc = await FirebaseFirestore.instance
        .collection('restaurants')
        .doc(id)
        .get();
    if (!doc.exists) return null;
    return _resolvedPayload(doc);
  }

  Future<Map<String, dynamic>?> _resolveRestaurant(User user) async {
    final restaurants = FirebaseFirestore.instance.collection('restaurants');
    final applications =
        FirebaseFirestore.instance.collection('restaurantApplications');

    final direct = await restaurants.doc(user.uid).get();
    if (direct.exists) {
      return _resolvedPayload(direct);
    }

    final appDoc = await applications.doc(user.uid).get();
    if (appDoc.exists) {
      final appData = appDoc.data() ?? {};
      final appRestaurantId =
          (appData['restaurantId'] ?? appData['ownerUid'] ?? '').toString();
      final fromApp = await _resolveRestaurantById(appRestaurantId);
      if (fromApp != null) {
        return fromApp;
      }
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
          .get();
      if (query.docs.length == 1) {
        return _resolvedPayload(query.docs.first);
      }
      if (query.docs.length > 1) {
        final exactById =
            query.docs.where((doc) => doc.id == user.uid).toList();
        if (exactById.length == 1) {
          return _resolvedPayload(exactById.first);
        }
        return null;
      }
    }

    if (appDoc.exists) {
      final data = appDoc.data() ?? {};
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
            title: 'تعذر تحديد المتجر المرتبط بالحساب',
            message:
                'لم يتم العثور على ربط واضح لمتجر واحد فقط مع هذا الحساب.\nتأكد من أن لكل حساب متجر واحد محدد بمعرّف واضح (restaurantId/ownerUid) لتجنب فتح بيانات متجر آخر.',
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

        final storeId = (resolved['id'] ?? '').toString();
        unawaited(PushNotificationService.instance.bindStore(storeId));
        return _StoreSignedInShell(storeId: storeId);
      },
    );
  }
}

class _StoreSignedInShell extends StatefulWidget {
  const _StoreSignedInShell({required this.storeId});

  final String storeId;

  @override
  State<_StoreSignedInShell> createState() => _StoreSignedInShellState();
}

class _StoreSignedInShellState extends State<_StoreSignedInShell> {
  StreamSubscription<Map<String, dynamic>>? _tapSubscription;
  String? _lastHandledPayloadKey;

  @override
  void initState() {
    super.initState();
    _tapSubscription = PushNotificationService.instance.notificationTapStream
        .listen(_handleNotificationPayload);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending =
          PushNotificationService.instance.consumePendingTapPayload();
      if (pending != null) {
        _handleNotificationPayload(pending);
      }
    });
  }

  @override
  void dispose() {
    _tapSubscription?.cancel();
    super.dispose();
  }

  String _payloadKey(Map<String, dynamic> payload) {
    return [
      payload['orderId'] ?? '',
      payload['type'] ?? '',
      payload['title'] ?? '',
      payload['body'] ?? '',
    ].join('|');
  }

  Future<void> _handleNotificationPayload(Map<String, dynamic> payload) async {
    if (!mounted) return;
    final payloadKey = _payloadKey(payload);
    if (payloadKey == _lastHandledPayloadKey) return;
    _lastHandledPayloadKey = payloadKey;

    final orderId = (payload['orderId'] ?? '').toString().trim();
    if (orderId.isNotEmpty) {
      final orderDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .get();
      final orderData = orderDoc.data();
      final restaurantId = (orderData?['restaurantId'] ?? '').toString();
      if (!mounted) return;
      if (orderDoc.exists && restaurantId == widget.storeId) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => StoreOrderDetailsScreen(
              orderData: {
                'docId': orderDoc.id,
                ...?orderData,
              },
            ),
          ),
        );
        return;
      }
    }

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StoreNotificationsScreen(
          restaurantId: widget.storeId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StoreHomeScreen(storeId: widget.storeId);
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
