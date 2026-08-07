import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:getwidget/getwidget.dart';
import 'package:image_picker/image_picker.dart';
import 'courier_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';

class CourierEditProfileScreen extends StatefulWidget {
  final String driverId;
  final Map<String, dynamic> currentData; // البيانات الحالية

  const CourierEditProfileScreen(
      {super.key, required this.driverId, required this.currentData});

  @override
  State<CourierEditProfileScreen> createState() =>
      _CourierEditProfileScreenState();
}

class _CourierEditProfileScreenState extends State<CourierEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _regionController;
  File? _pickedImage;
  bool _loading = false;
  double walletBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentData['name']);
    _phoneController = TextEditingController(text: widget.currentData['phone']);
    _regionController =
        TextEditingController(text: widget.currentData['region']);
    walletBalance = widget.currentData['wallet'] != null
        ? (widget.currentData['wallet'] as num).toDouble()
        : 0.0;
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _pickedImage = File(picked.path);
      });
    }
  }

  Future<String?> _uploadImage(File image) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('drivers')
          .child('${widget.driverId}.jpg');
      await ref.putFile(image);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Courier profile image upload failed: $e');
      return null;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
    });

    String? imageUrl = widget.currentData['profileImage'];
    if (_pickedImage != null) {
      imageUrl = await _uploadImage(_pickedImage!);
    }

    await FirebaseFirestore.instance
        .collection('drivers')
        .doc(widget.driverId)
        .update({
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'region': _regionController.text.trim(),
      'profileImage': imageUrl,
    });

    setState(() {
      _loading = false;
    });

    Get.back(); // رجوع للشاشة السابقة
    Get.snackbar(
      'تم التحديث',
      'تم تحديث بياناتك بنجاح.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppThemeArabic.clientSuccess,
      colorText: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildCourierAppBar('تعديل الملف الشخصي'),
      backgroundColor: Colors.transparent,
      body: CourierPageBackground(
        child: _loading
            ? const Center(child: GFLoader(type: GFLoaderType.circle))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _pickImage,
                        child: GFAvatar(
                          radius: 50,
                          backgroundImage: _pickedImage != null
                              ? FileImage(_pickedImage!)
                              : NetworkImage(
                                      widget.currentData['profileImage'] ??
                                          'https://via.placeholder.com/150')
                                  as ImageProvider,
                          child: const Align(
                            alignment: Alignment.bottomRight,
                            child: GFAvatar(
                              backgroundColor: AppThemeArabic.clientPrimary,
                              radius: 14,
                              child: Icon(Icons.edit,
                                  size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _nameController,
                        decoration:
                            const InputDecoration(labelText: 'الاسم الكامل'),
                        validator: (value) => value == null || value.isEmpty
                            ? 'الرجاء إدخال الاسم'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        decoration:
                            const InputDecoration(labelText: 'رقم الجوال'),
                        validator: (value) => value == null || value.isEmpty
                            ? 'الرجاء إدخال رقم الجوال'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _regionController,
                        decoration: const InputDecoration(labelText: 'المدينة'),
                        validator: (value) => value == null || value.isEmpty
                            ? 'الرجاء إدخال المدينة'
                            : null,
                      ),
                      const SizedBox(height: 24),
                      GFButton(
                        onPressed: _saveProfile,
                        text: 'حفظ التعديلات',
                        color: AppThemeArabic.clientPrimary,
                        fullWidthButton: true,
                        size: GFSize.LARGE,
                        shape: GFButtonShape.pills,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
