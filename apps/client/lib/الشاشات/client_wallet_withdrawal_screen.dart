import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';

class ClientWalletWithdrawalScreen extends StatefulWidget {
  final String clientId;
  final double walletBalance;

  const ClientWalletWithdrawalScreen({
    Key? key,
    required this.clientId,
    required this.walletBalance,
  }) : super(key: key);

  @override
  State<ClientWalletWithdrawalScreen> createState() =>
      _ClientWalletWithdrawalScreenState();
}

class _ClientWalletWithdrawalScreenState
    extends State<ClientWalletWithdrawalScreen> {
  static const _primary = AppThemeArabic.clientPrimary;

  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _accountHolderCtrl = TextEditingController();

  String? _paymentMethod;
  bool _submitting = false;

  static const _paymentMethods = [
    'تحويل بنكي',
    'STC Pay',
    'Mada',
    'Benefit',
    'PayPal',
    'أخرى',
  ];

  @override
  void dispose() {
    _amountCtrl.dispose();
    _accountNumberCtrl.dispose();
    _accountHolderCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) {
      _showError('أدخل مبلغًا صحيحًا');
      return;
    }
    if (amount > widget.walletBalance) {
      _showError('المبلغ المطلوب أكبر من رصيدك الحالي');
      return;
    }

    setState(() => _submitting = true);

    try {
      final clientDoc = await FirebaseFirestore.instance
          .collection('clients')
          .doc(widget.clientId)
          .get();
      final clientData = (clientDoc.data() ?? {}) as Map<String, dynamic>;

      final clientName =
          (clientData['name'] ?? clientData['fullName'] ?? clientData['displayName'] ?? '')
              .toString()
              .trim();
      final clientPhone =
          (clientData['phone'] ?? clientData['phoneNumber'] ?? '').toString().trim();

      await FirebaseFirestore.instance.collection('wallet_withdrawals').add({
        'clientId': widget.clientId,
        'clientName': clientName,
        'clientPhone': clientPhone,
        'amount': amount,
        'paymentMethod': _paymentMethod,
        'accountNumber': _accountNumberCtrl.text.trim(),
        'accountHolderName': _accountHolderCtrl.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال طلب السحب بنجاح، سيتم مراجعته قريبًا.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) _showError('حدث خطأ أثناء إرسال الطلب، حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          title: const Text('طلب سحب رصيد',
              style: TextStyle(color: _primary, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          centerTitle: true,
          iconTheme: const IconThemeData(color: _primary),
          elevation: 0.5,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // ─── بطاقة الرصيد المتاح ──────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_primary, _primary.withValues(alpha: 0.75)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Text('الرصيد المتاح للسحب',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.walletBalance.toStringAsFixed(2)} ج.س',
                        style: const TextStyle(
                          fontSize: 30,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ─── حقول النموذج ──────────────────────────────────
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('بيانات السحب'),
                      const SizedBox(height: 14),

                      // المبلغ
                      TextFormField(
                        controller: _amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d{0,2}'))
                        ],
                        decoration: _inputDecoration(
                          label: 'المبلغ المراد سحبه',
                          hint: 'أقصى مبلغ: ${widget.walletBalance.toStringAsFixed(2)} ج.س',
                          icon: Icons.attach_money_rounded,
                        ),
                        validator: (v) {
                          final val = double.tryParse(v?.trim() ?? '');
                          if (val == null || val <= 0) return 'أدخل مبلغًا صحيحًا';
                          if (val > widget.walletBalance) {
                            return 'المبلغ يتجاوز رصيدك (${widget.walletBalance.toStringAsFixed(2)} ج.س)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // طريقة الدفع
                      DropdownButtonFormField<String>(
                        value: _paymentMethod,
                        decoration: _inputDecoration(
                          label: 'طريقة الاستلام',
                          icon: Icons.payment_rounded,
                        ),
                        items: _paymentMethods
                            .map((m) => DropdownMenuItem(
                                  value: m,
                                  child: Text(m),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _paymentMethod = v),
                        validator: (v) =>
                            v == null ? 'اختر طريقة الاستلام' : null,
                        isExpanded: true,
                      ),
                      const SizedBox(height: 14),

                      // رقم الحساب
                      TextFormField(
                        controller: _accountNumberCtrl,
                        keyboardType: TextInputType.text,
                        decoration: _inputDecoration(
                          label: 'رقم الحساب / رقم المحفظة',
                          hint: 'أدخل رقم الحساب أو رقم الجوال',
                          icon: Icons.credit_card_rounded,
                        ),
                        validator: (v) => (v?.trim().isEmpty ?? true)
                            ? 'أدخل رقم الحساب'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      // اسم صاحب الحساب
                      TextFormField(
                        controller: _accountHolderCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: _inputDecoration(
                          label: 'اسم صاحب الحساب',
                          hint: 'الاسم كما يظهر في الحساب',
                          icon: Icons.person_outline_rounded,
                        ),
                        validator: (v) => (v?.trim().isEmpty ?? true)
                            ? 'أدخل اسم صاحب الحساب'
                            : null,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ─── ملاحظة ────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'سيتم مراجعة طلبك من قِبل الإدارة وتحويل المبلغ خلال 1-3 أيام عمل بعد الموافقة.',
                          style: TextStyle(
                              color: Colors.orange.shade800,
                              fontSize: 13,
                              height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ─── زر الإرسال ───────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text('إرسال طلب السحب'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))
        ],
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title,
        style: const TextStyle(
            fontWeight: FontWeight.bold, fontSize: 15, color: _primary));
  }

  InputDecoration _inputDecoration(
      {required String label, String? hint, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: _primary, size: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primary, width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}
