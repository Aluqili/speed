import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';
import 'package:speedstar_core/src/auth/login_screen_ar.dart';

import '../الخدمات/guest_location_service.dart';
import 'client_wallet_screen.dart';
import 'client_settings_screen.dart';
import 'chat_screen.dart';
import 'address_selection_screen.dart';
import 'add_new_address_screen.dart';

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
          allowGuestSignIn: false,
        ),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  void _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userType'); // لا نحذف الطلب الحالي

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreenArabic(),
      ),
      (route) => false,
    );
  }

  Future<void> _openSupportChat(BuildContext context) async {
    String chatId = '${widget.clientId}-support';
    String clientName = 'عميل';

    try {
      final clientDoc = await FirebaseFirestore.instance
          .collection('clients')
          .doc(widget.clientId)
          .get();
      final clientData = clientDoc.data() ?? <String, dynamic>{};
      final savedChatId =
          (clientData['lastSupportConversationId'] ?? '').toString().trim();
      final savedClientName =
          (clientData['name'] ?? clientData['fullName'] ?? '')
              .toString()
              .trim();
      if (savedChatId.isNotEmpty) {
        chatId = savedChatId;
      }
      if (savedClientName.isNotEmpty) {
        clientName = savedClientName;
      }
    } catch (_) {
      // Fallback to the default support conversation id.
    }

    if (!context.mounted) {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          currentUserId: widget.clientId,
          otherUserId: 'support',
          currentUserRole: 'client',
          chatId: chatId,
          currentUserName: clientName,
        ),
      ),
    );
  }

  Future<void> _saveGuestLocationToAddresses(BuildContext context) async {
    final guestLocation = await GuestLocationService.load();
    if (!context.mounted || guestLocation == null) {
      return;
    }

    final saved = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddNewAddressScreen(
          userId: widget.clientId,
          userType: 'client',
          existingName: guestLocation.addressName,
          existingLatitude: guestLocation.latitude,
          existingLongitude: guestLocation.longitude,
        ),
      ),
    );

    if (saved != null) {
      await GuestLocationService.clear();
      if (mounted) {
        setState(() {});
      }
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
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ClientSettingsScreen()),
            ),
      },
      {
        'icon': Icons.support_agent,
        'title': 'خدمة العملاء',
        'subtitle': 'تواصل معنا للمساعدة',
        'onTap': () => _openSupportChat(context),
      },
      {
        'icon': Icons.logout,
        'title': 'تسجيل الخروج',
        'subtitle': 'الخروج من الحساب',
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
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = items[index];
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    leading:
                        Icon(item['icon'] as IconData, color: primaryColor),
                    title: Text(
                      item['title'] as String,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(item['subtitle'] as String),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey,
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
