import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'client_wallet_screen.dart';
import 'client_settings_screen.dart';
import 'client_support_screen.dart';
import 'address_selection_screen.dart';
import 'role_selection_screen.dart'; // تم تصحيح اسم الملف

class ClientAccountTab extends StatelessWidget {
  final String clientId;

  const ClientAccountTab({Key? key, required this.clientId}) : super(key: key);

  void _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userType'); // لا نحذف الطلب الحالي

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const RoleSelectionScreen(), // تم التعديل هنا
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFFE724C);

    if (clientId.isEmpty) {
      return const Center(child: Text('يرجى تسجيل الدخول لعرض حسابك.'));
    }

    final options = [
      {
        'icon': Icons.account_balance_wallet,
        'title': 'رصيد المحفظة',
        'subtitle': 'عرض رصيدك الحالي وشحن المحفظة',
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ClientWalletScreen(clientId: clientId)),
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
                  userId: clientId,
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
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ClientSupportScreen()),
            ),
      },
      {
        'icon': Icons.logout,
        'title': 'تسجيل الخروج',
        'subtitle': 'الخروج من الحساب',
        'onTap': () => _signOut(context),
      },
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        body: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: options.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = options[index];
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
                leading: Icon(item['icon'] as IconData, color: primaryColor),
                title: Text(item['title'] as String, style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text(item['subtitle'] as String),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                onTap: item['onTap'] as VoidCallback,
              ),
            );
          },
        ),
      ),
    );
  }
}
