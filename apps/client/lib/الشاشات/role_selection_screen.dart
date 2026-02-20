import 'package:flutter/material.dart';
// تم إلغاء شاشة تسجيل الدخول مؤقتاً وسيتم التوجيه لاحقاً عبر SDUI

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({Key? key}) : super(key: key);

  void _navigateToLogin(BuildContext context, String userType) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم اختيار: $userType')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'اختر دورك',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildRoleButton(
                context: context,
                icon: Icons.shopping_cart,
                label: 'عميل',
                onTap: () => _navigateToLogin(context, 'client'),
              ),
              const SizedBox(height: 20),
              _buildRoleButton(
                context: context,
                icon: Icons.delivery_dining,
                label: 'مندوب',
                onTap: () => _navigateToLogin(context, 'driver'),
              ),
              const SizedBox(height: 20),
              _buildRoleButton(
                context: context,
                icon: Icons.restaurant_menu,
                label: 'مطعم',
                onTap: () => _navigateToLogin(context, 'restaurant'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFF57C00).withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF57C00)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFF57C00), size: 32),
            const SizedBox(width: 20),
            Text(
              label,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFFF57C00),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
