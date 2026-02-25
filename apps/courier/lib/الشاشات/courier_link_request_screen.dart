import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';

class CourierLinkRequestScreen extends StatefulWidget {
  const CourierLinkRequestScreen({
    super.key,
    this.userId,
    this.email,
  });

  final String? userId;
  final String? email;

  @override
  State<CourierLinkRequestScreen> createState() => _CourierLinkRequestScreenState();
}

class _CourierLinkRequestScreenState extends State<CourierLinkRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _vehicleTypeController = TextEditingController();
  final _vehiclePlateController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  File? _idImage;
  bool _submitting = false;

  bool get _requiresAccountCreation => (widget.userId ?? '').isEmpty;

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
    _vehicleTypeController.dispose();
    _vehiclePlateController.dispose();
    _nationalIdController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickIdImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1500,
    );
    if (picked != null) {
      setState(() => _idImage = File(picked.path));
    }
  }

  Future<String?> _uploadImageToCloudinary(File imageFile) async {
    const cloudName = 'dvnzloec6';
    const uploadPreset = 'flutter_unsigned';

    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    final response = await request.send();
    if (response.statusCode != 200) return null;
    final payload = json.decode(await response.stream.bytesToString());
    return payload['secure_url'] as String?;
  }

  Future<Map<String, dynamic>> _submitCourierApplicationViaHttp({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String vehicleType,
    required String vehiclePlate,
    required String nationalIdNumber,
    required String idImageUrl,
  }) async {
    final uri = Uri.parse(
      'https://us-central1-speedstar-dev.cloudfunctions.net/submitCourierApplication',
    );

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'data': {
          'email': email,
          'password': password,
          'name': name,
          'phone': phone,
          'vehicleType': vehicleType,
          'vehiclePlate': vehiclePlate,
          'nationalIdNumber': nationalIdNumber,
          'idImageUrl': idImageUrl,
        }
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }

    final body = json.decode(response.body) as Map<String, dynamic>;
    if (body['error'] != null) {
      final err = body['error'];
      throw Exception((err is Map && err['message'] != null)
          ? err['message'].toString()
          : err.toString());
    }

    final result = (body['result'] is Map<String, dynamic>)
        ? body['result'] as Map<String, dynamic>
        : <String, dynamic>{};

    return result;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final messenger = ScaffoldMessenger.of(context);

    if (!_formKey.currentState!.validate()) return;
    if (_idImage == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('الرجاء رفع صورة الهوية/الرخصة')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final idImageUrl = await _uploadImageToCloudinary(_idImage!);
      if (idImageUrl == null) {
        setState(() => _submitting = false);
        messenger.showSnackBar(
          const SnackBar(content: Text('فشل رفع صورة الهوية/الرخصة')),
        );
        return;
      }

      String ownerUid;
      String ownerEmail;
      if (!_requiresAccountCreation) {
        ownerUid = widget.userId!;
        ownerEmail = _emailController.text.trim().toLowerCase();
      } else {
        final email = _emailController.text.trim().toLowerCase();
        final password = _passwordController.text;
        if (email.isEmpty || password.length < 6) {
          setState(() => _submitting = false);
          messenger.showSnackBar(
            const SnackBar(content: Text('أدخل بريدًا صحيحًا وكلمة مرور 6 أحرف فأكثر')),
          );
          return;
        }

        ownerUid = '';
        ownerEmail = email;

        try {
          final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
              .httpsCallable('submitCourierApplication');
          final response = await callable.call({
            'email': email,
            'password': password,
            'name': _nameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'vehicleType': _vehicleTypeController.text.trim(),
            'vehiclePlate': _vehiclePlateController.text.trim(),
            'nationalIdNumber': _nationalIdController.text.trim(),
            'idImageUrl': idImageUrl,
          });

          final data = Map<String, dynamic>.from(response.data as Map);
          ownerUid = (data['ownerUid'] ?? '').toString();
          ownerEmail = (data['email'] ?? email).toString();
        } catch (e) {
          final raw = e.toString();
          final channelFailure = raw.contains('CloudFunctionsHostApi.call') ||
              raw.contains('Unable to establish connection on channel');
          if (!channelFailure) rethrow;

          final data = await _submitCourierApplicationViaHttp(
            email: email,
            password: password,
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            vehicleType: _vehicleTypeController.text.trim(),
            vehiclePlate: _vehiclePlateController.text.trim(),
            nationalIdNumber: _nationalIdController.text.trim(),
            idImageUrl: idImageUrl,
          );
          ownerUid = (data['ownerUid'] ?? '').toString();
          ownerEmail = (data['email'] ?? email).toString();
        }

        if (ownerUid.isEmpty) {
          throw Exception('تعذر إنشاء طلب المندوب');
        }
      }

      final payload = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'vehicleType': _vehicleTypeController.text.trim(),
        'vehiclePlate': _vehiclePlateController.text.trim(),
        'nationalIdNumber': _nationalIdController.text.trim(),
        'idImageUrl': idImageUrl,
        'email': ownerEmail,
        'approvalStatus': 'pending',
        'isApproved': false,
        'available': false,
        'ownerUid': ownerUid,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!_requiresAccountCreation) {
        await FirebaseFirestore.instance
            .collection('courierApplications')
            .doc(ownerUid)
            .set({
          ...payload,
          'driverId': ownerUid,
          'status': 'pending',
          'submittedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('تم إرسال طلب المندوب. انتظر موافقة الإدارة.')),
      );
      Navigator.pop(context, true);
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final message = e.code == 'invalid-argument'
          ? 'بيانات الطلب غير مكتملة: ${e.message ?? e.code}'
          : 'تعذر إرسال الطلب (Cloud Function): ${e.message ?? e.code}';
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
        backgroundColor: AppThemeArabic.clientBackground,
        appBar: AppBar(
          title: const Text('طلب إنشاء حساب مندوب', style: TextStyle(color: AppThemeArabic.clientPrimary, fontWeight: FontWeight.bold, fontSize: 20, fontFamily: 'Tajawal')),
          backgroundColor: Colors.white,
          centerTitle: true,
          elevation: 1,
          iconTheme: const IconThemeData(color: AppThemeArabic.clientPrimary),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'اسم المندوب'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'الرجاء إدخال الاسم' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'رقم الجوال'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'الرجاء إدخال رقم الجوال' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _vehicleTypeController,
                  decoration: const InputDecoration(labelText: 'نوع المركبة'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'الرجاء إدخال نوع المركبة' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _vehiclePlateController,
                  decoration: const InputDecoration(labelText: 'رقم اللوحة'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'الرجاء إدخال رقم اللوحة' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nationalIdController,
                  decoration: const InputDecoration(labelText: 'رقم الهوية/الرخصة'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'الرجاء إدخال رقم الهوية/الرخصة' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  readOnly: !_requiresAccountCreation,
                  decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'الرجاء إدخال البريد الإلكتروني';
                    if (!v.contains('@')) return 'البريد الإلكتروني غير صالح';
                    return null;
                  },
                ),
                if (_requiresAccountCreation) ...[
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
                _idImage == null
                    ? const Text('لم يتم رفع صورة الهوية/الرخصة بعد')
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(_idImage!, height: 160, fit: BoxFit.cover),
                      ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _pickIdImage,
                  icon: const Icon(Icons.badge),
                  label: const Text('رفع صورة الهوية/الرخصة'),
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
