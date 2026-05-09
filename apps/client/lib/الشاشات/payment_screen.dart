import 'package:flutter/material.dart';
import '../الثيم/client_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:getwidget/getwidget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:provider/provider.dart';
import 'package:speedstar_core/speedstar_core.dart' show formatUnifiedOrderCode;

import '../الخدمات/payment_app_launcher.dart';
import '../الخدمات/promocode_service.dart';
import '../الخدمات/cloudinary_service.dart';
import 'cart_provider.dart';
import 'client_order_details_screen.dart';

class PaymentScreen extends StatefulWidget {
  final String? orderId;
  final Map<String, dynamic>? draftOrderData;
  final bool clearCartOnSubmit;

  const PaymentScreen({
    super.key,
    this.orderId,
    this.draftOrderData,
    this.clearCartOnSubmit = false,
  })  : assert(orderId != null || draftOrderData != null);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  static const Color primaryColor = ClientColors.primary;
  static const Color backgroundColor = ClientColors.lightBackground;
  static const Color cardColor = Colors.white;
  static const String _paymentReviewStatus = 'قيد المراجعة';
  final _cloudinary = CloudinaryService.build();
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

  static const List<String> _defaultPaymentMethods = [
    'bankk',
    'ocash',
    'fawry',
  ];

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
              'enabledMethods': _defaultPaymentMethods,
              'bankkAccount': '',
              'ocashAccount': '',
              'fawryAccount': '',
              'bankkAccountHolder': '',
              'ocashAccountHolder': '',
              'fawryAccountHolder': '',
              'bankkQrUrl': '',
              'ocashQrUrl': '',
              'fawryQrUrl': '',
              'bankkInstructions': '',
              'ocashInstructions': '',
              'fawryInstructions': '',
              'bankkOpenUrlAndroid': '',
              'ocashOpenUrlAndroid': '',
              'fawryOpenUrlAndroid': '',
              'bankkOpenUrlIos': '',
              'ocashOpenUrlIos': '',
              'fawryOpenUrlIos': '',
              'bankkOpenUrl': '',
              'ocashOpenUrl': '',
              'fawryOpenUrl': '',
            };
        final methods = _resolveAvailableMethods(_settings!);
        _selectedMethod ??= methods.isNotEmpty ? methods.first : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _settings = {
          'enabledMethods': _defaultPaymentMethods,
          'bankkAccount': '',
          'ocashAccount': '',
          'fawryAccount': '',
          'bankkAccountHolder': '',
          'ocashAccountHolder': '',
          'fawryAccountHolder': '',
          'bankkQrUrl': '',
          'ocashQrUrl': '',
          'fawryQrUrl': '',
          'bankkInstructions': '',
          'ocashInstructions': '',
          'fawryInstructions': '',
          'bankkOpenUrlAndroid': '',
          'ocashOpenUrlAndroid': '',
          'fawryOpenUrlAndroid': '',
          'bankkOpenUrlIos': '',
          'ocashOpenUrlIos': '',
          'fawryOpenUrlIos': '',
          'bankkOpenUrl': '',
          'ocashOpenUrl': '',
          'fawryOpenUrl': '',
        };
        final methods = _resolveAvailableMethods(_settings!);
        _selectedMethod ??= methods.isNotEmpty ? methods.first : null;
      });
      debugPrint('paymentSettings fallback used: $e');
    }
  }

  List<String> _resolveAvailableMethods(Map<String, dynamic> settings) {
    final methods = List<String>.from(
      settings['enabledMethods'] ?? _defaultPaymentMethods,
    );
    return methods.isEmpty
        ? List<String>.from(_defaultPaymentMethods)
        : methods;
  }

  String _paymentAccountValue(String method) {
    final value = (_settings?['${method}Account'] ?? '').toString().trim();
    return value;
  }

  String _paymentAccountHolderValue(String method) {
    final value = (_settings?['${method}AccountHolder'] ??
            _settings?['${method}Holder'] ??
            '')
        .toString()
        .trim();
    return value;
  }

  String _paymentQrUrl(String method) {
    return (_settings?['${method}QrUrl'] ?? '').toString().trim();
  }

  String _paymentInstructions(String method) {
    return (_settings?['${method}Instructions'] ?? '').toString().trim();
  }

  String _paymentOpenUrl(String method) {
    return (_settings?['${method}OpenUrl'] ?? '').toString().trim();
  }

  String _paymentOpenUrlAndroid(String method) {
    return (_settings?['${method}OpenUrlAndroid'] ?? '').toString().trim();
  }

  String _paymentOpenUrlIos(String method) {
    return (_settings?['${method}OpenUrlIos'] ?? '').toString().trim();
  }

  Future<void> _launchPaymentApp(String method) async {
    await launchPaymentApp(
      context,
      PaymentAppLaunchConfig(
        method: method,
        androidUrl: _paymentOpenUrlAndroid(method),
        iosUrl: _paymentOpenUrlIos(method),
        genericUrl: _paymentOpenUrl(method),
      ),
    );
  }

  Future<void> _copyPaymentAccount(String method) async {
    final account = _paymentAccountValue(method);
    if (account.isEmpty) {
      if (!mounted) return;
      GFToast.showToast('رقم الحساب غير متوفر لهذه الطريقة.', context);
      return;
    }

    await Clipboard.setData(ClipboardData(text: account));
    if (!mounted) return;
    GFToast.showToast('تم نسخ رقم الحساب.', context);
  }

  void _showQrPreview(String method, String qrUrl) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'رمز ${_paymentMethodLabel(method)}',
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.network(
                    qrUrl,
                    height: 320,
                    width: 320,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('إغلاق'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSelectedMethodDetails({
    required String method,
    required double walletBalance,
    required double walletRequestedAmount,
    required double amountDueAfterWallet,
  }) {
    if (method == 'wallet') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
        ],
      );
    }

    final accountHolder = _paymentAccountHolderValue(method);
    final account = _paymentAccountValue(method);
    final qrUrl = _paymentQrUrl(method);
    final instructions = _paymentInstructions(method);
    final openUrl = _paymentOpenUrl(method);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _paymentMethodLabel(method),
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.payments_outlined, color: primaryColor),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'اسم صاحب الحساب',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                accountHolder.isEmpty ? 'غير متوفر' : accountHolder,
                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 15),
              ),
              const SizedBox(height: 12),
              const Text(
                'رقم الحساب',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        account.isEmpty ? 'غير متوفر' : account,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: account.isEmpty
                          ? null
                          : () => _copyPaymentAccount(method),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('نسخ'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (instructions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFED7AA)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, color: primaryColor, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'تعليمات الدفع',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  instructions,
                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 15),
                ),
              ],
            ),
          ),
        ],
        if (qrUrl.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 12,
                    offset: Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'رمز QR للدفع',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () => _showQrPreview(method, qrUrl),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.network(
                        qrUrl,
                        height: 240,
                        width: double.infinity,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'تعذر تحميل رمز QR لهذه الطريقة حالياً.',
                            style: TextStyle(fontFamily: 'Tajawal'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'اضغط على الرمز لتكبيره.',
                  style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
        if (openUrl.isNotEmpty || account.isNotEmpty || qrUrl.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (openUrl.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () => _launchPaymentApp(method),
                  icon: const Icon(Icons.open_in_new, color: Colors.white),
                  label: Text(
                    'فتح ${_paymentMethodLabel(method)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Tajawal',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              if (account.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => _copyPaymentAccount(method),
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('نسخ الرقم'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: const BorderSide(color: primaryColor),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              if (qrUrl.isNotEmpty)
                TextButton.icon(
                  onPressed: () => _showQrPreview(method, qrUrl),
                  icon: const Icon(Icons.zoom_in_rounded),
                  label: const Text('تكبير QR'),
                  style: TextButton.styleFrom(
                    foregroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 14),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Future<Map<String, dynamic>> _loadOrder() async {
    if (widget.orderId == null) {
      return Map<String, dynamic>.from(widget.draftOrderData!);
    }

    final doc = await FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId!)
        .get();
    if (!doc.exists || doc.data() == null) {
      throw Exception('الطلب غير موجود');
    }
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
      'externalPaidAmount': preview['amountDueAfterWallet']!,
      'walletSettledAt': null,
      'walletUsedAmount': null,
      'walletBalanceBeforeDebit': null,
      'walletBalanceAfterDebit': null,
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
    try {
      final resp = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          img.path,
          resourceType: CloudinaryResourceType.Image,
        ),
      );
      if (!mounted) return;
      setState(() => _proofUrl = resp.secureUrl);
    } catch (e) {
      if (!mounted) return;
      GFToast.showToast('فشل رفع الإيصال، حاول مرة أخرى.', context);
    }
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
      final externalPaidAmount =
          (walletFields['externalPaidAmount'] as num?)?.toDouble() ??
              amountDueAfterWallet;
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
        'externalPaidAmount': externalPaidAmount,
        'totalBeforeWallet': finalTotalAfterDiscount,
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
        'externalPaidAmount': externalPaidAmount,
        'totalBeforeWallet': finalTotalAfterDiscount,
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

  Widget _sectionLabel(String label) => Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          color: Color(0xFF1A1D26),
        ),
      );

  Widget _summaryRow(String label, String value,
      {Color valueColor = const Color(0xFF374151),
      bool bold = false,
      bool large = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              fontSize: large ? 17 : 14,
            ),
          ),
          const Spacer(),
          Text(
            label,
            style: TextStyle(
              color: bold ? const Color(0xFF1A1D26) : const Color(0xFF6B7280),
              fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
              fontSize: large ? 15 : 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard({
    required double subtotal,
    required double deliveryFee,
    required double largeOrderFee,
    required double totalWithDelivery,
    required num discount,
    required double walletRequestedAmount,
    required double walletBalance,
    required double amountDueAfterWallet,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          _summaryRow(
              'قيمة الأصناف', '${subtotal.toStringAsFixed(2)} ج.س'),
          _summaryRow(
              'رسوم التوصيل', '${deliveryFee.toStringAsFixed(2)} ج.س'),
          if (largeOrderFee > 0)
            _summaryRow('رسوم الخدمة',
                '${largeOrderFee.toStringAsFixed(2)} ج.س'),
          if (discount > 0)
            _summaryRow('خصم الرمز الترويجي',
                '-${discount.toString()} ج.س',
                valueColor: Colors.green),
          if (walletRequestedAmount > 0)
            _summaryRow(
                'خصم المحفظة',
                '-${walletRequestedAmount.toStringAsFixed(2)} ج.س',
                valueColor: Colors.green),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Divider(height: 1),
          ),
          _summaryRow(
            walletRequestedAmount > 0
                ? 'المبلغ المتبقي للدفع'
                : 'الإجمالي',
            '${(walletRequestedAmount > 0 ? amountDueAfterWallet : totalWithDelivery).toStringAsFixed(2)} ج.س',
            valueColor: primaryColor,
            bold: true,
            large: true,
          ),
        ],
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
            final methods = _resolveAvailableMethods(_settings!);
            if (walletBalance > 0 && !methods.contains('wallet')) {
              methods.insert(0, 'wallet');
            }
            if (_selectedMethod == null || !methods.contains(_selectedMethod)) {
              _selectedMethod = methods.isNotEmpty ? methods.first : null;
            }

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                backgroundColor: backgroundColor,
                appBar: AppBar(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  elevation: 1,
                  centerTitle: true,
                  title: const Text('طريقة الدفع',
                      style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ─── ملخص الطلب ───────────────────────────────────
                      _sectionLabel('ملخص الطلب'),
                      const SizedBox(height: 8),
                      _summaryCard(
                        subtotal: subtotal,
                        deliveryFee: deliveryFee,
                        largeOrderFee: largeOrderFee,
                        totalWithDelivery: totalWithDelivery.toDouble(),
                        discount: _discount,
                        walletRequestedAmount: walletRequestedAmount,
                        walletBalance: walletBalance,
                        amountDueAfterWallet: amountDueAfterWallet,
                      ),
                      const SizedBox(height: 6),
                      // تفاصيل الأصناف (أسدال)
                      Theme(
                        data: Theme.of(context)
                            .copyWith(dividerColor: Colors.transparent),
                        child: Container(
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 0),
                            title: Text(
                              'عرض تفاصيل الأصناف (${items.length})',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            iconColor: primaryColor,
                            collapsedIconColor: Colors.grey,
                            children: items.map((item) {
                              final name =
                                  (item['name'] ?? 'غير متوفر').toString();
                              final sizeLabel =
                                  (item['sizeLabel'] ?? '').toString().trim();
                              final qty = item['quantity']?.toString() ?? '1';
                              final price = item['price'] != null
                                  ? '${item['price']} ج.س'
                                  : '';
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 6),
                                child: Row(
                                  children: [
                                    Text(price,
                                        style: const TextStyle(
                                            color: primaryColor,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13)),
                                    const Spacer(),
                                    Flexible(
                                      child: Text(
                                        sizeLabel.isEmpty
                                            ? '$name × $qty'
                                            : '$name ($sizeLabel) × $qty',
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF374151)),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ─── رمز الخصم ────────────────────────────────────
                      _sectionLabel('رمز الخصم'),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                            )
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _promocodeController,
                                textAlign: TextAlign.right,
                                decoration: InputDecoration(
                                  hintText: 'أدخل رمز الخصم...',
                                  hintStyle: const TextStyle(
                                      color: Color(0xFF9CA3AF), fontSize: 14),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                  suffixIcon: _promoData != null
                                      ? const Icon(Icons.check_circle_rounded,
                                          color: Colors.green, size: 20)
                                      : null,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () async {
                                final messenger =
                                    ScaffoldMessenger.of(context);
                                setState(() {
                                  _promoError = null;
                                  _promoData = null;
                                  _discount = 0;
                                });
                                final code =
                                    _promocodeController.text.trim();
                                if (code.isEmpty) return;
                                final restaurantId =
                                    (data['restaurantId'] ?? '').toString();
                                final promo = await _promocodeService!
                                    .validatePromocode(
                                  code: code,
                                  subtotal: subtotal,
                                  deliveryFee: deliveryFee,
                                  largeOrderFee: largeOrderFee,
                                  restaurantId: restaurantId,
                                  items: items,
                                  isNewOrder: widget.orderId == null,
                                );
                                if (!mounted) return;
                                if (promo == null || promo['ok'] != true) {
                                  setState(() {
                                    _promoError = _promoReasonMessage(promo ==
                                            null
                                        ? 'invalid-code'
                                        : promo['reason']?.toString());
                                    _promoData = null;
                                    _discount = 0;
                                  });
                                  messenger.showSnackBar(SnackBar(
                                    content: Text(_promoError!),
                                    backgroundColor: Colors.red,
                                  ));
                                } else {
                                  final discount =
                                      (promo['discountAmount'] as num?) ?? 0;
                                  setState(() {
                                    _promoData = promo;
                                    _discount = discount;
                                    _promoError = null;
                                  });
                                  messenger.showSnackBar(SnackBar(
                                    content: Text(
                                        'تم تطبيق الخصم: -${discount.toString()} ج.س'),
                                    backgroundColor: Colors.green,
                                  ));
                                }
                              },
                              child: Container(
                                margin: const EdgeInsets.all(6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 10),
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'تطبيق',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_promoError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6, right: 4),
                          child: Text(_promoError!,
                              style: const TextStyle(
                                  color: Colors.red, fontSize: 12)),
                        ),
                      if (_promoData != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6, right: 4),
                          child: Text(
                              'تم تطبيق الخصم: -${_discount.toString()} ج.س',
                              style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ),
                      const SizedBox(height: 20),

                      // ─── طريقة الدفع ──────────────────────────────────
                      _sectionLabel('اختر طريقة الدفع'),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 96,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          reverse: true,
                          itemCount: methods.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 10),
                          itemBuilder: (context, idx) {
                            final m = methods[idx];
                            final selected = _selectedMethod == m;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedMethod = m),
                              child: AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 180),
                                width: 100,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? primaryColor
                                      : cardColor,
                                  borderRadius:
                                      BorderRadius.circular(16),
                                  border: Border.all(
                                    color: selected
                                        ? primaryColor
                                        : const Color(0xFFE5E7EB),
                                    width: selected ? 2 : 1,
                                  ),
                                  boxShadow: selected
                                      ? [
                                          BoxShadow(
                                            color: primaryColor
                                                .withValues(alpha: 0.25),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : [],
                                ),
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _paymentMethodIcon(m),
                                      size: 30,
                                      color: selected
                                          ? Colors.white
                                          : primaryColor,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _paymentMethodLabel(m),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: selected
                                            ? Colors.white
                                            : const Color(0xFF374151),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ─── تفاصيل الطريقة المختارة ──────────────────────
                      if (_selectedMethod != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: _buildSelectedMethodDetails(
                            method: _selectedMethod!,
                            walletBalance: walletBalance,
                            walletRequestedAmount: walletRequestedAmount,
                            amountDueAfterWallet: amountDueAfterWallet,
                          ),
                        ),
                      const SizedBox(height: 20),

                      // ─── رفع الإيصال ──────────────────────────────────
                      if (_selectedMethod != 'wallet') ...[
                        _sectionLabel('إيصال الدفع'),
                        const SizedBox(height: 8),
                        // صورة الإيصال أو placeholder
                        GestureDetector(
                          onTap: _pickProof,
                          child: Container(
                            height: 130,
                            decoration: BoxDecoration(
                              color: _proofUrl != null
                                  ? Colors.transparent
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _proofUrl != null
                                    ? primaryColor.withValues(alpha: 0.4)
                                    : const Color(0xFFD1D5DB),
                                width: 1.5,
                                // dashed look via strokeAlign not available; use solid
                              ),
                            ),
                            child: _proofUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(15),
                                    child: Image.network(
                                      _proofUrl!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                    ),
                                  )
                                : Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.cloud_upload_rounded,
                                          size: 36,
                                          color: Colors.grey[400]),
                                      const SizedBox(height: 8),
                                      Text(
                                        'اضغط لرفع صورة الإيصال',
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        if (_proofUrl != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: TextButton.icon(
                              onPressed: _pickProof,
                              icon: const Icon(Icons.edit_rounded, size: 14),
                              label: const Text('تغيير الإيصال',
                                  style: TextStyle(fontSize: 12)),
                              style: TextButton.styleFrom(
                                  foregroundColor: primaryColor),
                            ),
                          ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _transactionRefController,
                          textAlign: TextAlign.right,
                          decoration: InputDecoration(
                            labelText: 'الرقم المرجعي للعملية',
                            hintText: 'مثال: TXN-123456',
                            prefixIcon: const Icon(Icons.tag_rounded,
                                size: 18, color: primaryColor),
                            filled: true,
                            fillColor: cardColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                  color: Color(0xFFE5E7EB)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                  color: primaryColor, width: 1.5),
                            ),
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(14),
                            border:
                                Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded,
                                  color: Colors.green, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  amountDueAfterWallet > 0
                                      ? 'رصيد المحفظة غير كافٍ للإكمال، يرجى اختيار طريقة أخرى.'
                                      : 'سيُعتمد الطلب تلقائياً من المحفظة دون الحاجة لرفع إيصال.',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),

                      // ─── زر الإرسال ───────────────────────────────────
                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _submitting ? null : _submitPayment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey[300],
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                            textStyle: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2.5))
                              : const Text('تأكيد وإرسال الدفع'),
                        ),
                      ),
                      const SizedBox(height: 16),
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
