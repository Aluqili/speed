import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:badges/badges.dart' as badges;
import 'package:speedstar_core/speedstar_core.dart' show LoginScreenArabic;

import 'client_home_tab.dart';
import 'client_orders_tab.dart';
import 'client_account_tab.dart';
import 'client_cart_screen.dart';
import 'cart_provider.dart';
import 'client_order_tracking_screen.dart';
import 'client_rewards_screen.dart';
import '../الخدمات/unread_messages_service.dart';
import '../الثيم/client_theme.dart';
import '../مكونات/gradient_background.dart';
import '../مكونات/glass_card.dart';

class ClientHomeScreen extends StatefulWidget {
  final String clientId;
  const ClientHomeScreen({super.key, required this.clientId});

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  DateTime? _lastBackPressed;
  bool _startupHandled = false;

  Map<String, dynamic>? _activeOrder;
  String? _activeOrderId;

  static const _activeStatuses = {
    'payment_review', 'store_pending', 'courier_searching',
    'courier_offer_pending', 'courier_assigned', 'pickup_ready', 'picked_up',
    'arrived_to_client', 'قيد المراجعة', 'قيد التجهيز', 'قيد التوصيل',
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
        final s = (doc.data()['orderStatus'] as String? ??
            doc.data()['status'] as String? ?? '');
        return _activeStatuses.contains(s);
      }).toList()
        ..sort((a, b) {
          final at = (a.data()['createdAt'] as Timestamp?)
                  ?.millisecondsSinceEpoch ?? 0;
          final bt = (b.data()['createdAt'] as Timestamp?)
                  ?.millisecondsSinceEpoch ?? 0;
          return bt.compareTo(at);
        });
      setState(() {
        _activeOrderId = active.isEmpty ? null : active.first.id;
        _activeOrder   = active.isEmpty ? null : active.first.data();
      });
    });
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      ClientHomeTab(clientId: widget.clientId),
      _isGuest
          ? const _GuestLockedTab(
              title: 'طلباتك تحتاج تسجيل الدخول',
              subtitle: 'سجل دخولك لمتابعة طلباتك الحالية والسابقة.',
            )
          : ClientOrdersTab(clientId: widget.clientId),
      _isGuest
          ? const _GuestLockedTab(
              title: 'المكافآت مرتبطة بحسابك',
              subtitle: 'سجل دخولك لمتابعة نقاطك ومكافآتك.',
            )
          : ClientRewardsScreen(clientId: widget.clientId),
      ClientAccountTab(clientId: widget.clientId),
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
              SnackBar(
                content: const Text('اضغط مرة أخرى للخروج'),
                backgroundColor: ClientColors.surface,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            );
            return;
          }
          SystemNavigator.pop();
        },
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: Colors.transparent,
          ),
          child: Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            extendBody: true,
            body: GradientBackground(
              child: Column(
                children: [
                  if (_activeOrder != null && _activeOrderId != null)
                    SafeArea(
                      bottom: false,
                      child: _ActiveOrderBanner(
                        orderId: _activeOrderId!,
                        orderData: _activeOrder!,
                        onTap: () {
                          final s = _activeOrder!['orderStatus'] as String? ??
                              _activeOrder!['status'] as String? ?? '';
                          final canTrack = {'courier_assigned',
                              'pickup_ready', 'picked_up', 'arrived_to_client',
                              'قيد التوصيل'}.contains(s);
                          if (canTrack) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ClientOrderTrackingScreen(
                                    orderId: _activeOrderId!),
                              ),
                            );
                          } else {
                            _onItemTapped(1);
                          }
                        },
                      ),
                    ),
                  Expanded(child: pages[_selectedIndex]),
                ],
              ),
            ),

            bottomNavigationBar: _GlassBottomNav(
              selectedIndex: _selectedIndex,
              clientId: widget.clientId,
              onTap: _onItemTapped,
              onCartTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ClientCartScreen()),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── شريط التنقل السفلي الزجاجي ──────────────────────────────────────────────

class _GlassBottomNav extends StatelessWidget {
  const _GlassBottomNav({
    required this.selectedIndex,
    required this.clientId,
    required this.onTap,
    required this.onCartTap,
  });

  final int selectedIndex;
  final String clientId;
  final ValueChanged<int> onTap;
  final VoidCallback onCartTap;

  static const _items = [
    (icon: Icons.home_outlined,          activeIcon: Icons.home_rounded,           label: 'الرئيسية'),
    (icon: Icons.receipt_long_outlined,  activeIcon: Icons.receipt_long_rounded,   label: 'طلباتي'),
    (icon: Icons.star_border_rounded,    activeIcon: Icons.star_rounded,           label: 'مكافآت'),
    (icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded,         label: 'حسابي'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0x22FF6B00) : const Color(0x14000000),
          ),
        ),
        boxShadow: isDark
            ? const []
            : const [
                BoxShadow(
                  color: Color(0x10000000),
                  blurRadius: 12,
                  offset: Offset(0, -2),
                ),
              ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
          child: Row(
                  children: [
                    Expanded(child: _item(context, _items[0], 0, isDark: isDark)),
                    Expanded(child: _item(context, _items[1], 1, isDark: isDark)),
                    // زر السلة في المنتصف
                    Consumer<CartProvider>(
                      builder: (_, cart, __) => GestureDetector(
                        onTap: onCartTap,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: badges.Badge(
                            position:
                                badges.BadgePosition.topEnd(top: -6, end: -6),
                            showBadge: cart.cartItems.isNotEmpty,
                            badgeContent: Text(
                              '${cart.cartItems.length}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800),
                            ),
                            badgeStyle: const badges.BadgeStyle(
                              badgeColor: ClientColors.error,
                              padding: EdgeInsets.all(4),
                            ),
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: ClientColors.primary,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: ClientColors.glowShadow(
                                    opacity: 0.45, blur: 16),
                              ),
                              child: const Icon(Icons.shopping_basket_rounded,
                                  color: Colors.white, size: 24),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(child: _item(context, _items[2], 2, isDark: isDark)),
                    Expanded(
                      child: StreamBuilder<int>(
                        stream: clientId.isNotEmpty
                            ? UnreadMessagesService.unreadSupportStream(
                                clientId)
                            : Stream.value(0),
                        builder: (_, snap) =>
                            _item(context, _items[3], 3, badge: snap.data ?? 0, isDark: isDark),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context,
    ({IconData icon, IconData activeIcon, String label}) item,
    int index, {
    int badge = 0,
    required bool isDark,
  }) {
    final active = selectedIndex == index;
    final inactiveColor = isDark
        ? Colors.white.withValues(alpha: 0.45)
        : const Color(0xFF7A7A7A);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: active
                      ? ClientColors.primary.withValues(alpha: 0.20)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: ClientColors.primary.withValues(alpha: 0.25),
                            blurRadius: 12,
                          )
                        ]
                      : null,
                ),
                child: Icon(
                  active ? item.activeIcon : item.icon,
                  size: 22,
                  color: active
                      ? ClientColors.primary
                      : inactiveColor,
                ),
              ),
              if (badge > 0)
                Positioned(
                  top: -4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: ClientColors.error,
                      borderRadius: BorderRadius.circular(8),
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
          const SizedBox(height: 2),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            style: TextStyle(
              fontSize: 10,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active
                  ? ClientColors.primary
                  : inactiveColor,
            ),
            child: Text(item.label),
          ),
        ],
      ),
    );
  }
}

// ─── تاب مقفل للضيف ─────────────────────────────────────────────────────────

class _GuestLockedTab extends StatelessWidget {
  const _GuestLockedTab({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: GlowGlassCard(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: ClientColors.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: ClientColors.primary.withValues(alpha: 0.40),
                      ),
                    ),
                    child: const Icon(
                      Icons.lock_person_rounded,
                      color: ClientColors.primary,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: ClientColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: ClientColors.textSecondary,
                      height: 1.55,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LoginScreenArabic(
                            allowRegister: true,
                            allowGoogleSignIn: false,
                            allowPhoneSignIn: false,
                            allowGuestSignIn: false,
                          ),
                        ),
                      ),
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: ClientColors.primary,
                          boxShadow: ClientColors.glowShadow(),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.login_rounded, color: Colors.white),
                            SizedBox(width: 10),
                            Text(
                              'تسجيل الدخول',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
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

// ─── بانر الطلب النشط ────────────────────────────────────────────────────────

class _ActiveOrderBanner extends StatefulWidget {
  const _ActiveOrderBanner({
    required this.orderId,
    required this.orderData,
    required this.onTap,
  });

  final String orderId;
  final Map<String, dynamic> orderData;
  final VoidCallback onTap;

  @override
  State<_ActiveOrderBanner> createState() => _ActiveOrderBannerState();
}

class _ActiveOrderBannerState extends State<_ActiveOrderBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  static const _steps = [
    (label: 'دفع',     icon: Icons.payment_rounded),
    (label: 'تجهيز',   icon: Icons.restaurant_rounded),
    (label: 'مندوب',   icon: Icons.person_search_rounded),
    (label: 'توصيل',   icon: Icons.delivery_dining_rounded),
    (label: 'وصل',     icon: Icons.location_on_rounded),
  ];

  static const _statusLabels = {
    'payment_review':    'قيد مراجعة الدفع',
    'store_pending':     'جاري التجهيز',
    'courier_searching': 'نبحث عن مندوب',
    'courier_offer_pending': 'بانتظار رد المندوب',
    'courier_assigned':  'المندوب في الطريق',
    'pickup_ready':      'الطلب جاهز للاستلام',
    'picked_up':         'المندوب يحمل طلبك',
    'arrived_to_client': 'المندوب وصل إليك',
    'قيد المراجعة':     'قيد المراجعة',
    'قيد التجهيز':      'جاري التجهيز',
    'قيد التوصيل':      'في الطريق إليك',
  };

  int _stepIndex(String s) {
    if (s == 'payment_review') return 0;
    if (s == 'store_pending' || s == 'قيد المراجعة' || s == 'قيد التجهيز') return 1;
    if (s == 'courier_searching' || s == 'courier_offer_pending') return 2;
    if ({'courier_assigned', 'pickup_ready', 'picked_up', 'قيد التوصيل'}.contains(s)) return 3;
    if (s == 'arrived_to_client') return 4;
    return 1;
  }

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.orderData['orderStatus'] as String? ??
        widget.orderData['status'] as String? ?? '';
    final restaurant = (widget.orderData['restaurantName'] ?? 'مطعم').toString();
    final stepIdx = _stepIndex(status);
    final label = _statusLabels[status] ?? status;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
        decoration: BoxDecoration(
          color: ClientColors.primary,
          borderRadius: BorderRadius.circular(20),
          boxShadow: ClientColors.glowShadow(opacity: 0.45, blur: 20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Top row ─────────────────────────────────────────────────
            Row(
              children: [
                // Pulsing live dot
                FadeTransition(
                  opacity: _pulseAnim,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(color: Color(0x66FFFFFF), blurRadius: 6),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Restaurant + status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        restaurant,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        label,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                // Track button
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.50)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'تتبع',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios_rounded,
                          color: Colors.white, size: 10),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // ── Step progress ────────────────────────────────────────────
            Row(
              children: List.generate(_steps.length * 2 - 1, (i) {
                if (i.isOdd) {
                  final lineIdx = i ~/ 2;
                  final done = lineIdx < stepIdx;
                  return Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      height: 2,
                      decoration: BoxDecoration(
                        color: done
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  );
                }
                final idx = i ~/ 2;
                final done = idx < stepIdx;
                final active = idx == stepIdx;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: active ? 26 : 18,
                  height: active ? 26 : 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active
                        ? Colors.white
                        : done
                            ? Colors.white.withValues(alpha: 0.80)
                            : Colors.white.withValues(alpha: 0.25),
                    boxShadow: active
                        ? [
                            const BoxShadow(
                              color: Color(0x55FFFFFF),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    _steps[idx].icon,
                    size: active ? 13 : 9,
                    color: active
                        ? ClientColors.primary
                        : done
                            ? ClientColors.primary.withValues(alpha: 0.80)
                            : Colors.white.withValues(alpha: 0.60),
                  ),
                );
              }),
            ),
            const SizedBox(height: 5),
            // ── Step labels ──────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(_steps.length, (i) {
                final active = i == stepIdx;
                return Expanded(
                  child: Text(
                    _steps[i].label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: active
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.55),
                      fontSize: 9,
                      fontWeight:
                          active ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
