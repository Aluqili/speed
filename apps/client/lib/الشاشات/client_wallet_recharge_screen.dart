import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:getwidget/getwidget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:get/get.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';

import '../الخدمات/payment_app_launcher.dart';
import '../الخدمات/cloudinary_service.dart';

class ClientWalletRechargeScreen extends StatefulWidget {
  final String clientId;

  const ClientWalletRechargeScreen({Key? key, required this.clientId})
      : super(key: key);

  @override
  State<ClientWalletRechargeScreen> createState() =>
      _ClientWalletRechargeScreenState();
}

class _ClientWalletRechargeScreenState
    extends State<ClientWalletRechargeScreen> {
  // المتغيرات الخاصة بالحالة
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _transactionRefController =
      TextEditingController();
  File? _pickedImage;
  bool _uploading = false;
  String _selectedMethod = 'bankk';
  Map<String, String> _accounts = {};
  Map<String, String> _accountHolders = {};
  Map<String, String> _qrUrls = {};
  Map<String, String> _instructions = {};
  Map<String, String> _openUrls = {};
  Map<String, String> _openUrlsAndroid = {};
  Map<String, String> _openUrlsIos = {};
  List<String> _enabledMethods = const ['bankk', 'ocash', 'fawry'];
  bool _accountsLoading = true;
  final picker = ImagePicker();
  final _cloudinary = CloudinaryService.build();
  final Color primaryColor = AppThemeArabic.clientPrimary;
  final Color backgroundColor = AppThemeArabic.clientBackground;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final doc = await FirebaseFirestore.instance
        .collection('paymentSettings')
        .doc('default')
        .get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _enabledMethods = List<String>.from(
            data['enabledMethods'] ?? const ['bankk', 'ocash', 'fawry']);
        _accounts = {
          'bankk': data['bankkAccount'] ?? '',
          'ocash': data['ocashAccount'] ?? '',
          'fawry': data['fawryAccount'] ?? '',
        };
        _accountHolders = {
          'bankk': data['bankkAccountHolder'] ?? '',
          'ocash': data['ocashAccountHolder'] ?? '',
          'fawry': data['fawryAccountHolder'] ?? '',
        };
        _qrUrls = {
          'bankk': data['bankkQrUrl'] ?? '',
          'ocash': data['ocashQrUrl'] ?? '',
          'fawry': data['fawryQrUrl'] ?? '',
        };
        _instructions = {
          'bankk': data['bankkInstructions'] ?? '',
          'ocash': data['ocashInstructions'] ?? '',
          'fawry': data['fawryInstructions'] ?? '',
        };
        _openUrlsAndroid = {
          'bankk': data['bankkOpenUrlAndroid'] ?? '',
          'ocash': data['ocashOpenUrlAndroid'] ?? '',
          'fawry': data['fawryOpenUrlAndroid'] ?? '',
        };
        _openUrlsIos = {
          'bankk': data['bankkOpenUrlIos'] ?? '',
          'ocash': data['ocashOpenUrlIos'] ?? '',
          'fawry': data['fawryOpenUrlIos'] ?? '',
        };
        _openUrls = {
          'bankk': data['bankkOpenUrl'] ?? '',
          'ocash': data['ocashOpenUrl'] ?? '',
          'fawry': data['fawryOpenUrl'] ?? '',
        };
        if (!_enabledMethods.contains(_selectedMethod) &&
            _enabledMethods.isNotEmpty) {
          _selectedMethod = _enabledMethods.first;
        }
        _accountsLoading = false;
      });
    } else {
      setState(() => _accountsLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _pickedImage = File(pickedFile.path);
      });
      // تم حذف استخراج النص من الصورة
    }
  }

  Future<void> _submitRechargeRequest() async {
    final amountText = _amountController.text.trim();
    final transactionReference = _transactionRefController.text.trim();
    final amount = double.tryParse(amountText) ?? 0.0;
    if (amount <= 0 || _pickedImage == null || transactionReference.isEmpty) {
      Get.snackbar(
          'خطأ', 'الرجاء إدخال المبلغ والرقم المرجعي واختيار صورة الإيصال.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white);
      return;
    }

    setState(() {
      _uploading = true;
    });

    try {
      // رفع الصورة إلى Cloudinary
      final res = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(_pickedImage!.path,
            resourceType: CloudinaryResourceType.Image),
      );
      final imageUrl = res.secureUrl;
      final clientDoc = await FirebaseFirestore.instance
          .collection('clients')
          .doc(widget.clientId)
          .get();
      final clientData = clientDoc.data() ?? <String, dynamic>{};

      await FirebaseFirestore.instance.collection('wallet_recharges').add({
        'clientId': widget.clientId,
        'clientName':
            (clientData['name'] ?? clientData['fullName'] ?? 'عميل').toString(),
        'clientPhone':
            (clientData['phone'] ?? clientData['phoneNumber'] ?? '').toString(),
        'amount': amount,
        'imageUrl': imageUrl,
        'proofImageUrl': imageUrl,
        'paymentMethod': _selectedMethod,
        'transactionReference': transactionReference,
        'status': 'pending_review',
        'reviewStatus': 'pending',
        'type': 'wallet',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      Get.snackbar('نجاح', 'تم إرسال طلب الشحن بنجاح!',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white);

      Navigator.pop(context);
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ أثناء رفع الطلب: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white);
    } finally {
      setState(() {
        _uploading = false;
      });
    }
  }

  Future<void> _launchPaymentApp() async {
    await launchPaymentApp(
      context,
      PaymentAppLaunchConfig(
        method: _selectedMethod,
        androidUrl: (_openUrlsAndroid[_selectedMethod] ?? '').trim(),
        iosUrl: (_openUrlsIos[_selectedMethod] ?? '').trim(),
        genericUrl: (_openUrls[_selectedMethod] ?? '').trim(),
      ),
    );
  }

  Future<void> _copySelectedAccount() async {
    final account = (_accounts[_selectedMethod] ?? '').trim();
    if (account.isEmpty) {
      Get.snackbar(
        'تنبيه',
        'رقم الحساب غير متوفر لهذه الطريقة.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    await Clipboard.setData(ClipboardData(text: account));
    Get.snackbar(
      'تم',
      'تم نسخ رقم الحساب.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void _showQrPreview(String qrUrl) {
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
                  'رمز ${_methodLabel(_selectedMethod)}',
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
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

  String _methodLabel(String method) {
    switch (method) {
      case 'bankk':
        return 'بنكك';
      case 'ocash':
        return 'أوكاش';
      case 'fawry':
        return 'فوري';
      default:
        return method;
    }
  }

  @override
  Widget build(BuildContext context) {
    final methodLabels = {
      'bankk': 'بنكك',
      'ocash': 'أوكاش',
      'fawry': 'فوري',
    };

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: const Text('شحن المحفظة',
              style: TextStyle(
                  color: AppThemeArabic.clientPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  fontFamily: 'Tajawal')),
          backgroundColor: Colors.white,
          centerTitle: true,
          iconTheme: const IconThemeData(color: AppThemeArabic.clientPrimary),
          elevation: 1,
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('شحن المحفظة',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Tajawal',
                            fontSize: 20)),
                    const SizedBox(height: 18),
                    const Text('1. اختر طريقة الدفع',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (_accountsLoading)
                      const Center(child: CircularProgressIndicator())
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _enabledMethods
                                .map(
                                  (method) => SizedBox(
                                    width: 110,
                                    child: _buildMethodButton(
                                      methodLabels[method] ?? method,
                                      method,
                                      method == 'bankk'
                                          ? Icons.account_balance
                                          : method == 'ocash'
                                              ? Icons.account_balance_wallet
                                              : Icons.payment,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 10),
                          if (_accounts[_selectedMethod]?.isNotEmpty == true)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(18),
                                border:
                                    Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: primaryColor.withValues(
                                              alpha: 0.10),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          _methodLabel(_selectedMethod),
                                          style: TextStyle(
                                            fontFamily: 'Tajawal',
                                            fontWeight: FontWeight.bold,
                                            color: primaryColor,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Icon(
                                          Icons.account_balance_wallet_outlined,
                                          color: primaryColor),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    'اسم صاحب الحساب: ${_accountHolders[_selectedMethod] ?? 'غير متوفر'}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Tajawal'),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                          color: const Color(0xFFE5E7EB)),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _accounts[_selectedMethod] ?? '',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'Tajawal',
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        TextButton.icon(
                                          onPressed: _copySelectedAccount,
                                          icon: const Icon(Icons.copy_rounded,
                                              size: 18),
                                          label: const Text('نسخ'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if ((_instructions[_selectedMethod] ?? '')
                                      .trim()
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF7ED),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                            color: const Color(0xFFFED7AA)),
                                      ),
                                      child: Text(
                                        'التعليمات: ${_instructions[_selectedMethod]}',
                                        style: const TextStyle(
                                            fontFamily: 'Tajawal'),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          if ((_qrUrls[_selectedMethod] ?? '')
                              .trim()
                              .isNotEmpty)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border:
                                    Border.all(color: const Color(0xFFE5E7EB)),
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
                                      color: AppThemeArabic.clientPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  InkWell(
                                    onTap: () => _showQrPreview(
                                        _qrUrls[_selectedMethod]!),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          _qrUrls[_selectedMethod]!,
                                          height: 220,
                                          width: double.infinity,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) =>
                                              Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[100],
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Text(
                                                'تعذر تحميل رمز QR لهذه الطريقة حالياً'),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'اضغط على الرمز لتكبيره.',
                                    style: TextStyle(
                                        fontFamily: 'Tajawal',
                                        color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          if ((_openUrls[_selectedMethod] ?? '').trim().isNotEmpty ||
                              (_accounts[_selectedMethod] ?? '')
                                  .trim()
                                  .isNotEmpty ||
                              (_qrUrls[_selectedMethod] ?? '')
                                  .trim()
                                  .isNotEmpty)
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                if ((_openUrls[_selectedMethod] ?? '')
                                    .trim()
                                    .isNotEmpty)
                                  ElevatedButton.icon(
                                    onPressed: _launchPaymentApp,
                                    icon: const Icon(Icons.open_in_new),
                                    label: Text(
                                        'فتح ${_methodLabel(_selectedMethod)}'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 14),
                                    ),
                                  ),
                                if ((_accounts[_selectedMethod] ?? '')
                                    .trim()
                                    .isNotEmpty)
                                  OutlinedButton.icon(
                                    onPressed: _copySelectedAccount,
                                    icon: const Icon(Icons.copy_rounded),
                                    label: const Text('نسخ الرقم'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: primaryColor,
                                      side: BorderSide(color: primaryColor),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 14),
                                    ),
                                  ),
                                if ((_qrUrls[_selectedMethod] ?? '')
                                    .trim()
                                    .isNotEmpty)
                                  TextButton.icon(
                                    onPressed: () => _showQrPreview(
                                        _qrUrls[_selectedMethod]!),
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
                      ),
                    const SizedBox(height: 18),
                    const Text('2. أدخل مبلغ الشحن',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'المبلغ...',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: AppThemeArabic.clientBackground,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text('3. أدخل الرقم المرجعي للتحويل',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _transactionRefController,
                      decoration: InputDecoration(
                        hintText: 'الرقم المرجعي...',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: AppThemeArabic.clientBackground,
                        prefixIcon:
                            const Icon(Icons.confirmation_number_outlined),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text('4. ارفع صورة الإيصال',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _pickedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(_pickedImage!,
                                height: 180, fit: BoxFit.cover),
                          )
                        : Container(
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey),
                            ),
                            child: const Center(
                                child: Text('لم يتم اختيار صورة بعد')),
                          ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.image),
                      label: const Text('اختيار صورة الإيصال'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'سيتم إرسال طلب الشحن إلى المراجعة، ولن يضاف الرصيد إلى محفظتك إلا بعد اعتماد الطلب.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _uploading
                        ? const Center(
                            child: GFLoader(type: GFLoaderType.circle))
                        : SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _submitRechargeRequest,
                              child: const Text('إرسال طلب الشحن'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                textStyle: const TextStyle(
                                    fontWeight: FontWeight.bold),
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

  Widget _buildMethodButton(String label, String method, IconData icon) {
    final selected = _selectedMethod == method;
    return InkWell(
      onTap: () => setState(() => _selectedMethod = method),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? primaryColor.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? primaryColor : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: primaryColor),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                  fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
