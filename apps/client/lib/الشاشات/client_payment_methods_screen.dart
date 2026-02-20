// lib/screens/client_payment_methods_screen.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:getwidget/getwidget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloudinary_public/cloudinary_public.dart';

class ClientPaymentMethodsScreen extends StatefulWidget {
  const ClientPaymentMethodsScreen({Key? key}) : super(key: key);

  @override
  State<ClientPaymentMethodsScreen> createState() =>
      _ClientPaymentMethodsScreenState();
}

class _ClientPaymentMethodsScreenState
    extends State<ClientPaymentMethodsScreen> {
  final _cloudinary = CloudinaryPublic('dvnzloec6', 'flutter_unsigned');

  bool _loadingSettings = true;
  bool _loadingOrder = true;
  bool _submitting = false;

  String? _orderId;
  Map<String, dynamic>? _settings;
  Map<String, dynamic>? _orderData;

  String? _selectedMethod;
  String? _proofUrl;

  @override
  void initState() {
    super.initState();
    _orderId = Get.arguments as String?;
    if (_orderId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Get.back());
      return;
    }
    _loadSettings();
    _loadOrder();
  }

  Future<void> _loadSettings() async {
    final doc = await FirebaseFirestore.instance
        .collection('paymentSettings')
        .doc('default')
        .get();
    _settings = doc.data();
    setState(() => _loadingSettings = false);
  }

  Future<void> _loadOrder() async {
    final doc = await FirebaseFirestore.instance
        .collection('orders')
        .doc(_orderId)
        .get();
    _orderData = doc.data();
    setState(() => _loadingOrder = false);
  }

  Future<void> _pickProof() async {
    final img = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (img == null) return;
    final res = await _cloudinary.uploadFile(
      CloudinaryFile.fromFile(img.path, resourceType: CloudinaryResourceType.Image),
    );
    setState(() => _proofUrl = res.secureUrl);
  }

  Future<void> _submitPayment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // جلب بيانات العميل
    final userDoc = await FirebaseFirestore.instance.collection('clients').doc(user.uid).get();
    final wallet = (userDoc.data()?['wallet'] ?? 0).toDouble();
    final totalWithDelivery = (_orderData?['totalWithDelivery'] as num).toDouble();

    double remainingToPay = totalWithDelivery;
    // إذا كان هناك رصيد في المحفظة
    if (wallet > 0) {
      double usedFromWallet = wallet >= totalWithDelivery ? totalWithDelivery : wallet;
      remainingToPay = totalWithDelivery - usedFromWallet;
      // خصم ما يمكن من المحفظة
      await FirebaseFirestore.instance.collection('clients').doc(user.uid).update({
        'wallet': wallet - usedFromWallet,
      });
      // تحديث الطلب بقيمة ما تم دفعه من المحفظة
      await FirebaseFirestore.instance.collection('orders').doc(_orderId).update({
        'walletPaid': usedFromWallet,
        'walletUsed': true,
      });
      if (remainingToPay == 0) {
        // تم الدفع بالكامل من المحفظة
        await FirebaseFirestore.instance.collection('orders').doc(_orderId).update({
          'status': 'تم الدفع',
          'paymentStatus': 'تم الدفع',
          'paymentMethod': 'wallet',
        });
        setState(() => _submitting = false);
        Get.offAllNamed('/orderSuccess', arguments: {'orderId': _orderId});
        GFToast.showToast('تم خصم مبلغ الطلب من محفظتك بنجاح', context);
        return;
      } else {
        GFToast.showToast('تم خصم ${usedFromWallet.toStringAsFixed(2)} من محفظتك. المتبقي: ${remainingToPay.toStringAsFixed(2)} ج.س', context);
      }
    }

    // إذا بقي مبلغ يجب دفعه بوسيلة أخرى
    if (remainingToPay > 0) {
      if (_selectedMethod == null || _proofUrl == null) {
        GFToast.showToast('يرجى اختيار طريقة ورفع الإيصال لباقي المبلغ', context);
        return;
      }
      setState(() => _submitting = true);
      // إضافة إيصال الدفع في الفرعي payments
      final paymentRef = FirebaseFirestore.instance
          .collection('orders')
          .doc(_orderId)
          .collection('payments')
          .doc();
      await paymentRef.set({
        'method': _selectedMethod,
        'proofImageUrl': _proofUrl,
        'submittedAt': FieldValue.serverTimestamp(),
        'status': 'انتظار الدفع',
        'amount': remainingToPay,
        'type': 'order',
      });
      // تحديث حالة الطلب الرئيسي مع حفظ رابط الإيصال
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(_orderId)
          .update({
        'status': 'انتظار الدفع',
        'paymentStatus': 'انتظار الدفع',
        'remainingToPay': remainingToPay,
        'paymentMethod': _selectedMethod,
        'proofImageUrl': _proofUrl, // حفظ رابط صورة الإيصال في الطلب الرئيسي
      });

      // تحقق بعد التحديث أن الحقل تم حفظه فعلاً
      final updatedOrder = await FirebaseFirestore.instance.collection('orders').doc(_orderId).get();
      final updatedData = updatedOrder.data();
      if (updatedData == null || updatedData['proofImageUrl'] == null || updatedData['proofImageUrl'].toString().isEmpty) {
        setState(() => _submitting = false);
        GFToast.showToast('⚠️ حدث خطأ ولم يتم حفظ صورة الإيصال في الطلب. يرجى المحاولة مرة أخرى أو التواصل مع الدعم.', context);
        return;
      }

      setState(() => _submitting = false);
      // الانتقال إلى شاشة انتظار موافقة الأدمن
      Get.offNamed(
        '/paymentWaiting',
        arguments: {'orderId': _orderId},
      );
    }
  }

  Widget _buildRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  static const Color primaryColor = Color(0xFFFE724C);
  static const Color backgroundColor = Color(0xFFF5F5F5);

  @override
  Widget build(BuildContext context) {
    if (_loadingSettings || _loadingOrder) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final data = _orderData!;
    final subtotal = (data['total'] as num).toDouble();
    final deliveryFee = (data['deliveryFee'] as num).toDouble();
    final totalWithDelivery = (data['totalWithDelivery'] as num).toDouble();
    final methods = List<String>.from(_settings?['enabledMethods'] ?? []);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          centerTitle: true,
          title: const Text('طرق الدفع', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 20, fontFamily: 'Tajawal')),
          iconTheme: const IconThemeData(color: primaryColor),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Card(
              color: Colors.white,
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('تفاصيل الطلب', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal', fontSize: 20)),
                    const SizedBox(height: 18),
                    _buildRow('قيمة الأصناف', '${subtotal.toStringAsFixed(2)} ج.س'),
                    _buildRow('رسوم التوصيل', '${deliveryFee.toStringAsFixed(2)} ج.س'),
                    const Divider(),
                    _buildRow('الإجمالي الكلي', '${totalWithDelivery.toStringAsFixed(2)} ج.س', bold: true),
                    const SizedBox(height: 18),
                    const Text('1. اختر طريقة الدفع', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: methods.map((m) {
                        final label = _settings?['${m}Label'] ?? m;
                        final selected = _selectedMethod == m;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedMethod = m),
                            child: Container(
                              height: 48,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: selected ? primaryColor : Colors.grey[200],
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: selected ? primaryColor : Colors.grey[300]!),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.account_balance, color: selected ? Colors.white : primaryColor),
                                  const SizedBox(width: 6),
                                  Text(label, style: TextStyle(color: selected ? Colors.white : primaryColor, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    if (_selectedMethod != null && (_settings?['${_selectedMethod}Account'] ?? '').isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, color: primaryColor, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'اسم صاحب الحساب: ${_settings?['${_selectedMethod}AccountHolder'] ?? 'غير متوفر'}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'رقم الحساب: ${_settings?['${_selectedMethod}Account'] ?? ''}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 18),
                    const Text('2. ارفع صورة الإيصال', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _proofUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(_proofUrl!, height: 180, fit: BoxFit.cover),
                          )
                        : Container(
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey),
                            ),
                            child: const Center(child: Text('لم يتم اختيار صورة بعد')),
                          ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _pickProof,
                      icon: const Icon(Icons.image),
                      label: const Text('اختيار صورة الإيصال'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _submitting
                        ? const Center(child: GFLoader(type: GFLoaderType.circle))
                        : SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _submitPayment,
                              child: const Text('إرسال الدفع'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                textStyle: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
