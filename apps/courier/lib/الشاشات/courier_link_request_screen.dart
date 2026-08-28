import 'dart:convert';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'courier_ui.dart';
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
  State<CourierLinkRequestScreen> createState() =>
      _CourierLinkRequestScreenState();
}

class _CourierLinkRequestScreenState extends State<CourierLinkRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappPhoneController = TextEditingController();
  final _vehicleTypeController = TextEditingController();
  final _vehiclePlateController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  File? _idImage;
  bool _submitting = false;
  String? _selectedLocalityId;
  String? _selectedAreaId;

  bool get _requiresAccountCreation => (widget.userId ?? '').isEmpty;
  _WorkLocality? get _selectedLocality {
    final id = _selectedLocalityId;
    if (id == null) return null;
    for (final item in _khartoumLocalities) {
      if (item.id == id) return item;
    }
    return null;
  }

  _WorkArea? get _selectedArea {
    final locality = _selectedLocality;
    final id = _selectedAreaId;
    if (locality == null || id == null) return null;
    for (final item in locality.areas) {
      if (item.id == id) return item;
    }
    return null;
  }

  Map<String, dynamic> get _workAreaPayload {
    final locality = _selectedLocality;
    final area = _selectedArea;
    final localityName = locality?.name ?? '';
    final areaName = area?.name ?? '';
    final label = [
      'ولاية الخرطوم',
      if (localityName.isNotEmpty) localityName,
      if (areaName.isNotEmpty) areaName,
    ].join(' - ');

    return {
      'stateId': 'khartoum',
      'stateName': 'ولاية الخرطوم',
      'city': localityName,
      'region': label,
      'workStateId': 'khartoum',
      'workStateName': 'ولاية الخرطوم',
      'workLocalityId': locality?.id ?? '',
      'workLocalityName': localityName,
      'workAreaId': area?.id ?? '',
      'workAreaName': areaName,
      'workAreaLabel': label,
      'serviceArea': {
        'stateId': 'khartoum',
        'stateName': 'ولاية الخرطوم',
        'localityId': locality?.id ?? '',
        'localityName': localityName,
        'areaId': area?.id ?? '',
        'areaName': areaName,
        'label': label,
      },
    };
  }

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
    _whatsappPhoneController.dispose();
    _vehicleTypeController.dispose();
    _vehiclePlateController.dispose();
    _nationalIdController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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

  Future<Map<String, dynamic>> _submitCourierApplicationViaHttp({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String whatsappPhone,
    required String vehicleType,
    required String vehiclePlate,
    required String nationalIdNumber,
    required String idImageUrl,
    required Map<String, dynamic> workArea,
  }) async {
    final uri = Uri.parse(
      'https://me-central1-speedstar-prod-4c7c5.cloudfunctions.net/submitCourierApplication',
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
          'whatsappPhone': whatsappPhone,
          'vehicleType': vehicleType,
          'vehiclePlate': vehiclePlate,
          'nationalIdNumber': nationalIdNumber,
          'idImageUrl': idImageUrl,
          ...workArea,
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
    final workArea = _workAreaPayload;
    if (_idImage == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('الرجاء رفع صورة إثبات الشخصية')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final idImageUrl = await _uploadImageToCloudinary(_idImage!);
      if (idImageUrl == null) {
        setState(() => _submitting = false);
        messenger.showSnackBar(
          const SnackBar(content: Text('فشل رفع صورة إثبات الشخصية')),
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
        final confirmPassword = _confirmPasswordController.text;
        if (email.isEmpty || password.length < 6) {
          setState(() => _submitting = false);
          messenger.showSnackBar(
            const SnackBar(
                content: Text('أدخل بريدًا صحيحًا وكلمة مرور 6 أحرف فأكثر')),
          );
          return;
        }
        if (password != confirmPassword) {
          setState(() => _submitting = false);
          messenger.showSnackBar(
            const SnackBar(content: Text('كلمتا المرور غير متطابقتين')),
          );
          return;
        }

        ownerUid = '';
        ownerEmail = email;

        try {
          final callable = FirebaseFunctions.instanceFor(region: 'me-central1')
              .httpsCallable('submitCourierApplication');
          final response = await callable.call({
            'email': email,
            'password': password,
            'name': _nameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'whatsappPhone': _whatsappPhoneController.text.trim(),
            'vehicleType': _vehicleTypeController.text.trim(),
            'vehiclePlate': _vehiclePlateController.text.trim(),
            'nationalIdNumber': _nationalIdController.text.trim(),
            'idImageUrl': idImageUrl,
            ...workArea,
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
            whatsappPhone: _whatsappPhoneController.text.trim(),
            vehicleType: _vehicleTypeController.text.trim(),
            vehiclePlate: _vehiclePlateController.text.trim(),
            nationalIdNumber: _nationalIdController.text.trim(),
            idImageUrl: idImageUrl,
            workArea: workArea,
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
        'whatsappPhone': _whatsappPhoneController.text.trim(),
        'vehicleType': _vehicleTypeController.text.trim(),
        'vehiclePlate': _vehiclePlateController.text.trim(),
        'nationalIdNumber': _nationalIdController.text.trim(),
        'idImageUrl': idImageUrl,
        ...workArea,
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
        const SnackBar(
            content: Text('تم إرسال طلب المندوب. انتظر موافقة الإدارة.')),
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
        backgroundColor: Colors.transparent,
        appBar: buildCourierAppBar('طلب إنشاء حساب مندوب'),
        body: CourierPageBackground(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'اسم المندوب'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'الرجاء إدخال الاسم'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration:
                      const InputDecoration(labelText: 'رقم الهاتف (اختياري)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _whatsappPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration:
                      const InputDecoration(labelText: 'رقم واتساب (اختياري)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _vehicleTypeController,
                  decoration: const InputDecoration(labelText: 'نوع المركبة'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'الرجاء إدخال نوع المركبة'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _vehiclePlateController,
                  decoration:
                      const InputDecoration(labelText: 'رقم اللوحة (اختياري)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nationalIdController,
                  decoration: const InputDecoration(
                    labelText: 'رقم إثبات الشخصية',
                    hintText: 'مثال: رقم وطني، جواز سفر، إثبات شخصية',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'الرجاء إدخال رقم إثبات الشخصية'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  readOnly: !_requiresAccountCreation,
                  decoration:
                      const InputDecoration(labelText: 'البريد الإلكتروني'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'الرجاء إدخال البريد الإلكتروني';
                    }
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
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration:
                        const InputDecoration(labelText: 'تأكيد كلمة المرور'),
                    validator: (v) {
                      if (v != _passwordController.text) {
                        return 'كلمتا المرور غير متطابقتين';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedLocalityId,
                  decoration: const InputDecoration(
                    labelText: 'محلية العمل',
                    prefixIcon: Icon(Icons.map_outlined),
                  ),
                  items: _khartoumLocalities
                      .map(
                        (locality) => DropdownMenuItem(
                          value: locality.id,
                          child: Text(locality.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedLocalityId = value;
                      _selectedAreaId = null;
                    });
                  },
                  validator: (value) =>
                      value == null ? 'اختر محلية العمل' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedAreaId,
                  decoration: const InputDecoration(
                    labelText: 'منطقة العمل',
                    prefixIcon: Icon(Icons.location_city_outlined),
                  ),
                  items: (_selectedLocality?.areas ?? const <_WorkArea>[])
                      .map(
                        (area) => DropdownMenuItem(
                          value: area.id,
                          child: Text(area.name),
                        ),
                      )
                      .toList(),
                  onChanged: _selectedLocality == null
                      ? null
                      : (value) {
                          setState(() => _selectedAreaId = value);
                        },
                  validator: (value) =>
                      value == null ? 'اختر منطقة العمل' : null,
                ),
                const SizedBox(height: 12),
                _idImage == null
                    ? const Text('لم يتم رفع صورة إثبات الشخصية بعد')
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(_idImage!,
                            height: 160, fit: BoxFit.cover),
                      ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _pickIdImage,
                  icon: const Icon(Icons.badge),
                  label: const Text('رفع صورة إثبات الشخصية'),
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
      ),
    );
  }
}

class _WorkArea {
  const _WorkArea(this.id, this.name);

  final String id;
  final String name;
}

class _WorkLocality {
  const _WorkLocality(this.id, this.name, this.areas);

  final String id;
  final String name;
  final List<_WorkArea> areas;
}

const List<_WorkLocality> _khartoumLocalities = [
  _WorkLocality('khartoum', 'محلية الخرطوم', [
    _WorkArea('khartoum_center', 'وسط الخرطوم'),
    _WorkArea('riyadh', 'الرياض'),
    _WorkArea('manshiya', 'المنشية'),
    _WorkArea('arkawit', 'أركويت'),
    _WorkArea('alamarat', 'العمارات'),
    _WorkArea('alsahafa', 'الصحافة'),
    _WorkArea('jabra', 'جبرة'),
    _WorkArea('kalakla', 'الكلاكلة'),
    _WorkArea('soba', 'سوبا'),
    _WorkArea('alshajara', 'الشجرة'),
  ]),
  _WorkLocality('jabal_awliya', 'محلية جبل أولياء', [
    _WorkArea('jabal_awliya', 'جبل أولياء'),
    _WorkArea('alazhari', 'الأزهري'),
    _WorkArea('alengaz', 'الإنقاذ'),
    _WorkArea('alsalama', 'السلامة'),
    _WorkArea('alkalakla_south', 'الكلاكلة جنوب'),
    _WorkArea('mayu', 'مايو'),
    _WorkArea('soba_west', 'سوبا غرب'),
  ]),
  _WorkLocality('bahri', 'محلية بحري', [
    _WorkArea('bahri_center', 'وسط بحري'),
    _WorkArea('kafouri', 'كافوري'),
    _WorkArea('shambat', 'شمبات'),
    _WorkArea('halfaia', 'الحلفايا'),
    _WorkArea('alsamrab', 'السامراب'),
    _WorkArea('aldroshab', 'الدروشاب'),
    _WorkArea('almazad', 'المزاد'),
    _WorkArea('alshaabiya', 'الشعبية'),
  ]),
  _WorkLocality('east_nile', 'محلية شرق النيل', [
    _WorkArea('haj_yousif', 'الحاج يوسف'),
    _WorkArea('algeerif_east', 'الجريف شرق'),
    _WorkArea('alhalfaia_east', 'حلة كوكو'),
    _WorkArea('alshigla', 'الشقلة'),
    _WorkArea('alwadi_alakhder', 'الوادي الأخضر'),
    _WorkArea('alailafon', 'العيلفون'),
    _WorkArea('um_doum', 'أم دوم'),
  ]),
  _WorkLocality('omdurman', 'محلية أم درمان', [
    _WorkArea('omdurman_center', 'وسط أم درمان'),
    _WorkArea('almorada', 'الموردة'),
    _WorkArea('aburoof', 'أبروف'),
    _WorkArea('wad_nubawi', 'ود نوباوي'),
    _WorkArea('alabbasiya', 'العباسية'),
    _WorkArea('alfitihab', 'الفتيحاب'),
    _WorkArea('almahdiya', 'المهدية'),
  ]),
  _WorkLocality('karari', 'محلية كرري', [
    _WorkArea('karari', 'كرري'),
    _WorkArea('althawrat', 'الثورات'),
    _WorkArea('alwadi', 'الواحة'),
    _WorkArea('almanara', 'المنارة'),
    _WorkArea('alsarorab', 'السروراب'),
    _WorkArea('alhattana', 'الحتانة'),
  ]),
  _WorkLocality('ombada', 'محلية أمبدة', [
    _WorkArea('ombada', 'أمبدة'),
    _WorkArea('albugaa', 'البقعة'),
    _WorkArea('alsabeel', 'السبيل'),
    _WorkArea('alrashideen', 'الراشدين'),
    _WorkArea('dar_alsalam', 'دار السلام'),
    _WorkArea('alsouq_alshaabi_ombada', 'السوق الشعبي أمبدة'),
  ]),
];
