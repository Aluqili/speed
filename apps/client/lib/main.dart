import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:speedstar_core/speedstar_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:provider/provider.dart';
import 'package:speedstar_core/src/config/remote_helpers.dart';
import 'الشاشات/client_home_screen.dart';
import 'الشاشات/cart_provider.dart' as client_cart;
import 'package:speedstar_core/src/auth/login_gate.dart';

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
      await rc.setDefaults(const {
        'client_maintenance_mode': false,
        'client_maintenance_message': 'التطبيق تحت الصيانة. حاول لاحقًا.',
      });
      await rc.fetchAndActivate();
      final accent = rc.getString('accent_seed');
      _maintenanceMode = rc.getBool('client_maintenance_mode');
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
            signedIn: const _ClientHomeByAuthUser(),
          ),
        );
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
          content: Text(widget.message, maxLines: 1, overflow: TextOverflow.ellipsis),
          duration: const Duration(seconds: 3),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _ClientHomeByAuthUser extends StatelessWidget {
  const _ClientHomeByAuthUser();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return ClientHomeScreen(clientId: user.uid);
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
