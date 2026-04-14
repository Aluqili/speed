import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:speedstar_core/speedstar_core.dart';
import 'package:speedstar_core/src/config/remote_helpers.dart'
    as remote_helpers;
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'firebase_options.dart' as dev_firebase;
import 'firebase_options_prod.dart' as prod_firebase;
import 'الشاشات/client_home_screen.dart';
import 'الشاشات/cart_provider.dart' as client_cart;
import 'الخدمات/push_notification_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ClientApp());
}

class ClientApp extends StatelessWidget {
  const ClientApp({super.key});

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
                : AppThemeArabic.clientTheme;
            final darkTheme = seed != null
                ? AppThemeArabic.fromSeed(seed, dark: true)
                : AppThemeArabic.clientDarkTheme;
            return ChangeNotifierProvider<client_cart.CartProvider>(
              child: MaterialApp(
                title: 'SpeedStar Client',
                theme: theme,
                darkTheme: darkTheme,
                themeMode: mode,
                home: const _InitGateClient(),
              ),
              create: (_) => client_cart.CartProvider()..initialize(),
            );
          },
        );
      },
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
  bool _clientPhoneSignInEnabled = false;
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
      await rc.fetchAndActivate();
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
        final seed = remote_helpers.parseColorHex(accent);
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
            title: 'SpeedStar',
            subtitle: 'جاهزين نوصلك أسرع 🚀',
            imageAsset: 'assets/branding/app_icon_client.png.jpeg',
            accent: AppThemeArabic.clientPrimary,
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
        return const _ClientHomeEntryPoint();
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
                    fontSize: 34,
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
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        final isSignedIn = user != null && !user.isAnonymous;
        if (isSignedIn) {
          unawaited(PushNotificationService.instance.bindClient(user.uid));
        }

        return ClientHomeScreen(clientId: isSignedIn ? user!.uid : '');
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
