import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:getwidget/getwidget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:provider/provider.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';
import 'package:speedstar_core/speedstar_core.dart' show formatUnifiedOrderCode;

import '../الخدمات/promocode_service.dart';
import 'cart_provider.dart';
import 'client_order_details_screen.dart';

class PaymentScreen extends StatefulWidget {
  final String? orderId;
  final Map<String, dynamic>? draftOrderData;
  final bool clearCartOnSubmit;

  const PaymentScreen({
    Key? key,
    this.orderId,
    this.draftOrderData,
    this.clearCartOnSubmit = false,
  })  : assert(orderId != null || draftOrderData != null),
        super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  static const Color primaryColor = AppThemeArabic.clientPrimary;
  static const Color backgroundColor = AppThemeArabic.clientBackground;
  static const Color cardColor = Colors.white;
  static const String _paymentReviewStatus = 'قيد المراجعة';
  final _cloudinary = CloudinaryPublic('dvnzloec6', 'flutter_unsigned');
  String? _selectedMethod;
  String? _proofUrl;
  bool _submitting = false;
  Map<String, dynamic>? _settings;
  late Future<Map<String, dynamic>> _orderFuture;

  // متغيرات الرمز الترويجي
  final _promocodeController = TextEditingController();
  final _transactionRefController = TextEditingController();
  PromocodeService? _promocodeService;
  Map<String, dynamic>? _promoData;
  String? _promoError;
  num _discount = 0;

  String _promoReasonMessage(String? reason) {
    switch ((reason ?? '').trim()) {
      case 'not-found':
      case 'invalid-code':
        return 'الرمز غير صحيح.';
      case 'inactive':
        return 'هذا الرمز غير مفعل حالياً.';
      case 'expired':
        return 'انتهت صلاحية هذا الرمز.';
      case 'restaurant-mismatch':
        return 'هذا الرمز مخصص لمتجر آخر.';
      case 'min-order':
        return 'الطلب أقل من الحد الأدنى المطلوب للخصم.';
      case 'max-usage':
        return 'تم استهلاك الحد الأقصى لهذا الرمز.';
      case 'max-usage-per-user':
        return 'تم تجاوز الحد المسموح لك لاستخدام هذا الرمز.';
      case 'new-orders-only':
        return 'هذا الرمز مخصص للطلبات الجديدة فقط.';
      case 'item-mismatch':
        return 'هذا الرمز مرتبط بصنف غير موجود في الطلب.';
      default:
        return 'تعذر تطبيق الرمز حالياً. حاول مرة أخرى.';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _orderFuture = _loadOrder();
    _promocodeService = PromocodeService();
  }

  @override
  void dispose() {
    _promocodeController.dispose();
    _transactionRefController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('paymentSettings')
          .doc('default')
          .get();
      final data = doc.data();
      if (!mounted) return;
      setState(() {
        _settings = data ??
            {
              'enabledMethods': ['bankk', 'ocash', 'fawry'],
              'bankkAccount': '',
              'ocashAccount': '',
              'fawryAccount': '',
              'bankkAccountHolder': '',
              'ocashAccountHolder': '',
              'fawryAccountHolder': '',
            };
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _settings = {
          'enabledMethods': ['bankk', 'ocash', 'fawry'],
          'bankkAccount': '',
          'ocashAccount': '',
          'fawryAccount': '',
          'bankkAccountHolder': '',
          'ocashAccountHolder': '',
          'fawryAccountHolder': '',
        };
      });
      debugPrint('paymentSettings fallback used: $e');
    }
  }

  Future<Map<String, dynamic>> _loadOrder() async {
    if (widget.orderId == null) {
      return Map<String, dynamic>.from(widget.draftOrderData!);
    }

    final doc = await FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId!)
        .get();
    return doc.data()!;
  }

  double _resolveWalletBalance(Map<String, dynamic>? data) {
    if (data == null) return 0.0;
    final candidates = [data['walletBalance'], data['wallet'], data['balance']];
    for (final candidate in candidates) {
      if (candidate is num) return candidate.toDouble();
      final parsed = double.tryParse((candidate ?? '').toString());
      if (parsed != null) return parsed;
    }
    return 0.0;
  }

  Map<String, double> _buildWalletPreview({
    required double totalAmount,
    required double walletBalance,
  }) {
    final normalizedTotal = totalAmount < 0 ? 0.0 : totalAmount;
    final normalizedBalance = walletBalance < 0 ? 0.0 : walletBalance;
    final walletRequestedAmount = normalizedBalance < normalizedTotal
        ? normalizedBalance
        : normalizedTotal;
    final amountDueAfterWallet = normalizedTotal - walletRequestedAmount;

    return {
      'walletRequestedAmount': walletRequestedAmount,
      'amountDueAfterWallet':
          amountDueAfterWallet < 0 ? 0.0 : amountDueAfterWallet,
      'walletBalanceAfterPreview':
          (normalizedBalance - walletRequestedAmount) < 0
              ? 0.0
              : (normalizedBalance - walletRequestedAmount),
    };
  }

  Map<String, dynamic> _buildWalletPaymentFields({
    required double totalAmount,
    required double walletBalance,
  }) {
    final preview = _buildWalletPreview(
      totalAmount: totalAmount,
      walletBalance: walletBalance,
    );
    return {
      'walletRequestedAmount': preview['walletRequestedAmount']!,
      'walletBalanceBeforePayment': walletBalance < 0 ? 0.0 : walletBalance,
      'walletBalanceAfterPreview': preview['walletBalanceAfterPreview']!,
      'amountDueAfterWallet': preview['amountDueAfterWallet']!,
      'walletSettledAt': null,
      'walletUsedAmount': null,
      'walletBalanceBeforeDebit': null,
      'walletBalanceAfterDebit': null,
      'externalPaidAmount': null,
    };
  }

  String _paymentMethodLabel(String method) {
    switch (method) {
      case 'wallet':
        return 'المحفظة';
      case 'bankk':
        return 'بنكك';
      case 'ocash':
        return 'أوكاش';
      default:
        return 'فوري';
    }
  }

  IconData _paymentMethodIcon(String method) {
    switch (method) {
      case 'wallet':
        return Icons.account_balance_wallet;
      case 'bankk':
        return Icons.account_balance;
      case 'ocash':
        return Icons.phone_android;
      default:
        return Icons.payment;
    }
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
    if (!mounted) return;
    setState(() => _proofUrl = resp.secureUrl);
  }

  Future<void> _submitPayment() async {
    final transactionReference = _transactionRefController.text.trim();
    if (_selectedMethod == null) {
      GFToast.showToast('اختر طريقة الدفع أولاً', context);
      return;
    }
    if (!mounted) return;
    setState(() => _submitting = true);

    try {
      final orderData = await _orderFuture;
      final subtotal = (orderData['total'] as num?)?.toDouble() ?? 0.0;
      final deliveryFee = (orderData['deliveryFee'] as num?)?.toDouble() ?? 0.0;
      final largeOrderFee =
          (orderData['largeOrderFee'] as num?)?.toDouble() ?? 0.0;
      final restaurantId = (orderData['restaurantId'] ?? '').toString();
      final clientId = (orderData['clientId'] ?? '').toString().trim();
      final items =
          List<Map<String, dynamic>>.from(orderData['items'] ?? const []);
      final baseTotal = (orderData['totalWithDelivery'] as num?)?.toDouble() ??
          (subtotal + deliveryFee + largeOrderFee);

      String generatedOrderCode = formatUnifiedOrderCode(
        orderNumber: orderData['orderNumber'],
        orderId: orderData['orderId'],
        docId: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      Map<String, dynamic>? redeemedPromo;
      if (_promoData != null) {
        final redeem = await _promocodeService!.redeemPromocode(
          code: (_promoData!['code'] ?? '').toString(),
          subtotal: subtotal,
          deliveryFee: deliveryFee,
          largeOrderFee: largeOrderFee,
          restaurantId: restaurantId,
          items: items,
          orderReference: widget.orderId ?? generatedOrderCode,
          isNewOrder: widget.orderId == null,
        );

        if (redeem['ok'] != true) {
          if (!mounted) return;
          setState(() => _submitting = false);
          GFToast.showToast(
              _promoReasonMessage(redeem['reason']?.toString()), context);
          return;
        }
        redeemedPromo = redeem;
      }

      final finalTotalAfterDiscount = redeemedPromo != null
          ? ((redeemedPromo['totalAfterDiscount'] as num?)?.toDouble() ??
              (baseTotal -
                  ((redeemedPromo['discountAmount'] as num?)?.toDouble() ?? 0)))
          : baseTotal;

      double walletBalance = 0.0;
      if (clientId.isNotEmpty) {
        final clientDoc = await FirebaseFirestore.instance
            .collection('clients')
            .doc(clientId)
            .get();
        walletBalance = _resolveWalletBalance(clientDoc.data());
      }
      final walletFields = _buildWalletPaymentFields(
        totalAmount:
            finalTotalAfterDiscount < 0 ? 0.0 : finalTotalAfterDiscount,
        walletBalance: walletBalance,
      );
      final walletRequestedAmount =
          (walletFields['walletRequestedAmount'] as num?)?.toDouble() ?? 0.0;
      final amountDueAfterWallet =
          (walletFields['amountDueAfterWallet'] as num?)?.toDouble() ?? 0.0;
      final isWalletOnly = _selectedMethod == 'wallet';

      if (isWalletOnly && amountDueAfterWallet > 0) {
        if (!mounted) return;
        setState(() => _submitting = false);
        GFToast.showToast(
          'رصيد المحفظة لا يكفي لتغطية كامل الطلب. اختر طريقة أخرى لإكمال الباقي.',
          context,
        );
        return;
      }

      if (!isWalletOnly &&
          (_proofUrl == null || transactionReference.isEmpty)) {
        if (!mounted) return;
        setState(() => _submitting = false);
        GFToast.showToast(
          'ارفع الإيصال وأدخل الرقم المرجعي للمبلغ المتبقي بعد خصم المحفظة.',
          context,
        );
        return;
      }

      final transactionReferenceToStore = isWalletOnly
          ? 'wallet-auto-${DateTime.now().millisecondsSinceEpoch}'
          : transactionReference;

      var targetOrderId = widget.orderId;
      if (targetOrderId == null) {
        final draft = Map<String, dynamic>.from(widget.draftOrderData!);
        draft['orderId'] = generatedOrderCode;
        draft['orderNumber'] = generatedOrderCode;
        draft['status'] = isWalletOnly ? 'store_pending' : 'payment_review';
        draft['orderStatus'] =
            isWalletOnly ? 'store_pending' : 'payment_review';
        draft['paymentStatus'] = isWalletOnly ? 'paid' : _paymentReviewStatus;
        draft['paymentMethod'] = _selectedMethod;
        draft['transactionReference'] = transactionReferenceToStore;
        draft['paymentReviewDecision'] = isWalletOnly ? 'approved' : 'pending';
        draft['paymentReviewRequired'] = !isWalletOnly;
        draft['paymentReviewReason'] =
            isWalletOnly ? 'wallet_auto_paid' : 'awaiting_admin_review';
        if (!isWalletOnly) {
          draft['proofImageUrl'] = _proofUrl;
        }
        if (isWalletOnly) {
          draft['paidAt'] = FieldValue.serverTimestamp();
          draft['paymentReviewedAt'] = FieldValue.serverTimestamp();
        }
        if (redeemedPromo != null) {
          final discountAmount =
              (redeemedPromo['discountAmount'] as num?)?.toDouble() ?? 0;
          final draftBaseTotal =
              ((draft['totalWithDelivery'] as num?)?.toDouble() ?? 0);
          final finalTotal =
              (redeemedPromo['totalAfterDiscount'] as num?)?.toDouble() ??
                  (draftBaseTotal - discountAmount);
          draft['discountAmount'] = discountAmount;
          draft['discountCode'] = (redeemedPromo['code'] ?? '').toString();
          draft['promocode'] = redeemedPromo['promo'];
          draft['totalBeforeDiscount'] = draftBaseTotal;
          draft['totalWithDelivery'] = finalTotal < 0 ? 0 : finalTotal;
        }
        draft.addAll(walletFields);
        draft['createdAt'] = FieldValue.serverTimestamp();
        final created =
            await FirebaseFirestore.instance.collection('orders').add(draft);
        targetOrderId = created.id;
      }

      final paymentRef = FirebaseFirestore.instance
          .collection('orders')
          .doc(targetOrderId)
          .collection('payments')
          .doc();
      await paymentRef.set({
        'method': _selectedMethod,
        'proofImageUrl': _proofUrl,
        'transactionReference': transactionReferenceToStore,
        'submittedAt': FieldValue.serverTimestamp(),
        'status': isWalletOnly ? 'paid' : 'under_review',
        'walletRequestedAmount': walletRequestedAmount,
        'amountDueAfterWallet': amountDueAfterWallet,
        if (redeemedPromo != null) ...{
          'promocode': redeemedPromo['code'],
          'discount': redeemedPromo['discountAmount'],
          'promoDetails': redeemedPromo['promo'],
        }
      });

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(targetOrderId)
          .update({
        'status': isWalletOnly ? 'store_pending' : 'payment_review',
        'orderStatus': isWalletOnly ? 'store_pending' : 'payment_review',
        'paymentStatus': isWalletOnly ? 'paid' : _paymentReviewStatus,
        'paymentMethod': _selectedMethod,
        'proofImageUrl': isWalletOnly ? FieldValue.delete() : _proofUrl,
        'transactionReference': transactionReferenceToStore,
        'paymentReviewDecision': isWalletOnly ? 'approved' : 'pending',
        'paymentReviewRequired': !isWalletOnly,
        'paymentReviewReason':
            isWalletOnly ? 'wallet_auto_paid' : 'awaiting_admin_review',
        'walletAutoConfirmedAt':
            isWalletOnly ? FieldValue.serverTimestamp() : FieldValue.delete(),
        'paidAt':
            isWalletOnly ? FieldValue.serverTimestamp() : FieldValue.delete(),
        ...walletFields,
        if (redeemedPromo != null) ...{
          'discountAmount': redeemedPromo['discountAmount'],
          'discountCode': redeemedPromo['code'],
          'promocode': redeemedPromo['promo'],
          'totalBeforeDiscount':
              (orderData['totalWithDelivery'] as num?)?.toDouble() ?? 0,
          'totalWithDelivery': (redeemedPromo['totalAfterDiscount'] as num?)
                  ?.toDouble() ??
              (((orderData['totalWithDelivery'] as num?)?.toDouble() ?? 0) -
                  ((redeemedPromo['discountAmount'] as num?)?.toDouble() ?? 0)),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      if (widget.clearCartOnSubmit) {
        final cart = Provider.of<CartProvider?>(context, listen: false);
        cart?.clearCart();
      }
      setState(() => _submitting = false);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ClientOrderDetailsScreen(orderId: targetOrderId!),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      GFToast.showToast(
        'تعذر إرسال الدفع: ${e.message ?? e.code}',
        context,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      GFToast.showToast('تعذر إرسال الدفع، حاول مرة أخرى', context);
    }
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
        final largeOrderFee =
            (data['largeOrderFee'] as num?)?.toDouble() ?? 0.0;
        num totalWithDelivery = (data['totalWithDelivery'] as num).toDouble();
        if (_discount > 0) {
          totalWithDelivery -= _discount;
          if (totalWithDelivery < 0) totalWithDelivery = 0;
        }
        final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
        final clientId = (data['clientId'] ?? '').toString().trim();

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: clientId.isEmpty
              ? null
              : FirebaseFirestore.instance
                  .collection('clients')
                  .doc(clientId)
                  .snapshots(),
          builder: (context, walletSnap) {
            final walletBalance =
                _resolveWalletBalance(walletSnap.data?.data());
            final walletPreview = _buildWalletPreview(
              totalAmount: totalWithDelivery.toDouble(),
              walletBalance: walletBalance,
            );
            final walletRequestedAmount =
                walletPreview['walletRequestedAmount'] ?? 0.0;
            final amountDueAfterWallet =
                walletPreview['amountDueAfterWallet'] ??
                    totalWithDelivery.toDouble();
            final methods =
                List<String>.from(_settings!['enabledMethods'] ?? []);
            if (walletBalance > 0 && !methods.contains('wallet')) {
              methods.insert(0, 'wallet');
            }

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                backgroundColor: backgroundColor,
                appBar: AppBar(
                  backgroundColor: Colors.white,
                  elevation: 1,
                  centerTitle: true,
                  title: const Text('طريقة الدفع',
                      style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          fontFamily: 'Tajawal')),
                  iconTheme: const IconThemeData(color: primaryColor),
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(bottom: Radius.circular(18)),
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
                        title: const Text('تفاصيل الطلب',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: primaryColor,
                                fontFamily: 'Tajawal')),
                        backgroundColor: cardColor,
                        collapsedBackgroundColor: cardColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        children: [
                          ...items.map((item) => ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: backgroundColor,
                                  child: Text(
                                    item['quantity'] != null
                                        ? '${item['quantity']}'
                                        : '؟',
                                    style: const TextStyle(
                                        color: primaryColor,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Text(
                                  (() {
                                    final name = (item['name'] ?? 'غير متوفر')
                                        .toString();
                                    final sizeLabel = (item['sizeLabel'] ?? '')
                                        .toString()
                                        .trim();
                                    if (sizeLabel.isEmpty) return name;
                                    return '$name - $sizeLabel';
                                  })(),
                                  style: const TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontWeight: FontWeight.bold),
                                ),
                                trailing: Text(
                                  item['price'] != null
                                      ? '${item['price'].toString()} ج.س'
                                      : 'غير متوفر',
                                  style: const TextStyle(
                                      color: primaryColor,
                                      fontWeight: FontWeight.bold),
                                ),
                              )),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // إدخال الرمز الترويجي
                      const Text('رمز العرض أو الخصم',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: primaryColor,
                              fontFamily: 'Tajawal')),
                      const SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _promocodeController,
                            decoration: InputDecoration(
                              hintText: 'ادخل الرمز هنا',
                              filled: true,
                              fillColor: cardColor,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                setState(() {
                                  _promoError = null;
                                  _promoData = null;
                                  _discount = 0;
                                });
                                final code = _promocodeController.text.trim();
                                if (code.isEmpty) return;
                                final restaurantId =
                                    (data['restaurantId'] ?? '').toString();
                                final promo =
                                    await _promocodeService!.validatePromocode(
                                  code: code,
                                  subtotal: subtotal,
                                  deliveryFee: deliveryFee,
                                  largeOrderFee: largeOrderFee,
                                  restaurantId: restaurantId,
                                  items: items,
                                  isNewOrder: widget.orderId == null,
                                );
                                if (!mounted) {
                                  return;
                                }
                                if (promo == null || promo['ok'] != true) {
                                  setState(() {
                                    _promoError = _promoReasonMessage(
                                      promo == null
                                          ? 'invalid-code'
                                          : promo['reason']?.toString(),
                                    );
                                    _promoData = null;
                                    _discount = 0;
                                  });
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(_promoError!,
                                          style: const TextStyle(
                                              fontFamily: 'Tajawal')),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                } else {
                                  final discount =
                                      (promo['discountAmount'] as num?) ?? 0;
                                  setState(() {
                                    _promoData = promo;
                                    _discount = discount;
                                    _promoError = null;
                                  });
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'تم تطبيق الرمز بنجاح! الخصم: -${discount.toString()} ج.س',
                                          style: const TextStyle(
                                              fontFamily: 'Tajawal')),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 12),
                              ),
                              child: const Text('تطبيق',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'Tajawal',
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                      if (_promoError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(_promoError!,
                              style: const TextStyle(
                                  color: Colors.red, fontFamily: 'Tajawal')),
                        ),
                      if (_promoData != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                              'تم تطبيق الخصم: -${_discount.toString()} ج.س',
                              style: const TextStyle(
                                  color: Colors.green,
                                  fontFamily: 'Tajawal',
                                  fontWeight: FontWeight.bold)),
                        ),
                      const SizedBox(height: 16),

                      // صندوق القيم بشكل احترافي
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 18),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: Colors.black12, blurRadius: 4)
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('قيمة الأصناف',
                                    style: TextStyle(
                                        fontFamily: 'Tajawal',
                                        fontWeight: FontWeight.bold)),
                                Text('${subtotal.toStringAsFixed(2)} ج.س',
                                    style: const TextStyle(
                                        color: primaryColor,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('رسوم التوصيل',
                                    style: TextStyle(
                                        fontFamily: 'Tajawal',
                                        fontWeight: FontWeight.bold)),
                                Text('${deliveryFee.toStringAsFixed(2)} ج.س',
                                    style: const TextStyle(
                                        color: primaryColor,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                            if (largeOrderFee > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('رسوم الطلبات الكبيرة',
                                        style: TextStyle(
                                            fontFamily: 'Tajawal',
                                            fontWeight: FontWeight.bold)),
                                    Text(
                                        '${largeOrderFee.toStringAsFixed(2)} ج.س',
                                        style: const TextStyle(
                                            color: primaryColor,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            if (_discount > 0)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('الخصم',
                                        style: TextStyle(
                                            fontFamily: 'Tajawal',
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green)),
                                    Text('-${_discount.toString()} ج.س',
                                        style: const TextStyle(
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            if (walletRequestedAmount > 0)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('رصيد المحفظة الحالي',
                                        style: TextStyle(
                                            fontFamily: 'Tajawal',
                                            fontWeight: FontWeight.bold)),
                                    Text(
                                        '${walletBalance.toStringAsFixed(2)} ج.س',
                                        style: const TextStyle(
                                            color: primaryColor,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            if (walletRequestedAmount > 0)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('سيخصم من المحفظة عند الدفع',
                                        style: TextStyle(
                                            fontFamily: 'Tajawal',
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green)),
                                    Text(
                                        '-${walletRequestedAmount.toStringAsFixed(2)} ج.س',
                                        style: const TextStyle(
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('الإجمالي قبل المحفظة',
                                    style: TextStyle(
                                        fontFamily: 'Tajawal',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                                Text(
                                    '${totalWithDelivery.toStringAsFixed(2)} ج.س',
                                    style: const TextStyle(
                                        color: primaryColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                              ],
                            ),
                            if (walletRequestedAmount > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('المبلغ المتبقي للدفع الآن',
                                        style: TextStyle(
                                            fontFamily: 'Tajawal',
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: primaryColor)),
                                    Text(
                                      '${amountDueAfterWallet.toStringAsFixed(2)} ج.س',
                                      style: const TextStyle(
                                          color: primaryColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // طرق الدفع أفقي
                      const Text('اختر طريقة الدفع',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: primaryColor,
                              fontFamily: 'Tajawal')),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 80,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: methods.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, idx) {
                            final m = methods[idx];
                            final label = _paymentMethodLabel(m);
                            final icon = _paymentMethodIcon(m);
                            final selected = _selectedMethod == m;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedMethod = m),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 10),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? primaryColor.withValues(alpha: 0.12)
                                      : cardColor,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                      color: selected
                                          ? primaryColor
                                          : Colors.grey.shade300,
                                      width: selected ? 2 : 1),
                                  boxShadow: selected
                                      ? [
                                          BoxShadow(
                                              color: primaryColor.withValues(
                                                  alpha: 0.08),
                                              blurRadius: 4)
                                        ]
                                      : [],
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(icon, color: primaryColor, size: 28),
                                    const SizedBox(height: 6),
                                    Text(label,
                                        style: const TextStyle(
                                            fontFamily: 'Tajawal',
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15)),
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
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 18),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(color: Colors.black12, blurRadius: 2)
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_selectedMethod == 'wallet') ...[
                                Text(
                                  amountDueAfterWallet > 0
                                      ? 'المحفظة ستغطي ${walletRequestedAmount.toStringAsFixed(2)} ج.س ويتبقى ${amountDueAfterWallet.toStringAsFixed(2)} ج.س، لذلك يلزمك اختيار طريقة أخرى لباقي المبلغ.'
                                      : 'سيتم سداد الطلب كاملًا من المحفظة وخصم ${walletRequestedAmount.toStringAsFixed(2)} ج.س عند تأكيد الطلب.',
                                  style: const TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'الرصيد بعد الخصم: ${(walletBalance - walletRequestedAmount).toStringAsFixed(2)} ج.س',
                                  style: const TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize: 15,
                                  ),
                                ),
                              ] else ...[
                                Text(
                                  'اسم صاحب الحساب:',
                                  style: const TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                    ((_settings!['${_selectedMethod}AccountHolder'] ??
                                                _settings![
                                                    '${_selectedMethod}Holder'] ??
                                                '')
                                            .toString()
                                            .trim()
                                            .isEmpty)
                                        ? 'غير متوفر'
                                        : (_settings![
                                                    '${_selectedMethod}AccountHolder'] ??
                                                _settings![
                                                    '${_selectedMethod}Holder'] ??
                                                '')
                                            .toString(),
                                    style: const TextStyle(
                                        fontFamily: 'Tajawal', fontSize: 15)),
                                const SizedBox(height: 10),
                                Text(
                                  _selectedMethod == 'bankk'
                                      ? 'رقم الحساب:'
                                      : _selectedMethod == 'ocash'
                                          ? 'رقم الحساب:'
                                          : 'رقم الحساب:',
                                  style: const TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                    _settings!['${_selectedMethod}Account'] ??
                                        '',
                                    style: const TextStyle(
                                        fontFamily: 'Tajawal', fontSize: 15)),
                              ],
                            ],
                          ),
                        ),
                      if (_selectedMethod != 'wallet') ...[
                        const Text('رفع صورة الإيصال',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: primaryColor,
                                fontFamily: 'Tajawal')),
                        const SizedBox(height: 8),
                        if (_proofUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(_proofUrl!, height: 120),
                          ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _pickProof,
                            icon: const Icon(Icons.upload, color: Colors.white),
                            label: const Text('اختر صورة الإيصال',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Tajawal',
                                    fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              textStyle: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _transactionRefController,
                          decoration: InputDecoration(
                            labelText: 'الرقم المرجعي للعملية',
                            hintText: 'مثال: TXN-123456',
                            filled: true,
                            fillColor: cardColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ] else ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            amountDueAfterWallet > 0
                                ? 'لا يمكن إكمال الطلب بالمحفظة فقط لأن المبلغ المتبقي ${amountDueAfterWallet.toStringAsFixed(2)} ج.س.'
                                : 'لن تحتاج إلى رفع إيصال لأن الطلب سيُعتمد من المحفظة مباشرة.',
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      // زر إرسال الدفع
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submitting ? null : _submitPayment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: const TextStyle(
                                fontSize: 18,
                                fontFamily: 'Tajawal',
                                fontWeight: FontWeight.bold),
                            elevation: 2,
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Text('إرسال الدفع',
                                  style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
