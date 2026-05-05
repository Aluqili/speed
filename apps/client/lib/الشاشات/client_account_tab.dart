import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';
import 'package:speedstar_core/src/auth/login_screen_ar.dart';

import '../الخدمات/guest_location_service.dart';
import 'client_wallet_screen.dart';
import 'client_settings_screen.dart';
import 'client_support_screen.dart';
import 'address_selection_screen.dart';

class ClientAccountTab extends StatefulWidget {
  final String clientId;

  const ClientAccountTab({Key? key, required this.clientId}) : super(key: key);

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
                  backgroundColor: Colors.red),
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

  @override
  Widget build(BuildContext context) {
    const primaryColor = AppThemeArabic.clientPrimary;

    if (widget.clientId.isEmpty) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: Colors.grey[100],
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircleAvatar(
                        radius: 36,
                        backgroundColor: Color(0xFFFFF0E8),
                        child: Icon(
                          Icons.person_rounded,
                          size: 38,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'حسابك غير مسجل بعد',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'تصفح المطاعم بحرية، وعند رغبتك في الطلب أو متابعة طلباتك يمكنك تسجيل الدخول في ثوانٍ.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[700], height: 1.6),
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
        'color': Colors.red,
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

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: Colors.grey[100],
            body: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length + 1,
              separatorBuilder: (_, i) =>
                  i == 0 ? const SizedBox(height: 20) : const SizedBox(height: 12),
              itemBuilder: (context, index) {
                // ─── رأس بيانات المستخدم ────────────────────────
                if (index == 0) {
                  return _UserHeader(clientId: widget.clientId);
                }
                final item = items[index - 1];
                final isLogout = item['title'] == 'تسجيل الخروج';
                final iconColor = (item['color'] as Color?) ?? primaryColor;
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
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
                        color: isLogout ? Colors.red : const Color(0xFF1A1D26),
                      ),
                    ),
                    subtitle: Text(
                      item['subtitle'] as String,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF9CA3AF)),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: isLogout ? Colors.red[200] : Colors.grey[400],
                    ),
                    onTap: item['onTap'] as VoidCallback,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

// ─── رأس بيانات المستخدم ──────────────────────────────────────────────────

class _UserHeader extends StatelessWidget {
  const _UserHeader({required this.clientId});
  final String clientId;

  static const _primary = AppThemeArabic.clientPrimary;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clients')
          .doc(clientId)
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>?;
        final name = (data?['name'] ?? data?['fullName'] ?? data?['displayName'] ?? '')
            .toString()
            .trim();
        final email = (data?['email'] ?? '').toString().trim();
        final phone = (data?['phone'] ?? data?['phoneNumber'] ?? '').toString().trim();
        final photoUrl = (data?['photoUrl'] ?? data?['profileImage'] ?? '').toString().trim();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primary, _primary.withValues(alpha: 0.75)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              // صورة المستخدم
              CircleAvatar(
                radius: 32,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                backgroundImage:
                    photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                child: photoUrl.isEmpty
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '؟',
                        style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isNotEmpty ? name : 'مستخدم',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 17),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(email,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12),
                          overflow: TextOverflow.ellipsis),
                    ] else if (phone.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(phone,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
