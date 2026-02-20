import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:speedstar_core/speedstar_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:speedstar_core/src/config/remote_helpers.dart';
import 'package:speedstar_core/src/auth/login_gate.dart';
import 'الشاشات/courier_main_screen.dart';

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
      await rc.setDefaults(const {'courier_root_url': ''});
      await rc.setDefaults(const {
        'courier_maintenance_mode': false,
        'courier_maintenance_message': 'التطبيق تحت الصيانة. حاول لاحقًا.',
      });
      await rc.fetchAndActivate();
      final accent = rc.getString('accent_seed');
      _maintenanceMode = rc.getBool('courier_maintenance_mode');
      final maintenanceText = rc.getString('courier_maintenance_message').trim();
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
        return _ModeBanner(
          message: 'وضع الواجهة القديمة (Legacy) مُفعّل',
          child: LoginGate(
            signedIn: const _CourierHomeByAuthUser(),
          ),
        );
      },
    );
  }
}

class _CourierHomeByAuthUser extends StatelessWidget {
  const _CourierHomeByAuthUser();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return CourierMainScreen(courierId: user.uid);
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
