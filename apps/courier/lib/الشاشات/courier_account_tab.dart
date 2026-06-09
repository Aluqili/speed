import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speedstar_core/src/auth/login_screen_ar.dart';

import 'courier_privacy_policy_screen.dart';
import 'courier_ui.dart';
import 'courier_wallet_screen.dart';

class CourierAccountTab extends StatefulWidget {
  final String driverId;

  const CourierAccountTab({super.key, required this.driverId});

  @override
  State<CourierAccountTab> createState() => _CourierAccountTabState();
}

class _CourierAccountTabState extends State<CourierAccountTab> {
  Map<String, dynamic>? driverData;
  int completedOrders = 0;
  double totalEarnings = 0;
  bool _isDeletingAccount = false;

  @override
  void initState() {
    super.initState();
    _fetchDriverData();
    _fetchCompletedOrders();
  }

  Future<void> _fetchDriverData() async {
    final doc = await FirebaseFirestore.instance
        .collection('drivers')
        .doc(widget.driverId)
        .get();
    if (!doc.exists || !mounted) return;
    setState(() {
      driverData = doc.data();
    });
  }

  Future<void> _fetchCompletedOrders() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('orders')
        .where('assignedDriverId', isEqualTo: widget.driverId)
        .get();

    double total = 0;
    int completed = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final status = (data['orderStatus'] ?? data['status'] ?? '').toString();
      if (status != 'delivered' && status != 'تم التوصيل') continue;
      final fee = data['deliveryFeeForDriver'] ?? data['deliveryFee'] ?? 0;
      total += fee is num ? fee.toDouble() : 0;
      completed++;
    }

    if (!mounted) return;
    setState(() {
      completedOrders = completed;
      totalEarnings = total;
    });
  }

  Future<void> _editField(String fieldName, String currentValue) async {
    final controller = TextEditingController(text: currentValue);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('تعديل $fieldName'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: 'أدخل $fieldName الجديد'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (result == null || result == currentValue) return;
    await FirebaseFirestore.instance
        .collection('drivers')
        .doc(widget.driverId)
        .update({fieldName: result});
    _fetchDriverData();
  }

  Future<void> _changePassword() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تغيير كلمة المرور'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'كلمة المرور الجديدة'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('تغيير'),
          ),
        ],
      ),
    );

    if (result == null) return;
    if (result.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('كلمة المرور قصيرة جدًا')),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.currentUser?.updatePassword(result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تغيير كلمة المرور')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تغيير كلمة المرور: $e')),
      );
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userType');
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreenArabic(
          allowRegister: false,
          allowGoogleSignIn: false,
          allowPhoneSignIn: false,
          allowGuestSignIn: false,
        ),
      ),
      (route) => false,
    );
  }

  Future<void> _requestAccountDeletion() async {
    if (_isDeletingAccount) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف حساب المندوب'),
        content: const Text(
          'سيتم إرسال طلب حذف الحساب للإدارة. هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('متابعة'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isDeletingAccount = true);
    try {
      await FirebaseFirestore.instance
          .collection('accountDeletionRequests')
          .doc(widget.driverId)
          .set({
        'userId': widget.driverId,
        'authUid': user.uid,
        'role': 'courier',
        'sourceApp': 'courier',
        'status': 'pending',
        'requestedFrom': 'in_app',
        'userName': driverData?['name'] ?? '',
        'phone': driverData?['phone'] ?? '',
        'email': driverData?['email'] ?? user.email ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(widget.driverId)
          .set({
        'deletionRequestStatus': 'pending',
        'deletionRequestedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _logout();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إرسال طلب الحذف: $e')),
      );
    } finally {
      if (mounted) setState(() => _isDeletingAccount = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (driverData == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final name = (driverData!['name'] ?? 'غير معروف').toString();
    final phone = (driverData!['phone'] ?? 'غير متاح').toString();

    return Scaffold(
      appBar: buildCourierAppBar('حسابي'),
      body: CourierPageBackground(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CourierHeroCard(
              title: name,
              subtitle: 'إدارة بياناتك الشخصية وأمان الحساب والتحويلات.',
              icon: Icons.person_rounded,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: CourierMetricCard(
                    label: 'طلبات مكتملة',
                    value: '$completedOrders',
                    icon: Icons.task_alt_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CourierMetricCard(
                    label: 'إجمالي الأرباح',
                    value: totalEarnings.toStringAsFixed(1),
                    icon: Icons.payments_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CourierSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CourierSectionTitle(
                    title: 'معلومات الحساب',
                    subtitle: 'يمكنك تحديث البيانات الأساسية من هنا.',
                  ),
                  const SizedBox(height: 16),
                  _AccountFieldTile(
                    title: 'الاسم',
                    value: name,
                    icon: Icons.badge_outlined,
                    onEdit: () => _editField('name', name),
                  ),
                  const SizedBox(height: 10),
                  _AccountFieldTile(
                    title: 'رقم الهاتف',
                    value: phone,
                    icon: Icons.phone_outlined,
                    onEdit: () => _editField('phone', phone),
                  ),
                  const SizedBox(height: 10),
                  _AccountFieldTile(
                    title: 'معرف المندوب',
                    value: widget.driverId,
                    icon: Icons.fingerprint_rounded,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            CourierSectionCard(
              child: Column(
                children: [
                  _ActionTile(
                    title: 'المحفظة والتحويلات',
                    subtitle: 'مراجعة الرصيد والتحويلات وبيانات الاستلام',
                    icon: Icons.account_balance_wallet_outlined,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              CourierWalletScreen(driverId: widget.driverId),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _ActionTile(
                    title: 'تغيير كلمة المرور',
                    subtitle: 'رفع أمان الحساب وتحديث كلمة المرور الحالية',
                    icon: Icons.lock_outline_rounded,
                    onTap: _changePassword,
                  ),
                  const SizedBox(height: 10),
                  _ActionTile(
                    title: 'سياسة الخصوصية',
                    subtitle: 'الاطلاع على حقوقك وآلية معالجة البيانات',
                    icon: Icons.privacy_tip_outlined,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CourierPrivacyPolicyScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isDeletingAccount ? null : _requestAccountDeletion,
              icon: _isDeletingAccount
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.delete_forever_rounded),
              label: Text(
                _isDeletingAccount ? 'جاري إرسال الطلب...' : 'طلب حذف الحساب',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE85142),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountFieldTile extends StatelessWidget {
  const _AccountFieldTile({
    required this.title,
    required this.value,
    required this.icon,
    this.onEdit,
  });

  final String title;
  final String value;
  final IconData icon;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F1E7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white,
            child: Icon(icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF7A6857),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F1E7),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7A6857),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16),
          ],
        ),
      ),
    );
  }
}
