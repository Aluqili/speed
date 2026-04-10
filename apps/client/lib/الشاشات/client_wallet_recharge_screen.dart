import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:get/get.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';
import 'package:intl/intl.dart';

class ClientWalletRechargeScreen extends StatefulWidget {
  final String clientId;

  const ClientWalletRechargeScreen({Key? key, required this.clientId}) : super(key: key);

  @override
  State<ClientWalletRechargeScreen> createState() => _ClientWalletRechargeScreenState();
}

class _ClientWalletRechargeScreenState extends State<ClientWalletRechargeScreen> {
  // المتغيرات الخاصة بالحالة
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _transactionRefController = TextEditingController();
  File? _pickedImage;
  bool _uploading = false;
  String _selectedMethod = 'bankk';
  Map<String, String> _accounts = {};
  Map<String, String> _accountHolders = {};
  List<String> _enabledMethods = const ['bankk', 'ocash', 'fawry'];
  bool _accountsLoading = true;
  final picker = ImagePicker();
  final _cloudinary = CloudinaryPublic('dvnzloec6', 'flutter_unsigned');
  final Color primaryColor = AppThemeArabic.clientPrimary;
  final Color backgroundColor = AppThemeArabic.clientBackground;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final doc = await FirebaseFirestore.instance.collection('paymentSettings').doc('default').get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _enabledMethods = List<String>.from(data['enabledMethods'] ?? const ['bankk', 'ocash', 'fawry']);
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
        if (!_enabledMethods.contains(_selectedMethod) && _enabledMethods.isNotEmpty) {
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
      Get.snackbar('خطأ', 'الرجاء إدخال المبلغ والرقم المرجعي واختيار صورة الإيصال.',
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    setState(() {
      _uploading = true;
    });

    try {
      // رفع الصورة إلى Cloudinary
      final res = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(_pickedImage!.path, resourceType: CloudinaryResourceType.Image),
      );
      final imageUrl = res.secureUrl;
      final clientDoc = await FirebaseFirestore.instance
          .collection('clients')
          .doc(widget.clientId)
          .get();
      final clientData = clientDoc.data() ?? <String, dynamic>{};

      await FirebaseFirestore.instance.collection('wallet_recharges').add({
        'clientId': widget.clientId,
        'clientName': (clientData['name'] ?? clientData['fullName'] ?? 'عميل').toString(),
        'clientPhone': (clientData['phone'] ?? clientData['phoneNumber'] ?? '').toString(),
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
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.green, colorText: Colors.white);

      Navigator.pop(context);
    } catch (e) {
      Get.snackbar('خطأ', 'حدث خطأ أثناء رفع الطلب: $e',
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      setState(() {
        _uploading = false;
      });
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
          title: const Text('شحن المحفظة', style: TextStyle(color: AppThemeArabic.clientPrimary, fontWeight: FontWeight.bold, fontSize: 20, fontFamily: 'Tajawal')),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('شحن المحفظة', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal', fontSize: 20)),
                    const SizedBox(height: 18),
                    const Text('1. اختر طريقة الدفع', style: TextStyle(fontWeight: FontWeight.bold)),
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
                                          'اسم صاحب الحساب: ${_accountHolders[_selectedMethod] ?? 'غير متوفر'}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'رقم الحساب: ${_accounts[_selectedMethod]}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    const SizedBox(height: 18),
                    const Text('2. أدخل مبلغ الشحن', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'المبلغ...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: AppThemeArabic.clientBackground,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text('3. أدخل الرقم المرجعي للتحويل', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _transactionRefController,
                      decoration: InputDecoration(
                        hintText: 'الرقم المرجعي...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: AppThemeArabic.clientBackground,
                        prefixIcon: const Icon(Icons.confirmation_number_outlined),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text('4. ارفع صورة الإيصال', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _pickedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(_pickedImage!, height: 180, fit: BoxFit.cover),
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
                      onPressed: _pickImage,
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
                        ? const Center(child: GFLoader(type: GFLoaderType.circle))
                        : SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _submitRechargeRequest,
                              child: const Text('إرسال طلب الشحن'),
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

  Widget _buildMethodButton(String label, String value, IconData icon) {
    final selected = _selectedMethod == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = value),
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
            Icon(icon, color: selected ? Colors.white : primaryColor),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: selected ? Colors.white : primaryColor, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
