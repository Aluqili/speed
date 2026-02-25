import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';

import 'address_selection_screen.dart';
import 'store_privacy_policy_screen.dart';

// ألوان وخطوط متوافقة مع بقية الشاشات
const Color primaryColor = AppThemeArabic.clientPrimary;
const Color backgroundColor = AppThemeArabic.clientBackground;

class StoreSettingsScreen extends StatefulWidget {
  final String restaurantId;
  const StoreSettingsScreen({Key? key, required this.restaurantId}) : super(key: key);

  @override
  State<StoreSettingsScreen> createState() => _StoreSettingsScreenState();
}

class _StoreSettingsScreenState extends State<StoreSettingsScreen> {
  final _nameController     = TextEditingController();
  final _phoneController    = TextEditingController();
  final _discountController = TextEditingController();

  String? _address;
  String? _coverImageUrl;
  String? _logoImageUrl;
  bool   _autoAcceptOrders  = false;
  double? _latitude;
  double? _longitude;

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
      _nameController.text     = data['name']  ?? '';
      _phoneController.text    = data['phone'] ?? '';
      _discountController.text = (data['deliveryDiscountPercentage'] as num?)?.toStringAsFixed(0) ?? '';
      _address                 = data['address'];
      _coverImageUrl           = data['coverImageUrl'];
      _logoImageUrl            = data['logoImageUrl'];
      _autoAcceptOrders        = data['autoAcceptOrders'] ?? false;
      final loc                = data['location'];
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
      GFToast.showToast('❌ تعذر تحميل بيانات المتجر: ${e.message ?? e.code}', context);
    }
  }

  Future<void> _refreshDefaultAddress() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('restaurants').doc(widget.restaurantId).get();
      final defaultAddressId = doc.data()?['defaultAddressId'];
      if (defaultAddressId != null) {
        final addressDoc = await FirebaseFirestore.instance
            .collection('restaurants')
            .doc(widget.restaurantId)
            .collection('addresses')
            .doc(defaultAddressId)
            .get();
        final addressName = addressDoc.data()?['addressName'] ?? 'عنوان بدون اسم';
        if (!mounted) return;
        setState(() {
          _address = addressName;
          _latitude = (addressDoc.data()?['latitude'] as num?)?.toDouble();
          _longitude = (addressDoc.data()?['longitude'] as num?)?.toDouble();
        });
      }
    } on FirebaseException catch (e) {
      if (!mounted) return;
      GFToast.showToast('❌ تعذر تحديث العنوان: ${e.message ?? e.code}', context);
    }
  }

  Future<void> _pickAndUploadImage(bool isCover) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;
    final resp = await _cloudinary.uploadFile(
      CloudinaryFile.fromFile(picked.path, resourceType: CloudinaryResourceType.Image),
    );
    setState(() {
      if (isCover) _coverImageUrl = resp.secureUrl;
      else         _logoImageUrl  = resp.secureUrl;
    });
  }

  Future<void> _selectAddress() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddressSelectionScreen(restaurantId: widget.restaurantId),
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
        'name':                       _nameController.text.trim(),
        'phone':                      _phoneController.text.trim(),
        'deliveryDiscountPercentage': discount,
        'address':                    _address,
        'coverImageUrl':              _coverImageUrl,
        'logoImageUrl':               _logoImageUrl,
        'autoAcceptOrders':           _autoAcceptOrders,
        'location': (_latitude != null && _longitude != null)
            ? GeoPoint(_latitude!, _longitude!)
            : null,
      });

      if (!mounted) return;
      GFToast.showToast('✅ تم حفظ التعديلات', context);
    } on FirebaseException catch (e) {
      if (!mounted) return;
      GFToast.showToast('❌ لا تملك صلاحية الحفظ: ${e.message ?? e.code}', context);
    }
  }

  Future<void> _logout() async {
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/roleSelection', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 2,
          centerTitle: true,
          iconTheme: const IconThemeData(color: primaryColor),
          title: const Text(
            'إعدادات المطعم',
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.bold,
              fontFamily: 'Tajawal',
              fontSize: 20,
              letterSpacing: 1.1,
            ),
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionCard(
                children: [
                  _buildLabel('📛 اسم المطعم'),
                  _buildTextField(_nameController),
                  _buildLabel('📱 رقم الهاتف'),
                  _buildTextField(_phoneController, keyboardType: TextInputType.phone),
                  _buildLabel('🤑 نسبة خصم على رسوم التوصيل (٪)'),
                  _buildTextField(_discountController, keyboardType: TextInputType.number),
                ],
              ),
              _buildSectionCard(
                children: [
                  _buildLabel('📍 العنوان'),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _address ?? 'لم يتم التحديد',
                          style: const TextStyle(color: Colors.grey, fontFamily: 'Tajawal'),
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
                      : const Text('لم يتم اختيار صورة', style: TextStyle(fontFamily: 'Tajawal')),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.image, color: Colors.white),
                      label: const Text('اختيار صورة الغلاف', style: TextStyle(fontFamily: 'Tajawal')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _pickAndUploadImage(true),
                    ),
                  ),
                ],
              ),
              _buildSectionCard(
                children: [
                  _buildLabel('🏷️ شعار المطعم'),
                  _logoImageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(_logoImageUrl!, height: 80),
                        )
                      : const Text('لم يتم اختيار شعار', style: TextStyle(fontFamily: 'Tajawal')),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.image_outlined, color: Colors.white),
                      label: const Text('اختيار الشعار', style: TextStyle(fontFamily: 'Tajawal')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _pickAndUploadImage(false),
                    ),
                  ),
                ],
              ),
              _buildSectionCard(
                children: [
                  SwitchListTile(
                    title: const Text('✅ قبول الطلبات تلقائياً', style: TextStyle(fontFamily: 'Tajawal')),
                    value: _autoAcceptOrders,
                    onChanged: (v) async {
                      setState(() => _autoAcceptOrders = v);
                      await FirebaseFirestore.instance
                          .collection('restaurants')
                          .doc(widget.restaurantId)
                          .update({'autoAcceptOrders': v});
                      GFToast.showToast(
                        v ? 'تم تفعيل القبول التلقائي' : 'تم إيقاف القبول التلقائي',
                        context,
                        backgroundColor: v ? Colors.green : Colors.orange,
                      );
                    },
                    activeColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save, color: Colors.white),
                  label: const Text('حفظ التعديلات', style: TextStyle(fontFamily: 'Tajawal', fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _saveChanges,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.privacy_tip, color: Colors.white),
                  label: const Text('سياسة الخصوصية', style: TextStyle(fontFamily: 'Tajawal', fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  label: const Text('تسجيل الخروج', style: TextStyle(fontFamily: 'Tajawal', fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _logout,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({required List<Widget> children}) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }

  Widget _buildLabel(String txt) => Padding(
        padding: const EdgeInsets.only(top: 0, bottom: 8),
        child: Text(
          txt,
          style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal', fontSize: 15),
        ),
      );

  Widget _buildTextField(TextEditingController ctrl, {TextInputType? keyboardType}) => TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: const TextStyle(fontFamily: 'Tajawal'),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.grey.shade100,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      );
}
