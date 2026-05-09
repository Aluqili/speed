import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../الثيم/client_theme.dart';
import '../الخدمات/theme_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speedstar_core/speedstar_core.dart' show LoginScreenArabic;

import '../الخدمات/guest_location_service.dart';
import 'client_wallet_screen.dart';
import 'client_settings_screen.dart';
import 'client_support_screen.dart';
import 'address_selection_screen.dart';

class ClientAccountTab extends StatefulWidget {
  final String clientId;

  const ClientAccountTab({super.key, required this.clientId});

  @override
  State<ClientAccountTab> createState() => _ClientAccountTabState();
}

class _ClientAccountTabState extends State<ClientAccountTab> {
  Future<void> _openLogin(BuildContext context) async {
    await Navigator.push(
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

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && !currentUser.isAnonymous) {
      await GuestLocationService.saveAsClientAddress(currentUser.uid);
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تسجيل الخروج'),
          content: const Text('هل أنت متأكد من الخروج من حسابك؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: ClientColors.error),
              child: const Text('خروج',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userType');

    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreenArabic(
          allowRegister: true,
          allowGoogleSignIn: false,
          allowPhoneSignIn: false,
          allowGuestSignIn: false,
        ),
      ),
      (route) => false,
    );
  }

  Future<void> _openSupportChat(BuildContext context) async {
    if (!context.mounted) {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientSupportScreen(userId: widget.clientId),
      ),
    );
  }

  Future<void> _saveGuestLocationToAddresses(BuildContext context) async {
    final savedAddressId = await GuestLocationService.saveAsClientAddress(
      widget.clientId,
    );
    if (!context.mounted || savedAddressId == null) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'تمت إضافة موقع التصفح الحالي إلى عناوينك واعتماده افتراضيًا.'),
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  Widget _buildItemTile(Map<String, dynamic> item) {
    const primaryColor = ClientColors.primary;
    final isLogout = item['title'] == 'تسجيل الخروج';
    final iconColor = (item['color'] as Color?) ?? primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(
          item['icon'] as IconData,
          color: iconColor,
          size: 22,
        ),
      ),
      title: Text(
        item['title'] as String,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: isLogout ? ClientColors.error : titleColor,
        ),
      ),
      subtitle: Text(
        item['subtitle'] as String,
        style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 14,
        color: isLogout
            ? ClientColors.error.withValues(alpha: 0.6)
            : (isDark
                ? ClientColors.textSecondary.withValues(alpha: 0.6)
                : const Color(0xFF9CA3AF)),
      ),
      onTap: item['onTap'] as VoidCallback,
    );
  }

  Widget _buildSection(String label, List<Map<String, dynamic>> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 4, bottom: 6, top: 2),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: ClientColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0x1AFFFFFF) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? const Color(0x1AFF6B00) : const Color(0x14000000),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                if (i > 0)
                  Divider(
                      height: 1,
                      indent: 60,
                      endIndent: 0,
                      color: isDark
                          ? const Color(0x1AFFFFFF)
                          : const Color(0xFFEDEDED)),
                _buildItemTile(items[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = ClientColors.primary;

    if (widget.clientId.isEmpty) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0x1AFFFFFF)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0x4DFF6B00)),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.15),
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
                          shape: BoxShape.circle,
                          color: const Color(0x33FF6B00),
                          border: Border.all(
                              color: const Color(0x4DFF6B00), width: 2),
                        ),
                        child: const Icon(Icons.person_rounded,
                            size: 38, color: primaryColor),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'حسابك غير مسجل بعد',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'تصفح المطاعم بحرية، وعند رغبتك في الطلب أو متابعة طلباتك يمكنك تسجيل الدخول في ثوانٍ.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? ClientColors.textSecondary
                                : const Color(0xFF6B6B6B),
                            height: 1.6),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () => _openLogin(context),
                        icon: const Icon(Icons.login_rounded),
                        label: const Text('تسجيل الدخول أو إنشاء حساب'),
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

    final options = <Map<String, dynamic>>[
      {
        'icon': Icons.account_balance_wallet,
        'title': 'رصيد المحفظة',
        'subtitle': 'عرض رصيدك الحالي وشحن المحفظة',
        'color': const Color(0xFF10B981),
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ClientWalletScreen(clientId: widget.clientId),
              ),
            ),
      },
      {
        'icon': Icons.location_on,
        'title': 'عناويني',
        'subtitle': 'إدارة العناوين الخاصة بك',
        'color': const Color(0xFF3B82F6),
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddressSelectionScreen(
                  userId: widget.clientId,
                  userType: 'client',
                  isSelecting: false,
                ),
              ),
            ),
      },
      {
        'icon': Icons.settings,
        'title': 'الإعدادات',
        'subtitle': 'تغيير اللغة، الإشعارات...',
        'color': const Color(0xFF8B5CF6),
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ClientSettingsScreen()),
            ),
      },
      {
        'icon': Icons.support_agent,
        'title': 'خدمة العملاء',
        'subtitle': 'تواصل معنا للمساعدة',
        'color': primaryColor,
        'onTap': () => _openSupportChat(context),
      },
      {
        'icon': Icons.logout,
        'title': 'تسجيل الخروج',
        'subtitle': 'الخروج من الحساب',
        'color': ClientColors.error,
        'onTap': () => _signOut(context),
      },
    ];

    return FutureBuilder<GuestLocationData?>(
      future: GuestLocationService.load(),
      builder: (context, snapshot) {
        final guestLocation = snapshot.data;
        final items = [...options];
        if (guestLocation != null) {
          items.insert(
            1,
            {
              'icon': Icons.my_location_rounded,
              'title': 'حفظ موقع التصفح الحالي',
              'subtitle':
                  'إضافة ${guestLocation.addressName} إلى عناوينك المحفوظة',
              'color': const Color(0xFFF59E0B),
              'onTap': () => _saveGuestLocationToAddresses(context),
            },
          );
        }

        const accountTitles = {
          'رصيد المحفظة',
          'عناويني',
          'الإعدادات',
          'حفظ موقع التصفح الحالي',
        };
        const supportTitles = {'خدمة العملاء'};
        const otherTitles = {'تسجيل الخروج'};

        final accountItems = items
            .where((i) => accountTitles.contains(i['title']))
            .toList();
        final supportItems = items
            .where((i) => supportTitles.contains(i['title']))
            .toList();
        final otherItems = items
            .where((i) => otherTitles.contains(i['title']))
            .toList();

        final themeProvider = context.watch<ThemeProvider>();
        final isDark = themeProvider.isDark;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16, 16, 16,
                16 + MediaQuery.of(context).padding.bottom + 80,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _UserHeader(clientId: widget.clientId),
                  const SizedBox(height: 20),
                  // مفتاح الثيم
                  _ThemeToggleTile(isDark: isDark, onToggle: themeProvider.toggle),
                  const SizedBox(height: 16),
                  _buildSection('الحساب', accountItems),
                  const SizedBox(height: 16),
                  _buildSection('التواصل', supportItems),
                  const SizedBox(height: 16),
                  _buildSection('أخرى', otherItems),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── مفتاح الثيم ─────────────────────────────────────────────────────────

class _ThemeToggleTile extends StatelessWidget {
  const _ThemeToggleTile({required this.isDark, required this.onToggle});
  final bool isDark;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDarkTheme ? const Color(0x1AFFFFFF) : Colors.white;
    final cardBorder = isDarkTheme ? const Color(0x1AFF6B00) : const Color(0x14000000);
    final textColor = isDarkTheme ? Colors.white : const Color(0xFF1A1A1A);
    final subColor = isDarkTheme ? const Color(0xA6FFFFFF) : const Color(0xFF6B6B6B);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
        boxShadow: isDarkTheme
            ? const []
            : [const BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Switch(
              value: isDark,
              onChanged: (_) => onToggle(),
              activeColor: ClientColors.primary,
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'المظهر الداكن',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                Text(
                  isDark ? 'الوضع الداكن مفعّل' : 'الوضع الفاتح مفعّل',
                  style: TextStyle(fontSize: 12, color: subColor),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: ClientColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                color: ClientColors.primary,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── رأس بيانات المستخدم ──────────────────────────────────────────────────

class _UserHeader extends StatelessWidget {
  const _UserHeader({required this.clientId});
  final String clientId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clients')
          .doc(clientId)
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>?;
        final name =
            (data?['name'] ?? data?['fullName'] ?? data?['displayName'] ?? '')
                .toString()
                .trim();
        final email = (data?['email'] ?? '').toString().trim();
        final phone =
            (data?['phone'] ?? data?['phoneNumber'] ?? '').toString().trim();
        final photoUrl =
            (data?['photoUrl'] ?? data?['profileImage'] ?? '').toString().trim();
        final walletBalance =
            (data?['walletBalance'] as num?)?.toStringAsFixed(0) ?? '0';
        final subtitle =
            email.isNotEmpty ? email : (phone.isNotEmpty ? phone : '');

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
          decoration: BoxDecoration(
            color: ClientColors.primary,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            boxShadow: [
              BoxShadow(
                color: ClientColors.primary.withValues(alpha: 0.2),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Avatar
                  Center(
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: ClientColors.primary.withValues(alpha: 0.5),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: photoUrl.isNotEmpty
                          ? ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: photoUrl,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => const Icon(Icons.person, size: 32),
                              ),
                            )
                          : Center(
                              child: Text(
                                name.isNotEmpty
                                    ? name[0].toUpperCase()
                                    : '؟',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Name
                  Text(
                    name.isNotEmpty ? name : 'مستخدم',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 14),
                  // Stats row
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Row(
                      children: [
                        _statBox('المحفظة', '$walletBalance ج.س'),
                        _statDivider(),
                        _statBox('التقييم', '4.9 ⭐'),
                        _statDivider(),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('orders')
                              .where('clientId', isEqualTo: clientId)
                              .where('orderStatus',
                                  whereIn: ['delivered', 'تم التوصيل'])
                              .snapshots(),
                          builder: (_, snap) => _statBox(
                            'طلب',
                            '${snap.data?.docs.length ?? 0}',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statBox(String label, String value) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statDivider() {
    return Container(
      width: 1,
      height: 36,
      color: Colors.white.withValues(alpha: 0.07),
    );
  }
}
