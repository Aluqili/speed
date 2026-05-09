import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:speedstar_core/speedstar_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'firebase_options.dart' as dev_firebase;
import 'firebase_options_prod.dart' as prod_firebase;
import 'الشاشات/client_home_screen.dart';
import 'الشاشات/cart_provider.dart' as client_cart;
import 'الخدمات/push_notification_service.dart';
import 'الثيم/client_theme.dart';
import 'الخدمات/theme_provider.dart';

void main() {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  binding.deferFirstFrame();
  runApp(const ClientApp());
}

class ClientApp extends StatefulWidget {
  const ClientApp({super.key});
  @override
  State<ClientApp> createState() => _ClientAppState();
}

class _ClientAppState extends State<ClientApp> {
  final _themeProvider = ThemeProvider();

  @override
  void initState() {
    super.initState();
    _themeProvider.load();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<client_cart.CartProvider>(
          create: (_) => client_cart.CartProvider()..initialize(),
        ),
        ChangeNotifierProvider<ThemeProvider>.value(value: _themeProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) => MaterialApp(
          navigatorKey: PushNotificationService.navigatorKey,
          title: 'SpeedStar Client',
          theme: ClientAppTheme.light,
          darkTheme: ClientAppTheme.dark,
          themeMode: theme.mode,
          home: const _InitGateClient(),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}

class _InitGateClient extends StatefulWidget {
  const _InitGateClient();
  @override
  State<_InitGateClient> createState() => _InitGateClientState();
}

class _InitGateClientState extends State<_InitGateClient> {
  static const String _firebaseEnv =
      String.fromEnvironment('FIREBASE_ENV', defaultValue: 'dev');

  late Future<void> _initFuture;
  bool _maintenanceMode = false;
  // ignore: unused_field
  bool _clientPhoneSignInEnabled = false;
  String _maintenanceMessage = 'التطبيق تحت الصيانة. حاول لاحقًا.';
  bool _forceUpdateRequired = false;
  String _forceUpdateMessage =
      'يتوفر إصدار أحدث من التطبيق لتحسين الأداء والاستقرار. الرجاء التحديث للمتابعة.';
  String _updateUrl = '';
  int _currentBuildNumber = 0;
  int _minBuildNumber = 0;
  bool _firstFrameAllowed = false;

  @override
  void initState() {
    super.initState();
    _initFuture = _safeInit();
  }

  Future<void> _safeInit() async {
    final startedAt = DateTime.now();
    try {
      final firebaseOptions = _firebaseEnv == 'prod'
          ? prod_firebase.DefaultFirebaseOptions.currentPlatform
          : dev_firebase.DefaultFirebaseOptions.currentPlatform;
      await Firebase.initializeApp(options: firebaseOptions);

      // تهيئة الإشعارات في الخلفية — لا تعيق التحميل
      unawaited(PushNotificationService.instance.initialize().catchError((_) {}));

      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 4),
          minimumFetchInterval: Duration.zero,
        ),
      );
      final defaults = <String, Object>{
        ...OpsRuntimeConfig.defaultFlagsFor('client'),
        ...AppUpdateConfig.defaultFlagsFor('client'),
        'accent_seed': 'E85D2A',
        'client_maintenance_mode': false,
        'client_maintenance_message': 'التطبيق تحت الصيانة. حاول لاحقًا.',
        'client_phone_signin_enabled_sudan': false,
        'client_home_open_address_on_start': true,
        'client_home_show_favorites': true,
        'client_home_show_cart_badge': true,
        'client_home_nav_accent_hex': 'E85D2A',
        'client_state_guard_distance_km': 120.0,
        'client_state_rollout_enabled': true,
        'client_enabled_states_csv': 'khartoum',
        'client_state_rollout_block_message':
            'لسه ما جيناكم في الولاية يا غالي\nتابعنا على منصات التواصل عشان تعرف حنجيكم متين\nوقريباً حنصلكم.. انتظرونا! ❤️',
        'pricing_large_item_fee_enabled': true,
        'pricing_large_item_threshold': 10000.0,
        'pricing_large_item_fee_base': 500.0,
        'pricing_large_item_step_amount': 5000.0,
        'pricing_large_item_step_fee': 500.0,
        'pricing_large_item_fee_cap_per_unit': 2500.0,
        'pricing_client_delivery_base_fee': 5000.0,
        'pricing_client_delivery_base_distance_km': 6.0,
        'pricing_client_delivery_extra_per_km': 700.0,
        'pricing_delivery_platform_margin_fixed': 700.0,
        'pricing_delivery_platform_min_margin': 300.0,
      };
      await rc.setDefaults(defaults);
      // استخدام القيم المخزنة فوراً ثم جلب الجديدة في الخلفية
      await rc.activate();
        unawaited(rc.fetchAndActivate().catchError((_) => false));
      final accent = rc.getString('accent_seed');
      _maintenanceMode = rc.getBool('client_maintenance_mode');
      _clientPhoneSignInEnabled =
          rc.getBool('client_phone_signin_enabled_sudan');
      final update = await AppUpdateConfig.fromRemoteConfig(
        rc,
        appKey: 'client',
      );
      _forceUpdateRequired = update.forceUpdateRequired;
      _forceUpdateMessage = update.message;
      _updateUrl = update.updateUrl;
      _currentBuildNumber = update.currentBuildNumber;
      _minBuildNumber = update.minBuildNumber;
      final maintenanceText = rc.getString('client_maintenance_message').trim();
      if (maintenanceText.isNotEmpty) {
        _maintenanceMessage = maintenanceText;
      }
      if (accent.isNotEmpty) {
        final seed = parseColorHex(accent);
        ThemeController.instance.setAccentSeed(seed);
      }
    } catch (e) {
      debugPrint('Firebase init failed: $e');
    } finally {
      if (!_firstFrameAllowed) {
        final elapsed = DateTime.now().difference(startedAt);
        const minimumSplashTime = Duration(milliseconds: 900);
        if (elapsed < minimumSplashTime) {
          await Future.delayed(minimumSplashTime - elapsed);
        }
        _firstFrameAllowed = true;
        WidgetsBinding.instance.allowFirstFrame();
      }
    }
  }

  // تم نقل تحليل اللون إلى الحزمة المشتركة عبر parseColorHex

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
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
        return const _ClientHomeEntryPoint();
      },
    );
  }
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
          content: Text(widget.message,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          duration: const Duration(seconds: 3),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _ClientHomeEntryPoint extends StatelessWidget {
  const _ClientHomeEntryPoint();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ClientHomeScreen(
            clientId: FirebaseAuth.instance.currentUser?.uid ?? '',
          );
        }

        final user = snapshot.data;
        final isSignedIn = user != null && !user.isAnonymous;
        if (isSignedIn) {
          unawaited(PushNotificationService.instance.bindClient(user.uid));
        }

        return ClientHomeScreen(clientId: isSignedIn ? user.uid : '');
      },
    );
  }
}

class ClientShellArabic extends StatefulWidget {
  const ClientShellArabic({super.key, required this.appConfig});
  final AppConfig appConfig;

  @override
  State<ClientShellArabic> createState() => _ClientShellArabicState();
}

class _ClientShellArabicState extends State<ClientShellArabic> {
  int _index = 0;

  late final AppConfig _homeConfig = widget.appConfig;

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return RemoteViewArabic(appConfig: _homeConfig);
      case 1:
        return const _OrdersPageArabic();
      case 2:
        return const _AccountPageArabic();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _index == 0
              ? 'الرئيسية'
              : _index == 1
                  ? 'الطلبات'
                  : 'الحساب',
        ),
        actions: const [_SettingsAction()],
      ),
      body: _buildPage(_index),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'الطلبات',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'الحساب',
          ),
        ],
        onDestinationSelected: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _SettingsAction extends StatelessWidget {
  const _SettingsAction();
  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.settings),
      onPressed: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ClientSettingsScreen())),
    );
  }
}

class ClientSettingsScreen extends StatelessWidget {
  const ClientSettingsScreen({super.key});
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

class _OrdersPageArabic extends StatelessWidget {
  const _OrdersPageArabic();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'قائمة الطلبات',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          Text('سيتم تحميل الطلبات من السحابة قريبًا.'),
        ],
      ),
    );
  }
}

class _AccountPageArabic extends StatelessWidget {
  const _AccountPageArabic();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الحساب',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          Text('معلومات الحساب وتسجيل الدخول قادمة ضمن الحزمة المشتركة.'),
        ],
      ),
    );
  }
}
