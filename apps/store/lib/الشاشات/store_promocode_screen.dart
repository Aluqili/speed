import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
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
  final _reviewNoteController = TextEditingController();
  final _buyQtyController = TextEditingController(text: '3');
  final _freeQtyController = TextEditingController(text: '1');
  final _bundleQtyController = TextEditingController(text: '2');
  final _bundlePriceController = TextEditingController();
  final _nthQtyController = TextEditingController(text: '2');
  final _nthPercentController = TextEditingController(text: '50');
  final _spendMinController = TextEditingController();
  final _spendPercentController = TextEditingController(text: '10');
  final _cloudinary =
      CloudinaryPublic('dvnzloec6', 'flutter_unsigned', cache: false);

  String _discountScope = 'order_total';
  String _discountType = 'percent';
  String _offerKind = 'discount';
  DateTime? _startsAt;
  DateTime? _endsAt;
  String? _uploadedImageUrl;
  bool _submitting = false;
  bool _uploadingImage = false;
  final Set<String> _selectedItemIds = <String>{};
  final Map<String, Map<String, dynamic>> _selectedItems =
      <String, Map<String, dynamic>>{};

  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startsAt = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute - (now.minute % 5),
    );
    _endsAt = _startsAt!.add(const Duration(days: 1));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _repairLegacyOfferOwnership();
    });
  }

  Future<void> _repairLegacyOfferOwnership() async {
    try {
      await FirebaseFunctions.instanceFor(region: 'me-central1')
          .httpsCallable('repairStoreOfferOwnership')
          .call({'restaurantId': widget.restaurantId});
    } catch (_) {
      // The normal offers query remains available for newly created offers.
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _badgeTextController.dispose();
    _discountValueController.dispose();
    _maxDiscountController.dispose();
    _minOrderController.dispose();
    _reviewNoteController.dispose();
    _buyQtyController.dispose();
    _freeQtyController.dispose();
    _bundleQtyController.dispose();
    _bundlePriceController.dispose();
    _nthQtyController.dispose();
    _nthPercentController.dispose();
    _spendMinController.dispose();
    _spendPercentController.dispose();
    super.dispose();
  }

  bool get _needsSpecificItems {
    return _offerKind == 'buy_x_get_y' ||
        _offerKind == 'bundle_price' ||
        _offerKind == 'nth_item_percent' ||
        _discountScope == 'specific_items';
  }

  Map<String, dynamic> _buildOfferRulePayload() {
    if (_offerKind == 'buy_x_get_y') {
      return {
        'type': 'buy_x_get_y',
        'buyQty': int.tryParse(_buyQtyController.text.trim()) ?? 3,
        'freeQty': int.tryParse(_freeQtyController.text.trim()) ?? 1,
        'applyOn': 'same_item',
      };
    }
    if (_offerKind == 'bundle_price') {
      return {
        'type': 'bundle_price',
        'bundleQty': int.tryParse(_bundleQtyController.text.trim()) ?? 2,
        'bundlePrice': double.tryParse(_bundlePriceController.text.trim()) ?? 0,
      };
    }
    if (_offerKind == 'nth_item_percent') {
      return {
        'type': 'nth_item_percent',
        'nthQty': int.tryParse(_nthQtyController.text.trim()) ?? 2,
        'percentOff': double.tryParse(_nthPercentController.text.trim()) ?? 50,
      };
    }
    if (_offerKind == 'spend_x_get_percent') {
      return {
        'type': 'spend_x_get_percent',
        'minSpend': double.tryParse(_spendMinController.text.trim()) ?? 0,
        'percentOff':
            double.tryParse(_spendPercentController.text.trim()) ?? 10,
      };
    }
    return {'type': 'discount'};
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'غير محدد';
    return intl.DateFormat('yyyy/MM/dd - hh:mm a', 'ar').format(value);
  }

  String _formatOfferTimestamp(dynamic value) {
    if (value is Timestamp) {
      return intl.DateFormat('yyyy/MM/dd - hh:mm a', 'ar')
          .format(value.toDate());
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
    if (_needsSpecificItems && _selectedItemIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر وجبة واحدة على الأقل لهذا العرض.')),
      );
      return;
    }

    if (_offerKind == 'discount') {
      final discountValue =
          double.tryParse(_discountValueController.text.trim()) ?? 0;
      if (discountValue <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('أدخل قيمة خصم صحيحة.')),
        );
        return;
      }
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
          'offerKind': _offerKind,
          'offerRule': _buildOfferRulePayload(),
          'discountScope': _discountScope,
          'discountType': _discountType,
          'discountValue':
              double.tryParse(_discountValueController.text.trim()) ?? 0,
          'maxDiscount':
              double.tryParse(_maxDiscountController.text.trim()) ?? 0,
          'minOrder': double.tryParse(_minOrderController.text.trim()) ?? 0,
          'startsAt': _startsAt!.toIso8601String(),
          'endsAt': _endsAt!.toIso8601String(),
          'imageUrl': _uploadedImageUrl ?? '',
          'targetItems': _selectedItems.values.toList(),
          'merchantReviewNote': _reviewNoteController.text.trim(),
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
      final now = DateTime.now();
      final nextStart = DateTime(
        now.year,
        now.month,
        now.day,
        now.hour,
        now.minute - (now.minute % 5),
      );
      setState(() {
        _offerKind = 'discount';
        _discountScope = 'order_total';
        _discountType = 'percent';
        _startsAt = nextStart;
        _endsAt = nextStart.add(const Duration(days: 1));
        _uploadedImageUrl = null;
        _selectedItemIds.clear();
        _selectedItems.clear();
        _reviewNoteController.clear();
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
                    'اطلب خصمًا على الطلب، التوصيل، أو وجبات محددة — بمجرد موافقة الأدمن يظهر العرض للعملاء فورًا.',
                    style:
                        TextStyle(color: Colors.white70, fontFamily: 'Tajawal'),
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
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
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
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
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
                    DropdownButtonFormField<String>(
                      value: _offerKind,
                      decoration: const InputDecoration(labelText: 'نوع العرض'),
                      items: const [
                        DropdownMenuItem(
                          value: 'discount',
                          child: Text('خصم مباشر'),
                        ),
                        DropdownMenuItem(
                          value: 'buy_x_get_y',
                          child: Text('اشترِ X وخذ Y مجانًا'),
                        ),
                        DropdownMenuItem(
                          value: 'bundle_price',
                          child: Text('باقة بسعر ثابت'),
                        ),
                        DropdownMenuItem(
                          value: 'nth_item_percent',
                          child: Text('خصم على كل قطعة رقم N'),
                        ),
                        DropdownMenuItem(
                          value: 'spend_x_get_percent',
                          child: Text('خصم عند تجاوز مبلغ شراء'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _offerKind = value;
                          if (_offerKind != 'discount') {
                            _discountScope = 'specific_items';
                          }
                          if (!_needsSpecificItems) {
                            _selectedItemIds.clear();
                            _selectedItems.clear();
                          }
                        });
                      },
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
                              if (_offerKind != 'discount') return;
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
                              if (_offerKind != 'discount') return;
                              if (value != null) {
                                setState(() => _discountType = value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_offerKind == 'discount')
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _discountValueController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
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
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'سقف الخصم اختياري',
                              ),
                            ),
                          ),
                        ],
                      )
                    else if (_offerKind == 'buy_x_get_y')
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _buyQtyController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: 'اشترِ كمية'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _freeQtyController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: 'كمية مجانية'),
                            ),
                          ),
                        ],
                      )
                    else if (_offerKind == 'bundle_price')
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _bundleQtyController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: 'عدد القطع في الباقة'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _bundlePriceController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                  labelText: 'سعر الباقة (ج.س)'),
                            ),
                          ),
                        ],
                      )
                    else if (_offerKind == 'nth_item_percent')
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _nthQtyController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: 'كل قطعة رقم N'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _nthPercentController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                  labelText: 'نسبة الخصم (%)'),
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _spendMinController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                  labelText: 'الحد الأدنى للشراء (ج.س)'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _spendPercentController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                  labelText: 'نسبة الخصم (%)'),
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
                    TextFormField(
                      controller: _reviewNoteController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظة للأدمن (اختياري)',
                        hintText: 'أي معلومات إضافية تريد إيصالها للمراجع',
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
                    if (_needsSpecificItems) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'اختر الوجبات المشمولة بالعرض',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontFamily: 'Tajawal'),
                      ),
                      const SizedBox(height: 10),
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('restaurants')
                            .doc(widget.restaurantId)
                            .collection('full_menu')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return const Text(
                              'تعذر تحميل أصناف المتجر. أعد فتح الصفحة ثم حاول مرة أخرى.',
                              style: TextStyle(fontFamily: 'Tajawal'),
                            );
                          }
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
                              final selected =
                                  _selectedItemIds.contains(doc.id);
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
              stream: _currentUserId == null
                  ? const Stream.empty()
                  : FirebaseFirestore.instance
                      .collection('storeOffers')
                      .where('ownerUid', isEqualTo: _currentUserId)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  final error = snapshot.error;
                  return _sectionCard(
                    child: Text(
                      'تعذر تحميل العروض: $error',
                      style: const TextStyle(fontFamily: 'Tajawal'),
                    ),
                  );
                }
                final docs = (snapshot.data?.docs.toList() ?? [])
                    .where((doc) =>
                        doc.data()['restaurantId']?.toString() ==
                        widget.restaurantId)
                    .toList();

                // Sort: active first, then pending, then rejected, then by updatedAt
                int _statusOrder(Map<String, dynamic> d) {
                  final s = (d['status'] ?? 'pending').toString();
                  final active = d['isActive'] == true;
                  if (s == 'approved' && active) return 0;
                  if (s == 'approved' && !active) return 1;
                  if (s == 'pending') return 2;
                  return 3;
                }

                docs.sort((a, b) {
                  final orderA = _statusOrder(a.data());
                  final orderB = _statusOrder(b.data());
                  if (orderA != orderB) return orderA.compareTo(orderB);
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
                    final isLive = status == 'approved' && isActive;
                    final color = _statusColor(status, isActive);
                    final targetItems =
                        (data['targetItems'] as List?) ?? const [];
                    final legacyReviewNote =
                        (data['reviewNote'] ?? '').toString().trim();
                    final merchantReviewNote = (data['merchantReviewNote'] ??
                            (status == 'pending' ? legacyReviewNote : ''))
                        .toString()
                        .trim();
                    final adminReviewNote = (data['adminReviewNote'] ??
                            (status == 'pending' ? '' : legacyReviewNote))
                        .toString()
                        .trim();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isLive ? const Color(0xFFF0FDF4) : Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: color.withValues(alpha: isLive ? 0.45 : 0.24),
                          width: isLive ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (isLive) ...[
                                const Icon(Icons.circle,
                                    size: 10, color: Colors.green),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                              const SizedBox(width: 8),
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
                                    fontSize: 13,
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
                          if (adminReviewNote.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: status == 'rejected'
                                    ? const Color(0xFFFFF1F2)
                                    : const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    status == 'rejected'
                                        ? Icons.info_outline
                                        : Icons.sticky_note_2_outlined,
                                    size: 16,
                                    color: status == 'rejected'
                                        ? Colors.red
                                        : Colors.orange,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'ملاحظة الأدمن: $adminReviewNote',
                                      style: TextStyle(
                                        fontFamily: 'Tajawal',
                                        color: status == 'rejected'
                                            ? Colors.red.shade700
                                            : Colors.orange.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (merchantReviewNote.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.chat_bubble_outline,
                                    size: 16,
                                    color: AppThemeArabic.storeTextSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'ملاحظتك: $merchantReviewNote',
                                      style: const TextStyle(
                                        fontFamily: 'Tajawal',
                                        color:
                                            AppThemeArabic.storeTextSecondary,
                                      ),
                                    ),
                                  ),
                                ],
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
