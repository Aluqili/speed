import 'address_selection_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:badges/badges.dart' as badges;

import 'client_home_tab.dart';
import 'client_orders_tab.dart';
import 'client_account_tab.dart';
import 'client_cart_screen.dart';
import 'cart_provider.dart';
import 'client_favorites_tab.dart';

class ClientHomeScreen extends StatefulWidget {
  final String clientId;

  const ClientHomeScreen({Key? key, required this.clientId}) : super(key: key);

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  int _selectedIndex = 0;
  DateTime? _lastBackPressed;
  bool _openAddressOnStart = true;
  bool _showFavoritesTab = true;
  bool _showCartBadge = true;
  Color _accentColor = const Color(0xFFF57C00);

  @override
  void initState() {
    super.initState();
    _loadRemoteConfig();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      Provider.of<CartProvider>(context, listen: false).initialize();
      if (_openAddressOnStart) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AddressSelectionScreen(
              userId: widget.clientId,
              userType: 'client',
              isSelecting: true,
            ),
          ),
        );
      }
    });
  }

  Future<void> _loadRemoteConfig() async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.fetchAndActivate();
      setState(() {
        _openAddressOnStart = rc.getBool('client_home_open_address_on_start');
        _showFavoritesTab = rc.getBool('client_home_show_favorites');
        _showCartBadge = rc.getBool('client_home_show_cart_badge');
        final hex = rc.getString('client_home_nav_accent_hex');
        final parsed = _parseColorHex(hex);
        if (parsed != null) _accentColor = parsed;
      });
    } catch (_) {
      // استخدم القيم الافتراضية
    }
  }

  Color? _parseColorHex(String hex) {
    final h = hex.trim();
    if (h.isEmpty) return null;
    var c = h.replaceAll('#', '');
    if (c.length == 6) c = 'FF$c';
    if (c.length == 8) {
      try {
        final v = int.parse(c, radix: 16);
        return Color(v);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      // تأكد أن كل تبويب ملفوف بـ SafeArea لمنع أي overflow
      SafeArea(child: ClientHomeTab(clientId: widget.clientId)),
      SafeArea(child: ClientOrdersTab(clientId: widget.clientId)),
      SafeArea(
          child: _showFavoritesTab
              ? ClientFavoritesTab(clientId: widget.clientId)
              : Center(child: Text('المفضلة موقوفة مؤقتًا'))),
      SafeArea(child: ClientAccountTab(clientId: widget.clientId)),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          final now = DateTime.now();
          if (_lastBackPressed == null ||
              now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
            _lastBackPressed = now;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('اضغط مرة أخرى للخروج')),
            );
            return;
          }
          SystemNavigator.pop();
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          // حذف السهم من الأعلى بعدم وضع AppBar نهائياً
          body: pages[_selectedIndex],
          floatingActionButton: Consumer<CartProvider>(
            builder: (context, cartProvider, _) {
              return badges.Badge(
                position: badges.BadgePosition.topEnd(top: -4, end: -4),
                showBadge: _showCartBadge && cartProvider.cartItems.isNotEmpty,
                badgeContent: Text(
                  cartProvider.cartItems.length.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                badgeStyle: const badges.BadgeStyle(
                  badgeColor: Colors.red,
                  padding: EdgeInsets.all(5),
                ),
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: FloatingActionButton(
                    backgroundColor: Colors.white,
                    elevation: 4,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ClientCartScreen(),
                        ),
                      );
                    },
                    child: Icon(
                      Icons.shopping_basket_rounded,
                      color: _accentColor,
                      size: 24,
                    ),
                  ),
                ),
              );
            },
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: SafeArea(
            child: BottomAppBar(
              shape: const CircularNotchedRectangle(),
              notchMargin: 4.0,
              color: Colors.white,
              elevation: 10,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home_rounded,
                      label: 'الرئيسية',
                      isActive: _selectedIndex == 0,
                      onTap: () => _onItemTapped(0),
                    ),
                    _buildNavItem(
                      icon: Icons.list_alt_outlined,
                      activeIcon: Icons.list_alt_rounded,
                      label: 'طلباتي',
                      isActive: _selectedIndex == 1,
                      onTap: () => _onItemTapped(1),
                    ),
                    const SizedBox(width: 32),
                    _buildNavItem(
                      icon: Icons.favorite_border,
                      activeIcon: Icons.favorite,
                      label: 'المفضلة',
                      isActive: _selectedIndex == 2,
                      onTap: () => _onItemTapped(2),
                    ),
                    _buildNavItem(
                      icon: Icons.person_outline,
                      activeIcon: Icons.person_rounded,
                      label: 'حسابي',
                      isActive: _selectedIndex == 3,
                      onTap: () => _onItemTapped(3),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? activeIcon : icon,
            size: 22,
            color: isActive ? _accentColor : Colors.grey[600],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isActive ? _accentColor : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
