import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:getwidget/getwidget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloudinary_public/cloudinary_public.dart';

import '../الخدمات/promocode_service.dart';
import 'payment_waiting_screen.dart';

class PaymentScreen extends StatefulWidget {
  final String orderId;
  const PaymentScreen({Key? key, required this.orderId}) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  static const Color primaryColor = Color(0xFFFE724C);
  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color cardColor = Colors.white;
  final _cloudinary = CloudinaryPublic('dvnzloec6', 'flutter_unsigned');
  String? _selectedMethod;
  String? _proofUrl;
  bool _submitting = false;
  Map<String, dynamic>? _settings;
  late Future<Map<String, dynamic>> _orderFuture;

  // متغيرات الرمز الترويجي
  final _promocodeController = TextEditingController();
  PromocodeService? _promocodeService;
  Map<String, dynamic>? _promoData;
  String? _promoError;
  num _discount = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _orderFuture = _loadOrder();
    _promocodeService = PromocodeService();
  }

  Future<void> _loadSettings() async {
    final doc = await FirebaseFirestore.instance
        .collection('paymentSettings')
        .doc('default')
        .get();
    setState(() => _settings = doc.data());
  }

  Future<Map<String, dynamic>> _loadOrder() async {
    final doc = await FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .get();
    return doc.data()!;
  }

  Future<void> _pickProof() async {
    final img = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (img == null) return;
    final resp = await _cloudinary.uploadFile(
      CloudinaryFile.fromFile(
        img.path,
        resourceType: CloudinaryResourceType.Image,
      ),
    );
    setState(() => _proofUrl = resp.secureUrl);
  }

  Future<void> _submitPayment() async {
    if (_selectedMethod == null || _proofUrl == null) {
      GFToast.showToast('اختر طريقة الدفع وارفع الإيصال', context);
      return;
    }
    setState(() => _submitting = true);

    // 1. إنشاء مستند الدفع الفرعي داخل الطلب
    final paymentRef = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .collection('payments')
        .doc();
    await paymentRef.set({
      'method': _selectedMethod,
      'proofImageUrl': _proofUrl,
      'submittedAt': FieldValue.serverTimestamp(),
      'status': 'pending',
      if (_promoData != null) ...{
        'promocode': _promoData!['code'],
        'discount': _discount,
      }
    });

    // 2. تحديث حالة الطلب إلى انتظار موافقة الأدمن
    await FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .update({'status': 'pending_payment'});

    // 3. تحديث عدد مرات الاستخدام للرمز
    if (_promoData != null) {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      await _promocodeService!.incrementUsage(_promoData!['code'], userId);
    }

    setState(() => _submitting = false);

    // 4. الانتقال إلى شاشة الانتظار حتى يوافق الأدمن
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentWaitingScreen(orderId: widget.orderId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_settings == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: _orderFuture,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final data = snap.data!;
        final subtotal = (data['total'] as num).toDouble();
        final deliveryFee = (data['deliveryFee'] as num).toDouble();
        num totalWithDelivery = (data['totalWithDelivery'] as num).toDouble();
        if (_discount > 0) {
          totalWithDelivery -= _discount;
          if (totalWithDelivery < 0) totalWithDelivery = 0;
        }
        final methods = List<String>.from(_settings!['enabledMethods'] ?? []);
        final items = List<Map<String, dynamic>>.from(data['items'] ?? []);

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: backgroundColor,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 1,
              centerTitle: true,
              title: const Text('طريقة الدفع', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 20, fontFamily: 'Tajawal')),
              iconTheme: const IconThemeData(color: primaryColor),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
              ),
              automaticallyImplyLeading: true,
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // تفاصيل الطلب بنظام أسدال
                  ExpansionTile(
                    title: const Text('تفاصيل الطلب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: primaryColor, fontFamily: 'Tajawal')),
                    backgroundColor: cardColor,
                    collapsedBackgroundColor: cardColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    children: [
                      ...items.map((item) => ListTile(
                            leading: CircleAvatar(
                              backgroundColor: backgroundColor,
                              child: Text(
                                item['quantity'] != null ? '${item['quantity']}' : '؟',
                                style: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(
                              item['name'] ?? 'غير متوفر',
                              style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
                            ),
                            trailing: Text(
                              item['price'] != null ? '${item['price'].toString()} ج.س' : 'غير متوفر',
                              style: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                            ),
                          )),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // إدخال الرمز الترويجي
                  const Text('رمز العرض أو الخصم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryColor, fontFamily: 'Tajawal')),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _promocodeController,
                          decoration: InputDecoration(
                            hintText: 'ادخل الرمز هنا',
                            filled: true,
                            fillColor: cardColor,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          setState(() { _promoError = null; _promoData = null; _discount = 0; });
                          final code = _promocodeController.text.trim();
                          if (code.isEmpty) return;
                          final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
                          final restaurantId = (data['restaurantId'] ?? '').toString();
                          final promo = await _promocodeService!.validatePromocode(
                            code: code,
                            userId: userId,
                            orderTotal: subtotal + deliveryFee,
                            restaurantId: restaurantId,
                          );
                          if (promo == null) {
                              setState(() { _promoError = 'الرمز خاطئ'; _promoData = null; _discount = 0; });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(_promoError!, style: const TextStyle(fontFamily: 'Tajawal')),
                                  backgroundColor: Colors.red,
                                ),
                              );
                          } else {
                            // منطق الخيارات المتقدمة
                            // 1. خصم للطلبات الجديدة فقط
                            if (promo['onlyForNewOrders'] == true && (data['orderStatus'] != 'انتظار الدفع' && data['paymentStatus'] != 'انتظار الدفع')) {
                                setState(() { _promoError = 'هذا الرمز متاح للطلبات الجديدة فقط.'; _promoData = null; _discount = 0; });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(_promoError!, style: const TextStyle(fontFamily: 'Tajawal')),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                            }
                            // 2. خصم على صنف محدد
                            num discount = 0;
                            if (promo['itemName'] != null && promo['itemName'].toString().isNotEmpty) {
                              final item = items.firstWhere(
                                (i) => i['name'] == promo['itemName'],
                                orElse: () => <String, dynamic>{},
                              );
                              if (item.isEmpty) {
                                  setState(() { _promoError = 'الرمز يخص صنف محدد غير موجود في الطلب.'; _promoData = null; _discount = 0; });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(_promoError!, style: const TextStyle(fontFamily: 'Tajawal')),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                              }
                              if (promo['discountType'] == 'percent') {
                                discount = ((item['price'] as num) * (promo['discountValue'] as num) / 100).round();
                              } else {
                                discount = promo['discountValue'] as num;
                              }
                            } else {
                              // خصم عادي على كامل الطلب
                              if (promo['discountType'] == 'percent') {
                                discount = ((subtotal + deliveryFee) * (promo['discountValue'] as num) / 100).round();
                              } else {
                                discount = promo['discountValue'] as num;
                              }
                            }
                            // 3. تحقق من الحد الأدنى للطلب
                            if (promo['minOrder'] != null && (subtotal + deliveryFee) < promo['minOrder']) {
                                setState(() { _promoError = 'الطلب أقل من الحد الأدنى للخصم.'; _promoData = null; _discount = 0; });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(_promoError!, style: const TextStyle(fontFamily: 'Tajawal')),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                            }
                            setState(() {
                              _promoData = promo;
                              _discount = discount;
                              _promoError = null;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('تم تطبيق الرمز بنجاح! الخصم: -${discount.toString()} ج.س', style: const TextStyle(fontFamily: 'Tajawal')),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        ),
                        child: const Text('تطبيق', style: TextStyle(color: Colors.white, fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  if (_promoError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(_promoError!, style: const TextStyle(color: Colors.red, fontFamily: 'Tajawal')),
                    ),
                  if (_promoData != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('تم تطبيق الخصم: -${_discount.toString()} ج.س', style: const TextStyle(color: Colors.green, fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                    ),
                  const SizedBox(height: 16),

                  // صندوق القيم بشكل احترافي
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('قيمة الأصناف', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                            Text('${subtotal.toStringAsFixed(2)} ج.س', style: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('رسوم التوصيل', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                            Text('${deliveryFee.toStringAsFixed(2)} ج.س', style: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        if (_discount > 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('الخصم', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: Colors.green)),
                                Text('-${_discount.toString()} ج.س', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('الإجمالي الكلي', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('${totalWithDelivery.toStringAsFixed(2)} ج.س', style: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // طرق الدفع أفقي
                  const Text('اختر طريقة الدفع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryColor, fontFamily: 'Tajawal')),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: methods.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, idx) {
                        final m = methods[idx];
                        final label = m == 'bankk' ? 'بنكك' : m == 'ocash' ? 'أوكاش' : 'فوري';
                        final icon = m == 'bankk'
                            ? Icons.account_balance
                            : m == 'ocash'
                                ? Icons.phone_android
                                : Icons.payment;
                        final selected = _selectedMethod == m;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedMethod = m),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            decoration: BoxDecoration(
                              color: selected ? primaryColor.withOpacity(0.12) : cardColor,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: selected ? primaryColor : Colors.grey.shade300, width: selected ? 2 : 1),
                              boxShadow: selected ? [BoxShadow(color: primaryColor.withOpacity(0.08), blurRadius: 4)] : [],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(icon, color: primaryColor, size: 28),
                                const SizedBox(height: 6),
                                Text(label, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 15)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  // إظهار بيانات الطريقة المختارة فقط
                  if (_selectedMethod != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 18),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedMethod == 'bankk' ? 'رقم الحساب:' : _selectedMethod == 'ocash' ? 'رقم الحساب:' : 'رقم الحساب:',
                            style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: primaryColor),
                          ),
                          const SizedBox(height: 4),
                          Text(_settings!['${_selectedMethod}Account'] ?? '', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 15)),
                        ],
                      ),
                    ),
                  // رفع الإيصال
                  const Text('رفع صورة الإيصال', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryColor, fontFamily: 'Tajawal')),
                  const SizedBox(height: 8),
                  if (_proofUrl != null) ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(_proofUrl!, height: 120),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _pickProof,
                      icon: const Icon(Icons.upload, color: Colors.white),
                      label: const Text('اختر صورة الإيصال', style: TextStyle(color: Colors.white, fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // زر إرسال الدفع
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submitPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 18, fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
                        elevation: 2,
                      ),
                      child: _submitting
                          ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('إرسال الدفع', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}