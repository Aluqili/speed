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
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _recordNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  File? _recordImage;
  bool _submitting = false;

  bool get _isAuthenticatedSubmit => (widget.userId ?? '').isNotEmpty;

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

      final payload = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'commercialRecordNumber': _recordNumberController.text.trim(),
        'commercialRecordImageUrl': recordImageUrl,
        'email': '',
        'ownerUid': '',
        'approvalStatus': 'pending',
        'isApproved': false,
        'temporarilyClosed': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      String ownerUid;
      String ownerEmail;
      if (_isAuthenticatedSubmit) {
        ownerUid = widget.userId!;
        ownerEmail = _emailController.text.trim().toLowerCase();
      } else {
        final email = _emailController.text.trim().toLowerCase();
        if (email.isEmpty) {
          setState(() => _submitting = false);
          messenger.showSnackBar(
            const SnackBar(
              content: Text('أدخل بريدًا إلكترونيًا صحيحًا'),
            ),
          );
          return;
        }
        ownerUid = '';
        ownerEmail = email;
      }

      payload['email'] = ownerEmail;
      payload['ownerUid'] = ownerUid;

      if (_isAuthenticatedSubmit) {
        await FirebaseFirestore.instance
            .collection('restaurantApplications')
            .doc(ownerUid)
            .set({
          ...payload,
          'restaurantId': ownerUid,
          'status': 'pending',
          'submittedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
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

        final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
            .httpsCallable('submitRestaurantApplication');
        await callable.call({
          'email': ownerEmail,
          'password': password,
          'name': payload['name'],
          'phone': payload['phone'],
          'commercialRecordNumber': payload['commercialRecordNumber'],
          'commercialRecordImageUrl': payload['commercialRecordImageUrl'],
        });
      }

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
                  decoration: const InputDecoration(labelText: 'اسم المطعم'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'الرجاء إدخال اسم المطعم'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration:
                      const InputDecoration(labelText: 'رقم جوال المطعم'),
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
