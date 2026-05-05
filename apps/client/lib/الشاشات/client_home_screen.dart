import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:badges/badges.dart' as badges;
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';
import 'package:speedstar_core/src/auth/login_screen_ar.dart';

import 'client_home_tab.dart';
import 'client_orders_tab.dart';
import 'client_account_tab.dart';
import 'client_cart_screen.dart';
import 'cart_provider.dart';
import 'client_favorites_tab.dart';
import 'client_order_tracking_screen.dart';
import '../الخدمات/unread_messages_service.dart';

class ClientHomeScreen extends StatefulWidget {
  final String clientId;

  const ClientHomeScreen({Key? key, required this.clientId}) : super(key: key);

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  DateTime? _lastBackPressed;
  bool _showCartBadge = true;
  Color _accentColor = AppThemeArabic.clientPrimary;
  bool _startupHandled = false;

  Map<String, dynamic>? _activeOrder;
  String? _activeOrderId;

  static const _activeStatuses = {
    'payment_review',
    'store_pending',
    'courier_searching',
    'courier_assigned',
    'pickup_ready',
    'picked_up',
    'arrived_to_client',
    'قيد المراجعة',
    'قيد التجهيز',
    'قيد التوصيل',
  };

  bool get _isGuest => widget.clientId.trim().isEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleStartup());
  }

  Future<void> _handleStartup() async {
    if (_startupHandled || !mounted) return;
    _startupHandled = true;
    Provider.of<CartProvider>(context, listen: false).initialize();
    await _loadRemoteConfig();
    _listenActiveOrder();
  }

  void _listenActiveOrder() {
    final uid = widget.clientId.trim();
    if (uid.isEmpty) return;
    FirebaseFirestore.instance
        .collection('orders')
        .where('clientId', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final active = snap.docs.where((doc) {
        final data = doc.data();
        final status =
            (data['orderStatus'] as String? ?? data['status'] as String? ?? '');
        return _activeStatuses.contains(status);
      }).toList();
      active.sort((a, b) {
        final at =
            (a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final bt =
            (b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        return bt.compareTo(at);
      });
      setState(() {
        if (active.isEmpty) {
          _activeOrder = null;
          _activeOrderId = null;
        } else {
          _activeOrderId = active.first.id;
          _activeOrder = active.first.data();
        }
      });
    });
  }

  Future<void> _loadRemoteConfig() async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.fetchAndActivate();
      setState(() {
        _showCartBadge = rc.getBool('client_home_show_cart_badge');
        final hex = rc.getString('client_home_nav_accent_hex');
        final parsed = _parseColorHex(hex);
        if (parsed != null) _accentColor = parsed;
      });
    } catch (_) {}
  }

  Color? _parseColorHex(String hex) {
    final h = hex.trim();
    if (h.isEmpty) return null;
    var c = h.replaceAll('#', '');
    if (c.length == 6) c = 'FF$c';
    if (c.length == 8) {
      try {
        return Color(int.parse(c, radix: 16));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      SafeArea(child: ClientHomeTab(clientId: widget.clientId)),
      SafeArea(
        child: _isGuest
            ? const _GuestLockedTab(
                title: 'طلباتك تحتاج تسجيل الدخول',
                subtitle: 'سجل دخولك لمتابعة الطلبات الحالية والسابقة.',
              )
            : ClientOrdersTab(clientId: widget.clientId),
      ),
      SafeArea(
        child: _isGuest
            ? const _GuestLockedTab(
                title: 'المفضلة مرتبطة بحسابك',
                subtitle: 'سجل دخولك للاحتفاظ بالمطاعم والوجبات المفضلة.',
              )
            : ClientFavoritesTab(clientId: widget.clientId),
      ),
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
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
          ),
          child: Scaffold(
            backgroundColor: AppThemeArabic.clientBackground,
            extendBody: true,
            body: Column(
              children: [
                if (_activeOrder != null && _activeOrderId != null)
                  _ActiveOrderBanner(
                    orderId: _activeOrderId!,
                    orderData: _activeOrder!,
                    accentColor: _accentColor,
                  ),
                Expanded(child: pages[_selectedIndex]),
              ],
            ),

            // ─── FAB السلة ──────────────────────────────────────────────
            floatingActionButton: Consumer<CartProvider>(
              builder: (context, cart, _) {
                return SizedBox(
                  width: 58,
                  height: 58,
                  child: badges.Badge(
                    position: badges.BadgePosition.topEnd(top: -4, end: -4),
                    showBadge: _showCartBadge && cart.cartItems.isNotEmpty,
                    badgeContent: Text(
                      cart.cartItems.length.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    badgeStyle: const badges.BadgeStyle(
                      badgeColor: Color(0xFFFF3B30),
                      padding: EdgeInsets.all(5),
                    ),
                    child: FloatingActionButton(
                      backgroundColor: _accentColor,
                      foregroundColor: Colors.white,
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ClientCartScreen()),
                      ),
                      child: const Icon(
                        Icons.shopping_basket_rounded,
                        size: 26,
                      ),
                    ),
                  ),
                );
              },
            ),
            floatingActionButtonLocation:
                FloatingActionButtonLocation.centerDocked,

            // ─── شريط التنقل السفلي ──────────────────────────────────────
            bottomNavigationBar: _BottomNav(
              selectedIndex: _selectedIndex,
              accentColor: _accentColor,
              clientId: widget.clientId,
              onTap: _onItemTapped,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── شريط التنقل المخصص ─────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.selectedIndex,
    required this.accentColor,
    required this.clientId,
    required this.onTap,
  });

  final int selectedIndex;
  final String clientId;
  final Color accentColor;
  final ValueChanged<int> onTap;

  static const _items = [
    (icon: Icons.home_outlined,       activeIcon: Icons.home_rounded,          label: 'الرئيسية'),
    (icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long_rounded, label: 'طلباتي'),
    (icon: Icons.favorite_border,     activeIcon: Icons.favorite_rounded,       label: 'المفضلة'),
    (icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded,      label: 'حسابي'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 30,
              spreadRadius: 0,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: accentColor.withValues(alpha: 0.06),
              blurRadius: 20,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              // الزر الأول + الثاني
              Expanded(child: _navItem(_items[0], 0)),
              Expanded(child: _navItem(_items[1], 1)),
              // مساحة FAB
              const SizedBox(width: 64),
              // الثالث + الرابع
              Expanded(child: _navItem(_items[2], 2)),
              // تاب الحساب مع شارة رسائل الدعم
              Expanded(
                child: StreamBuilder<int>(
                  stream: clientId.isNotEmpty
                      ? UnreadMessagesService.unreadSupportStream(clientId)
                      : Stream.value(0),
                  builder: (context, snap) =>
                      _navItem(_items[3], 3, badge: snap.data ?? 0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    ({IconData icon, IconData activeIcon, String label}) item,
    int index, {
    int badge = 0,
  }) {
    final isActive = selectedIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: isActive
                        ? accentColor.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isActive ? item.activeIcon : item.icon,
                    size: 22,
                    color: isActive ? accentColor : const Color(0xFFAEAEB2),
                  ),
                ),
                if (badge > 0)
                  Positioned(
                    top: -4,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        badge > 9 ? '9+' : '$badge',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight:
                    isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? accentColor : const Color(0xFFAEAEB2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── تاب القفل للضيوف ────────────────────────────────────────────────────────

class _GuestLockedTab extends StatelessWidget {
  const _GuestLockedTab({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    const primary = AppThemeArabic.clientPrimary;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppThemeArabic.clientBackground,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFECE8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.lock_person_rounded,
                        color: primary,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppThemeArabic.clientTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppThemeArabic.clientTextSecondary,
                        height: 1.55,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginScreenArabic(
                                allowRegister: true,
                                allowGoogleSignIn: false,
                                allowPhoneSignIn: false,
                                allowGuestSignIn: false,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.login_rounded),
                        label: const Text('تسجيل الدخول'),
                      ),
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
}

// ─── بانر الطلب النشط ────────────────────────────────────────────────────────

class _ActiveOrderBanner extends StatelessWidget {
  const _ActiveOrderBanner({
    required this.orderId,
    required this.orderData,
    required this.accentColor,
  });

  final String orderId;
  final Map<String, dynamic> orderData;
  final Color accentColor;

  String _statusLabel(String status) {
    const map = {
      'payment_review':    'قيد مراجعة الدفع',
      'store_pending':     'بانتظار قبول المتجر',
      'courier_searching': 'جاري البحث عن مندوب',
      'courier_assigned':  'المندوب في الطريق إليك',
      'pickup_ready':      'الطلب جاهز للاستلام',
      'picked_up':         'المندوب استلم طلبك',
      'arrived_to_client': 'المندوب وصل إليك',
      'قيد المراجعة':      'قيد المراجعة',
      'قيد التجهيز':       'قيد التجهيز',
      'قيد التوصيل':       'في الطريق إليك',
    };
    return map[status] ?? status;
  }

  bool get _canTrack {
    final status =
        orderData['orderStatus'] as String? ?? orderData['status'] as String? ?? '';
    return ['courier_assigned', 'pickup_ready', 'picked_up', 'arrived_to_client',
      'قيد التوصيل'].contains(status);
  }

  IconData get _statusIcon {
    final status =
        orderData['orderStatus'] as String? ?? orderData['status'] as String? ?? '';
    if (status == 'payment_review' || status == 'قيد المراجعة') {
      return Icons.access_time_rounded;
    }
    if (status == 'store_pending' || status == 'قيد التجهيز') {
      return Icons.restaurant_rounded;
    }
    if (status == 'courier_searching') return Icons.search_rounded;
    return Icons.delivery_dining_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final status =
        orderData['orderStatus'] as String? ?? orderData['status'] as String? ?? '';
    final restaurant = (orderData['restaurantName'] ?? 'مطعم').toString();
    final label = _statusLabel(status);

    return GestureDetector(
      onTap: () {
        if (_canTrack) {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ClientOrderTrackingScreen(orderId: orderId)),
          );
        } else {
          final homeState =
              context.findAncestorStateOfType<_ClientHomeScreenState>();
          homeState?._onItemTapped(1);
        }
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              accentColor,
              accentColor.withValues(alpha: 0.85),
            ],
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Row(
              children: [
                // أيقونة الحالة
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_statusIcon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                // نص الحالة
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'طلب نشط · $restaurant',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // زر التتبع
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _canTrack ? 'تتبع' : 'عرض',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_ios_rounded,
                          color: Colors.white, size: 11),
                    ],
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
