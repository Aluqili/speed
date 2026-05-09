import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';
import 'package:speedstar_core/src/auth/login_screen_ar.dart';

import 'address_selection_screen.dart';
import 'store_privacy_policy_screen.dart';

// ألوان وخطوط متوافقة مع بقية الشاشات
const Color primaryColor = AppThemeArabic.storePrimary;
const Color backgroundColor = AppThemeArabic.storeBackground;

class StoreSettingsScreen extends StatefulWidget {
  final String restaurantId;
  const StoreSettingsScreen({Key? key, required this.restaurantId})
      : super(key: key);

  @override
  State<StoreSettingsScreen> createState() => _StoreSettingsScreenState();
}

class _StoreSettingsScreenState extends State<StoreSettingsScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _discountController = TextEditingController();

  String? _address;
  String? _coverImageUrl;
  String? _logoImageUrl;
  bool _autoAcceptOrders = false;
  double? _latitude;
  double? _longitude;
  bool _isDeletingAccount = false;

  final _cloudinary = CloudinaryPublic('dvnzloec6', 'flutter_unsigned');

  @override
  void initState() {
    super.initState();
    _loadRestaurantData();
    _refreshDefaultAddress();
  }

  Future<void> _loadRestaurantData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.restaurantId)
          .get();
      if (!doc.exists) return;
      final data = doc.data()!;
      _nameController.text = data['name'] ?? '';
      _phoneController.text = data['phone'] ?? '';
      _discountController.text =
          (data['deliveryDiscountPercentage'] as num?)?.toStringAsFixed(0) ??
              '';
      _address = data['address'];
      _coverImageUrl = data['coverImageUrl'];
      _logoImageUrl = data['logoImageUrl'];
      _autoAcceptOrders = data['autoAcceptOrders'] ?? false;
      final loc = data['location'];
      if (loc is GeoPoint) {
        _latitude = loc.latitude;
        _longitude = loc.longitude;
      } else if (loc is Map<String, dynamic>) {
        _latitude = (loc['lat'] as num).toDouble();
        _longitude = (loc['lng'] as num).toDouble();
      }
      if (!mounted) return;
      setState(() {});
    } on FirebaseException catch (e) {
      if (!mounted) return;
      GFToast.showToast(
          '❌ تعذر تحميل بيانات المتجر: ${e.message ?? e.code}', context);
    }
  }

  Future<void> _refreshDefaultAddress() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.restaurantId)
          .get();
      final defaultAddressId = doc.data()?['defaultAddressId'];
      if (defaultAddressId != null) {
        final addressDoc = await FirebaseFirestore.instance
            .collection('restaurants')
            .doc(widget.restaurantId)
            .collection('addresses')
            .doc(defaultAddressId)
            .get();
        final addressName =
            addressDoc.data()?['addressName'] ?? 'عنوان بدون اسم';
        if (!mounted) return;
        setState(() {
          _address = addressName;
          _latitude = (addressDoc.data()?['latitude'] as num?)?.toDouble();
          _longitude = (addressDoc.data()?['longitude'] as num?)?.toDouble();
        });
      }
    } on FirebaseException catch (e) {
      if (!mounted) return;
      GFToast.showToast(
          '❌ تعذر تحديث العنوان: ${e.message ?? e.code}', context);
    }
  }

  Future<void> _pickAndUploadImage(bool isCover) async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;
    final resp = await _cloudinary.uploadFile(
      CloudinaryFile.fromFile(picked.path,
          resourceType: CloudinaryResourceType.Image),
    );
    setState(() {
      if (isCover) {
        _coverImageUrl = resp.secureUrl;
      } else {
        _logoImageUrl = resp.secureUrl;
      }
    });
  }

  Future<void> _selectAddress() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AddressSelectionScreen(restaurantId: widget.restaurantId),
      ),
    );
    await _refreshDefaultAddress();
  }

  Future<void> _saveChanges() async {
    final discount = double.tryParse(_discountController.text.trim());

    try {
      await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.restaurantId)
          .update({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'deliveryDiscountPercentage': discount,
        'address': _address,
        'coverImageUrl': _coverImageUrl,
        'logoImageUrl': _logoImageUrl,
        'autoAcceptOrders': _autoAcceptOrders,
        'location': (_latitude != null && _longitude != null)
            ? GeoPoint(_latitude!, _longitude!)
            : null,
      });

      if (!mounted) return;
      GFToast.showToast('✅ تم حفظ التعديلات', context);
    } on FirebaseException catch (e) {
      if (!mounted) return;
      GFToast.showToast(
          '❌ لا تملك صلاحية الحفظ: ${e.message ?? e.code}', context);
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
        title: const Text('حذف حساب المتجر'),
        content: const Text(
          'سيتم إرسال طلب حذف حساب المتجر نهائياً. هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('متابعة الحذف'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يوجد مستخدم مسجل حالياً')));
      return;
    }

    setState(() => _isDeletingAccount = true);
    try {
      await FirebaseFirestore.instance
          .collection('accountDeletionRequests')
          .doc(widget.restaurantId)
          .set({
        'userId': widget.restaurantId,
        'authUid': user.uid,
        'role': 'store',
        'sourceApp': 'store',
        'status': 'pending',
        'requestedFrom': 'in_app',
        'userName': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': user.email ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.restaurantId)
          .set({
        'deletionRequestStatus': 'pending',
        'deletionRequestedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _logout();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال طلب حذف الحساب بنجاح')),
      );
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: const Text(
            'إعدادات المطعم',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: 'Tajawal',
              fontSize: 20,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 18),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppThemeArabic.storePrimary, Color(0xFF13A89E)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.white.withValues(alpha: 0.18),
                      backgroundImage: (_logoImageUrl ?? '').isNotEmpty
                          ? NetworkImage(_logoImageUrl!)
                          : null,
                      child: (_logoImageUrl ?? '').isEmpty
                          ? const Icon(Icons.storefront_rounded,
                              color: Colors.white, size: 28)
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _nameController.text.trim().isEmpty
                                ? 'بيانات المتجر'
                                : _nameController.text.trim(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _address ??
                                'حدّث العنوان وبيانات الهوية البصرية من هنا',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _buildSectionCard(
                title: 'البيانات الأساسية',
                icon: Icons.badge_outlined,
                children: [
                  _buildLabel('📛 اسم المطعم'),
                  _buildTextField(_nameController),
                  _buildLabel('📱 رقم الهاتف'),
                  _buildTextField(_phoneController,
                      keyboardType: TextInputType.phone),
                  _buildLabel('🤑 نسبة خصم على رسوم التوصيل (٪)'),
                  _buildTextField(_discountController,
                      keyboardType: TextInputType.number),
                ],
              ),
              _buildSectionCard(
                title: 'الموقع',
                icon: Icons.place_outlined,
                children: [
                  _buildLabel('📍 العنوان'),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _address ?? 'لم يتم التحديد',
                          style: const TextStyle(
                              color: Colors.grey, fontFamily: 'Tajawal'),
                        ),
                      ),
                      GFButton(
                        onPressed: _selectAddress,
                        text: 'تحديد',
                        size: GFSize.SMALL,
                        color: primaryColor,
                        shape: GFButtonShape.pills,
                      ),
                    ],
                  ),
                ],
              ),
              _buildSectionCard(
                title: 'صورة الغلاف',
                icon: Icons.wallpaper_outlined,
                children: [
                  _buildLabel('🖼️ صورة الغلاف'),
                  _coverImageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            _coverImageUrl!,
                            height: 140,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Text('لم يتم اختيار صورة',
                          style: TextStyle(fontFamily: 'Tajawal')),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.image, color: Colors.white),
                      label: const Text('اختيار صورة الغلاف',
                          style: TextStyle(fontFamily: 'Tajawal')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _pickAndUploadImage(true),
                    ),
                  ),
                ],
              ),
              _buildSectionCard(
                title: 'الشعار',
                icon: Icons.image_outlined,
                children: [
                  _buildLabel('🏷️ شعار المطعم'),
                  _logoImageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(_logoImageUrl!, height: 80),
                        )
                      : const Text('لم يتم اختيار شعار',
                          style: TextStyle(fontFamily: 'Tajawal')),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon:
                          const Icon(Icons.image_outlined, color: Colors.white),
                      label: const Text('اختيار الشعار',
                          style: TextStyle(fontFamily: 'Tajawal')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _pickAndUploadImage(false),
                    ),
                  ),
                ],
              ),
              _buildSectionCard(
                title: 'سلوك الطلبات',
                icon: Icons.tune,
                children: [
                  SwitchListTile(
                    title: const Text('✅ قبول الطلبات تلقائياً',
                        style: TextStyle(fontFamily: 'Tajawal')),
                    value: _autoAcceptOrders,
                    onChanged: (v) async {
                      setState(() => _autoAcceptOrders = v);
                      await FirebaseFirestore.instance
                          .collection('restaurants')
                          .doc(widget.restaurantId)
                          .update({'autoAcceptOrders': v});
                      if (!context.mounted) return;
                      GFToast.showToast(
                        v
                            ? 'تم تفعيل القبول التلقائي'
                            : 'تم إيقاف القبول التلقائي',
                        context,
                        backgroundColor: v ? Colors.green : Colors.orange,
                      );
                    },
                    activeColor: primaryColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save, color: Colors.white),
                  label: const Text('حفظ التعديلات',
                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _saveChanges,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.privacy_tip, color: Colors.white),
                  label: const Text('سياسة الخصوصية',
                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const StorePrivacyPolicyScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  label: const Text('تسجيل الخروج',
                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _logout,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _isDeletingAccount
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.delete_forever, color: Colors.white),
                  label: const Text('حذف الحساب',
                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed:
                      _isDeletingAccount ? null : _requestAccountDeletion,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required List<Widget> children,
    required String title,
    required IconData icon,
  }) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppThemeArabic.storePrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppThemeArabic.storePrimary),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String txt) => Padding(
        padding: const EdgeInsets.only(top: 0, bottom: 8),
        child: Text(
          txt,
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontFamily: 'Tajawal', fontSize: 15),
        ),
      );

  Widget _buildTextField(TextEditingController ctrl,
          {TextInputType? keyboardType}) =>
      TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: const TextStyle(fontFamily: 'Tajawal'),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.grey.shade100,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      );
}
