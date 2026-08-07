import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class StoreLinkRequestScreen extends StatefulWidget {
  const StoreLinkRequestScreen({
    super.key,
    this.userId,
    this.email,
  });

  final String? userId;
  final String? email;

  @override
  State<StoreLinkRequestScreen> createState() => _StoreLinkRequestScreenState();
}

class _StoreLinkRequestScreenState extends State<StoreLinkRequestScreen> {
  static const _businessTypes = <String, String>{
    'restaurant': 'مطعم',
    'brand': 'براند',
    'ecommerce': 'متجر إلكتروني',
    'grocery': 'بقالة',
    'pharmacy': 'صيدلية',
  };

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _recordNumberController = TextEditingController();
  final _pharmacyLicenseController = TextEditingController();
  final _returnPolicyDaysController = TextEditingController(text: '14');
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  File? _recordImage;
  File? _pharmacyLicenseImage;
  bool _submitting = false;
  String _businessType = 'restaurant';

  bool get _isAuthenticatedSubmit => (widget.userId ?? '').isNotEmpty;
  bool get _isPharmacy => _businessType == 'pharmacy';
  bool get _requiresReturnPolicy =>
      _businessType == 'brand' || _businessType == 'ecommerce';

  @override
  void initState() {
    super.initState();
    if ((widget.email ?? '').isNotEmpty) {
      _emailController.text = widget.email!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _recordNumberController.dispose();
    _pharmacyLicenseController.dispose();
    _returnPolicyDaysController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickRecordImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1500,
    );
    if (picked != null) {
      setState(() => _recordImage = File(picked.path));
    }
  }

  Future<void> _pickPharmacyLicenseImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1500,
    );
    if (picked != null) {
      setState(() => _pharmacyLicenseImage = File(picked.path));
    }
  }

  Future<String?> _uploadImageToCloudinary(File imageFile) async {
    const cloudName = 'dvnzloec6';
    const uploadPreset = 'flutter_unsigned';

    final uri =
        Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    final response = await request.send();
    if (response.statusCode != 200) return null;
    final payload = json.decode(await response.stream.bytesToString());
    return payload['secure_url'] as String?;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final messenger = ScaffoldMessenger.of(context);

    if (!_formKey.currentState!.validate()) return;
    if (_recordImage == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('الرجاء رفع صورة السجل التجاري')),
      );
      return;
    }
    if (_isPharmacy &&
        (_pharmacyLicenseController.text.trim().isEmpty ||
            _pharmacyLicenseImage == null)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('أدخل رقم ترخيص الصيدلية وارفع صورته')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final recordImageUrl = await _uploadImageToCloudinary(_recordImage!);
      if (recordImageUrl == null) {
        setState(() => _submitting = false);
        messenger.showSnackBar(
          const SnackBar(content: Text('فشل رفع صورة السجل التجاري')),
        );
        return;
      }
      String pharmacyLicenseImageUrl = '';
      if (_isPharmacy) {
        pharmacyLicenseImageUrl =
            await _uploadImageToCloudinary(_pharmacyLicenseImage!) ?? '';
        if (pharmacyLicenseImageUrl.isEmpty) {
          setState(() => _submitting = false);
          messenger.showSnackBar(
            const SnackBar(content: Text('فشل رفع صورة ترخيص الصيدلية')),
          );
          return;
        }
      }

      final payload = <String, dynamic>{
        'name': _nameController.text.trim(),
        'businessType': _businessType,
        'businessTypeLabel': _businessTypes[_businessType],
        'phone': _phoneController.text.trim(),
        'commercialRecordNumber': _recordNumberController.text.trim(),
        'commercialRecordImageUrl': recordImageUrl,
        'pharmacyLicenseNumber': _pharmacyLicenseController.text.trim(),
        'pharmacyLicenseImageUrl': pharmacyLicenseImageUrl,
        'returnPolicyDays': _requiresReturnPolicy
            ? int.tryParse(_returnPolicyDaysController.text.trim()) ?? 14
            : null,
        'email': '',
        'ownerUid': '',
        'approvalStatus': 'pending',
        'isApproved': false,
        'temporarilyClosed': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final ownerEmail = _emailController.text.trim().toLowerCase();
      if (ownerEmail.isEmpty) {
        setState(() => _submitting = false);
        messenger.showSnackBar(
          const SnackBar(content: Text('أدخل بريدًا إلكترونيًا صحيحًا')),
        );
        return;
      }
      if (!_isAuthenticatedSubmit) {
        final password = _passwordController.text;
        if (password.length < 6) {
          setState(() => _submitting = false);
          messenger.showSnackBar(
            const SnackBar(
              content: Text('الحد الأدنى لطول كلمة المرور 6 أحرف'),
            ),
          );
          return;
        }
      }
      final callable = FirebaseFunctions.instanceFor(region: 'me-central1')
          .httpsCallable('submitRestaurantApplication');
      await callable.call({
        'email': ownerEmail,
        if (!_isAuthenticatedSubmit) 'password': _passwordController.text,
        'name': payload['name'],
        'businessType': payload['businessType'],
        'phone': payload['phone'],
        'commercialRecordNumber': payload['commercialRecordNumber'],
        'commercialRecordImageUrl': payload['commercialRecordImageUrl'],
        'pharmacyLicenseNumber': payload['pharmacyLicenseNumber'],
        'pharmacyLicenseImageUrl': payload['pharmacyLicenseImageUrl'],
        'returnPolicyDays': payload['returnPolicyDays'],
      });

      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('تم إرسال الطلب بنجاح. انتظر موافقة الإدارة.'),
        ),
      );
      Navigator.pop(context, true);
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final message = e.code == 'invalid-argument'
          ? 'بيانات الطلب غير مكتملة: ${e.message ?? e.code}'
          : 'تعذر إرسال الطلب (Cloud Function): ${e.message ?? e.code}';
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final message = 'تعذر إرسال الطلب: ${e.message ?? e.code}';
      messenger.showSnackBar(
        SnackBar(content: Text(message)),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final message = e.code == 'permission-denied'
          ? 'تم رفض العملية بسبب الصلاحيات. تأكد أنك تستخدم آخر نسخة من القواعد والتطبيق.'
          : 'تعذر إرسال الطلب: ${e.message ?? e.code}';
      messenger.showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(
        SnackBar(content: Text('تعذر إرسال الطلب: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('طلب ربط متجر'),
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'اسم المنشأة'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'الرجاء إدخال اسم المنشأة'
                      : null,
                ),
                const SizedBox(height: 12),
                const Text(
                  'اختر نوع قسمك',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const Text(
                  'سنجهز لك أدوات الإدارة المناسبة لطبيعة نشاطك.',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.8,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  children: _businessTypes.entries.map((entry) {
                    final selected = _businessType == entry.key;
                    final icon = switch (entry.key) {
                      'restaurant' => Icons.restaurant_rounded,
                      'grocery' => Icons.shopping_basket_rounded,
                      'pharmacy' => Icons.medication_rounded,
                      'brand' => Icons.sell_rounded,
                      _ => Icons.storefront_rounded,
                    };
                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _submitting
                          ? null
                          : () => setState(() => _businessType = entry.key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: selected
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.black12,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(icon,
                                color: selected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.black54),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(entry.value,
                                  style: TextStyle(
                                      fontWeight: selected
                                          ? FontWeight.w800
                                          : FontWeight.w600)),
                            ),
                            if (selected)
                              Icon(Icons.check_circle_rounded,
                                  color: Theme.of(context).colorScheme.primary),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration:
                      const InputDecoration(labelText: 'رقم جوال المنشأة'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'الرجاء إدخال رقم الجوال'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _recordNumberController,
                  decoration:
                      const InputDecoration(labelText: 'رقم السجل التجاري'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'الرجاء إدخال رقم السجل التجاري'
                      : null,
                ),
                if (_isPharmacy) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _pharmacyLicenseController,
                    decoration:
                        const InputDecoration(labelText: 'رقم ترخيص الصيدلية'),
                    validator: (value) =>
                        _isPharmacy && (value == null || value.trim().isEmpty)
                            ? 'الرجاء إدخال رقم ترخيص الصيدلية'
                            : null,
                  ),
                  const SizedBox(height: 8),
                  _pharmacyLicenseImage == null
                      ? const Text('لم يتم رفع صورة ترخيص الصيدلية بعد')
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(_pharmacyLicenseImage!,
                              height: 130, fit: BoxFit.cover),
                        ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _pickPharmacyLicenseImage,
                    icon: const Icon(Icons.medical_information_outlined),
                    label: const Text('رفع صورة ترخيص الصيدلية'),
                  ),
                ],
                if (_requiresReturnPolicy) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _returnPolicyDaysController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'مدة الاسترجاع بالأيام'),
                    validator: (value) {
                      if (!_requiresReturnPolicy) return null;
                      final days = int.tryParse((value ?? '').trim());
                      return days == null || days < 0 || days > 365
                          ? 'أدخل مدة بين 0 و365 يومًا'
                          : null;
                    },
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  readOnly: _isAuthenticatedSubmit,
                  decoration:
                      const InputDecoration(labelText: 'البريد الإلكتروني'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'الرجاء إدخال البريد الإلكتروني';
                    }
                    if (!v.contains('@')) {
                      return 'البريد الإلكتروني غير صالح';
                    }
                    return null;
                  },
                ),
                if (!_isAuthenticatedSubmit) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'كلمة المرور'),
                    validator: (v) {
                      if (v == null || v.length < 6) {
                        return 'الحد الأدنى لطول كلمة المرور 6 أحرف';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 12),
                _recordImage == null
                    ? const Text('لم يتم رفع صورة السجل التجاري بعد')
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(_recordImage!,
                            height: 160, fit: BoxFit.cover),
                      ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _pickRecordImage,
                  icon: const Icon(Icons.image),
                  label: const Text('رفع صورة السجل التجاري'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('إرسال الطلب'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
