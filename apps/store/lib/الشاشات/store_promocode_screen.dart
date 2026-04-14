import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' as intl;
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';

class StorePromocodeScreen extends StatefulWidget {
  final String restaurantId;

  const StorePromocodeScreen({Key? key, required this.restaurantId})
      : super(key: key);

  @override
  State<StorePromocodeScreen> createState() => _StorePromocodeScreenState();
}

class _StorePromocodeScreenState extends State<StorePromocodeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _badgeTextController = TextEditingController();
  final _discountValueController = TextEditingController();
  final _maxDiscountController = TextEditingController();
  final _minOrderController = TextEditingController();
  final _cloudinary =
      CloudinaryPublic('dvnzloec6', 'flutter_unsigned', cache: false);

  String _discountScope = 'order_total';
  String _discountType = 'percent';
  DateTime? _startsAt;
  DateTime? _endsAt;
  String? _uploadedImageUrl;
  bool _submitting = false;
  bool _uploadingImage = false;
  final Set<String> _selectedItemIds = <String>{};
  final Map<String, Map<String, dynamic>> _selectedItems =
      <String, Map<String, dynamic>>{};

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _badgeTextController.dispose();
    _discountValueController.dispose();
    _maxDiscountController.dispose();
    _minOrderController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'غير محدد';
    return intl.DateFormat('yyyy/MM/dd - hh:mm a', 'ar').format(value);
  }

  String _formatOfferTimestamp(dynamic value) {
    if (value is Timestamp) {
      return intl.DateFormat('yyyy/MM/dd - hh:mm a', 'ar').format(value.toDate());
    }
    return '-';
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (picked == null) return;

    setState(() => _uploadingImage = true);
    try {
      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          File(picked.path).path,
          resourceType: CloudinaryResourceType.Image,
        ),
      );
      if (!mounted) return;
      setState(() {
        _uploadedImageUrl = response.secureUrl;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر رفع الصورة: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _uploadingImage = false);
      }
    }
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final now = DateTime.now();
    final initial = isStart
        ? (_startsAt ?? now.add(const Duration(hours: 1)))
        : (_endsAt ??
            (_startsAt?.add(const Duration(days: 1)) ??
                now.add(const Duration(days: 1))));

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;

    final value = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() {
      if (isStart) {
        _startsAt = value;
        if (_endsAt != null && !_endsAt!.isAfter(value)) {
          _endsAt = value.add(const Duration(hours: 4));
        }
      } else {
        _endsAt = value;
      }
    });
  }

  Future<void> _submitOffer() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startsAt == null || _endsAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدد وقت بداية ونهاية العرض.')),
      );
      return;
    }
    if (_discountScope == 'specific_items' && _selectedItemIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر وجبة واحدة على الأقل لهذا العرض.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'me-central1')
          .httpsCallable('submitStoreOfferRequest');

      await callable.call({
        'restaurantId': widget.restaurantId,
        'offer': {
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'badgeText': _badgeTextController.text.trim(),
          'discountScope': _discountScope,
          'discountType': _discountType,
          'discountValue': double.parse(_discountValueController.text.trim()),
          'maxDiscount':
              double.tryParse(_maxDiscountController.text.trim()) ?? 0,
          'minOrder': double.tryParse(_minOrderController.text.trim()) ?? 0,
          'startsAt': _startsAt!.toIso8601String(),
          'endsAt': _endsAt!.toIso8601String(),
          'imageUrl': _uploadedImageUrl ?? '',
          'targetItems': _selectedItems.values.toList(),
        },
      });

      _formKey.currentState!.reset();
      _titleController.clear();
      _descriptionController.clear();
      _badgeTextController.clear();
      _discountValueController.clear();
      _maxDiscountController.clear();
      _minOrderController.clear();

      if (!mounted) return;
      setState(() {
        _discountScope = 'order_total';
        _discountType = 'percent';
        _startsAt = null;
        _endsAt = null;
        _uploadedImageUrl = null;
        _selectedItemIds.clear();
        _selectedItems.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال العرض إلى الأدمن للمراجعة.')),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'تعذر إرسال العرض.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إرسال العرض: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Color _statusColor(String status, bool isActive) {
    switch (status) {
      case 'approved':
        return isActive ? Colors.green : Colors.blueGrey;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _statusLabel(String status, bool isActive) {
    switch (status) {
      case 'approved':
        return isActive ? 'معتمد ومفعل' : 'معتمد وموقوف';
      case 'rejected':
        return 'مرفوض';
      default:
        return 'بانتظار الموافقة';
    }
  }

  String _scopeLabel(String scope) {
    switch (scope) {
      case 'delivery_fee':
        return 'خصم على التوصيل';
      case 'specific_items':
        return 'خصم على وجبات محددة';
      default:
        return 'خصم على إجمالي الطلب';
    }
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeArabic.storeBackground,
      appBar: AppBar(
        title: const Text('عروض المطعم'),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.local_offer_outlined,
                      color: Colors.white, size: 34),
                  SizedBox(height: 16),
                  Text(
                    'أنشئ عرضك وأرسله للمراجعة',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'يمكنك طلب خصم على الطلب، على التوصيل، أو على وجبات محددة، ولن يظهر للعميل حتى يعتمد من الأدمن.',
                    style: TextStyle(
                        color: Colors.white70, fontFamily: 'Tajawal'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _sectionCard(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'إرسال عرض جديد',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'عنوان العرض',
                        hintText: 'مثال: خصم 20% على وجبات الغداء',
                      ),
                      validator: (value) => (value == null || value.trim().isEmpty)
                          ? 'أدخل عنوان العرض'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'وصف العرض',
                        hintText: 'اشرح الشروط والمزايا بشكل واضح للعميل',
                      ),
                      validator: (value) => (value == null || value.trim().isEmpty)
                          ? 'أدخل وصفًا للعرض'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _badgeTextController,
                      decoration: const InputDecoration(
                        labelText: 'وسم قصير اختياري',
                        hintText: 'مثال: لفترة محدودة',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _discountScope,
                            decoration:
                                const InputDecoration(labelText: 'نطاق الخصم'),
                            items: const [
                              DropdownMenuItem(
                                  value: 'order_total',
                                  child: Text('إجمالي الطلب')),
                              DropdownMenuItem(
                                  value: 'delivery_fee',
                                  child: Text('رسوم التوصيل')),
                              DropdownMenuItem(
                                  value: 'specific_items',
                                  child: Text('وجبات محددة')),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _discountScope = value;
                                if (value != 'specific_items') {
                                  _selectedItemIds.clear();
                                  _selectedItems.clear();
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _discountType,
                            decoration:
                                const InputDecoration(labelText: 'نوع الخصم'),
                            items: const [
                              DropdownMenuItem(
                                  value: 'percent', child: Text('نسبة مئوية')),
                              DropdownMenuItem(
                                  value: 'fixed', child: Text('مبلغ ثابت')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _discountType = value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _discountValueController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                              labelText: _discountType == 'percent'
                                  ? 'قيمة الخصم (%)'
                                  : 'قيمة الخصم (ج.س)',
                            ),
                            validator: (value) {
                              final parsed =
                                  double.tryParse((value ?? '').trim());
                              if (parsed == null || parsed <= 0) {
                                return 'أدخل قيمة خصم صحيحة';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _maxDiscountController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'سقف الخصم اختياري',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _minOrderController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'الحد الأدنى للطلب لتفعيل العرض',
                        hintText: '0 = بدون حد أدنى',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickDateTime(isStart: true),
                            icon: const Icon(Icons.schedule_outlined),
                            label: Text('يبدأ: ${_formatDate(_startsAt)}'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickDateTime(isStart: false),
                            icon: const Icon(Icons.event_available_outlined),
                            label: Text('ينتهي: ${_formatDate(_endsAt)}'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _uploadingImage ? null : _pickImage,
                      icon: _uploadingImage
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.image_outlined),
                      label: Text(_uploadedImageUrl == null
                          ? 'رفع صورة العرض'
                          : 'تغيير صورة العرض'),
                    ),
                    if (_uploadedImageUrl != null) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          _uploadedImageUrl!,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                    if (_discountScope == 'specific_items') ...[
                      const SizedBox(height: 16),
                      const Text(
                        'اختر الوجبات المشمولة بالعرض',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Tajawal'),
                      ),
                      const SizedBox(height: 10),
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('restaurants')
                            .doc(widget.restaurantId)
                            .collection('full_menu')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: CircularProgressIndicator(),
                            );
                          }
                          final docs = snapshot.data!.docs;
                          if (docs.isEmpty) {
                            return const Text(
                                'لا توجد أصناف متاحة للاختيار حالياً.');
                          }
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: docs.map((doc) {
                              final data = doc.data();
                              final itemName =
                                  (data['name'] ?? 'صنف').toString();
                              final selected = _selectedItemIds.contains(doc.id);
                              return FilterChip(
                                label: Text(itemName),
                                selected: selected,
                                onSelected: (value) {
                                  setState(() {
                                    if (value) {
                                      _selectedItemIds.add(doc.id);
                                      _selectedItems[doc.id] = {
                                        'itemId': doc.id,
                                        'name': itemName,
                                        'imageUrl':
                                            (data['imageUrl'] ?? '').toString(),
                                      };
                                    } else {
                                      _selectedItemIds.remove(doc.id);
                                      _selectedItems.remove(doc.id);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _submitting ? null : _submitOffer,
                        icon: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_outlined),
                        label: const Text('إرسال العرض للمراجعة'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: AppThemeArabic.storePrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'العروض المرسلة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                fontFamily: 'Tajawal',
              ),
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('storeOffers')
                  .where('restaurantId', isEqualTo: widget.restaurantId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data?.docs.toList() ?? [];
                docs.sort((a, b) {
                  final aTime = a.data()['updatedAt'];
                  final bTime = b.data()['updatedAt'];
                  final aMs =
                      aTime is Timestamp ? aTime.millisecondsSinceEpoch : 0;
                  final bMs =
                      bTime is Timestamp ? bTime.millisecondsSinceEpoch : 0;
                  return bMs.compareTo(aMs);
                });

                if (docs.isEmpty) {
                  return _sectionCard(
                    child: const Text(
                      'لم يتم إرسال أي عروض بعد.',
                      style: TextStyle(fontFamily: 'Tajawal'),
                    ),
                  );
                }

                return Column(
                  children: docs.map((doc) {
                    final data = doc.data();
                    final status = (data['status'] ?? 'pending').toString();
                    final isActive = data['isActive'] == true;
                    final color = _statusColor(status, isActive);
                    final targetItems =
                        (data['targetItems'] as List?) ?? const [];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: color.withValues(alpha: 0.24)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (data['title'] ?? '').toString(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 17,
                                        fontFamily: 'Tajawal',
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      (data['summaryText'] ?? '').toString(),
                                      style: const TextStyle(
                                        color:
                                            AppThemeArabic.storeTextSecondary,
                                        fontFamily: 'Tajawal',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  _statusLabel(status, isActive),
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Tajawal',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            (data['description'] ?? '').toString(),
                            style: const TextStyle(fontFamily: 'Tajawal'),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _metaChip(_scopeLabel(
                                  (data['discountScope'] ?? '').toString())),
                              _metaChip(
                                  'من ${_formatOfferTimestamp(data['startsAt'])}'),
                              _metaChip(
                                  'إلى ${_formatOfferTimestamp(data['endsAt'])}'),
                              if (targetItems.isNotEmpty)
                                _metaChip('${targetItems.length} وجبات محددة'),
                            ],
                          ),
                          if ((data['reviewNote'] ?? '')
                              .toString()
                              .trim()
                              .isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                'ملاحظة المراجعة: ${(data['reviewNote'] ?? '').toString()}',
                                style: const TextStyle(fontFamily: 'Tajawal'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppThemeArabic.storeSurface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          fontFamily: 'Tajawal',
        ),
      ),
    );
  }
}
