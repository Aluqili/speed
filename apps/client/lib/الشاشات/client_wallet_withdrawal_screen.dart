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
    extends State<ClientWalletWithdrawalScreen>
    with SingleTickerProviderStateMixin {
  static const _primary = AppThemeArabic.clientPrimary;
  static const _bg = Color(0xFFF5F6FA);

  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _accountHolderCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();

  String? _selectedMethod;
  bool _submitting = false;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  // ─── طرق الاستلام ──────────────────────────────────────────────────────────
  static const _methods = [
    _PayMethod(
      key: 'bank',
      label: 'بنك',
      subLabel: 'تحويل بنكي',
      icon: Icons.account_balance_rounded,
      color: Color(0xFF2563EB),
    ),
    _PayMethod(
      key: 'fawry',
      label: 'فوري',
      subLabel: 'رقم الهاتف',
      icon: Icons.flash_on_rounded,
      color: Color(0xFF059669),
    ),
    _PayMethod(
      key: 'okash',
      label: 'أوكاش',
      subLabel: 'رقم المحفظة',
      icon: Icons.wallet_rounded,
      color: Color(0xFF7C3AED),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _accountNumberCtrl.dispose();
    _accountHolderCtrl.dispose();
    _bankNameCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _selectMethod(String key) {
    setState(() {
      _selectedMethod = key;
      _accountNumberCtrl.clear();
      _accountHolderCtrl.clear();
      _bankNameCtrl.clear();
    });
    _animCtrl.forward(from: 0);
  }

  _PayMethod? get _method =>
      _selectedMethod == null
          ? null
          : _methods.firstWhere((m) => m.key == _selectedMethod);

  Future<void> _submit() async {
    if (_selectedMethod == null) {
      _showError('اختر طريقة الاستلام أولاً');
      return;
    }
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
      final clientData = clientDoc.data() ?? {};
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
        'paymentMethod': _method!.label,
        'paymentMethodKey': _selectedMethod,
        'accountNumber': _accountNumberCtrl.text.trim(),
        'accountHolderName': _accountHolderCtrl.text.trim(),
        if (_selectedMethod == 'bank') 'bankName': _bankNameCtrl.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _showSuccess();
      Navigator.pop(context);
    } catch (_) {
      if (mounted) _showError('حدث خطأ أثناء الإرسال، حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

  void _showSuccess() => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('تم إرسال طلب السحب بنجاح'),
          ]),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bg,
        body: CustomScrollView(
          slivers: [
            // ─── AppBar مع الهيدر المزخرف ─────────────────────────────────
            SliverAppBar(
              expandedHeight: 180,
              pinned: true,
              backgroundColor: _primary,
              iconTheme: const IconThemeData(color: Colors.white),
              title: const Text(
                'سحب الرصيد',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
              ),
              centerTitle: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  children: [
                    // خلفية متدرجة
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_primary, _primary.withValues(alpha: 0.7)],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                      ),
                    ),
                    // دوائر زخرفية
                    Positioned(
                      top: -30,
                      left: -30,
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.07),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -20,
                      right: -20,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 30,
                      left: 80,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                    // محتوى الرصيد
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'الرصيد المتاح للسحب',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${widget.walletBalance.toStringAsFixed(2)} ج.س',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ─── المحتوى ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Form(
                key: _formKey,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ─── المبلغ ─────────────────────────────────────
                      _SectionHeader(
                          icon: Icons.payments_rounded,
                          label: 'المبلغ المراد سحبه'),
                      const SizedBox(height: 10),
                      _Card(
                        child: TextFormField(
                          controller: _amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d+\.?\d{0,2}'))
                          ],
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: _primary),
                          decoration: InputDecoration(
                            hintText: '0.00',
                            hintStyle: TextStyle(
                                color: Colors.grey[300],
                                fontSize: 22,
                                fontWeight: FontWeight.w300),
                            suffixText: 'ج.س',
                            suffixStyle: const TextStyle(
                                color: _primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 15),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                            helperText:
                                'الحد الأقصى: ${widget.walletBalance.toStringAsFixed(2)} ج.س',
                            helperStyle: TextStyle(
                                fontSize: 12, color: Colors.grey[500]),
                          ),
                          validator: (v) {
                            final val = double.tryParse(v?.trim() ?? '');
                            if (val == null || val <= 0) return 'أدخل مبلغًا صحيحًا';
                            if (val > widget.walletBalance) {
                              return 'المبلغ يتجاوز رصيدك';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ─── طريقة الاستلام ─────────────────────────────
                      _SectionHeader(
                          icon: Icons.account_balance_wallet_rounded,
                          label: 'طريقة الاستلام'),
                      const SizedBox(height: 12),
                      Row(
                        children: _methods.map((method) {
                          final selected = _selectedMethod == method.key;
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                  left: method == _methods.last ? 0 : 8),
                              child: _MethodCard(
                                method: method,
                                selected: selected,
                                onTap: () => _selectMethod(method.key),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      // ─── حقول ديناميكية ──────────────────────────────
                      if (_selectedMethod != null) ...[
                        FadeTransition(
                          opacity: _fadeAnim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.08),
                              end: Offset.zero,
                            ).animate(_fadeAnim),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _SectionHeader(
                                  icon: _method!.icon,
                                  label: 'بيانات ${_method!.label}',
                                  color: _method!.color,
                                ),
                                const SizedBox(height: 10),
                                _Card(
                                  child: Column(
                                    children: [
                                      // حقل اسم البنك — للبنك فقط
                                      if (_selectedMethod == 'bank') ...[
                                        _InputField(
                                          controller: _bankNameCtrl,
                                          label: 'اسم البنك',
                                          hint: 'مثال: بنك الخرطوم',
                                          icon: Icons.account_balance_rounded,
                                          accentColor: _method!.color,
                                          validator: (v) =>
                                              (v?.trim().isEmpty ?? true)
                                                  ? 'أدخل اسم البنك'
                                                  : null,
                                        ),
                                        const SizedBox(height: 12),
                                      ],

                                      // رقم الحساب / الجوال
                                      _InputField(
                                        controller: _accountNumberCtrl,
                                        label: _selectedMethod == 'bank'
                                            ? 'رقم الحساب / IBAN'
                                            : 'رقم الهاتف',
                                        hint: _selectedMethod == 'bank'
                                            ? 'أدخل رقم الحساب البنكي'
                                            : '09xxxxxxxx',
                                        icon: _selectedMethod == 'bank'
                                            ? Icons.credit_card_rounded
                                            : Icons.phone_rounded,
                                        keyboardType: TextInputType.phone,
                                        accentColor: _method!.color,
                                        validator: (v) =>
                                            (v?.trim().isEmpty ?? true)
                                                ? 'هذا الحقل مطلوب'
                                                : null,
                                      ),
                                      const SizedBox(height: 12),

                                      // اسم صاحب الحساب
                                      _InputField(
                                        controller: _accountHolderCtrl,
                                        label: 'اسم صاحب الحساب',
                                        hint: 'الاسم كما هو مسجّل',
                                        icon: Icons.person_rounded,
                                        accentColor: _method!.color,
                                        validator: (v) =>
                                            (v?.trim().isEmpty ?? true)
                                                ? 'أدخل اسم صاحب الحساب'
                                                : null,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                      ],

                      // ─── ملاحظة ──────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: Colors.orange.shade200, width: 1),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.schedule_rounded,
                                  color: Colors.orange.shade700, size: 16),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'يتم مراجعة طلبات السحب خلال 1–3 أيام عمل، وسيتم إشعارك فور اعتماد الطلب.',
                                style: TextStyle(
                                    color: Colors.orange.shade800,
                                    fontSize: 12,
                                    height: 1.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ─── زر الإرسال ─────────────────────────────────
                      GestureDetector(
                        onTap: _submitting ? null : _submit,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 54,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _submitting
                                  ? [Colors.grey[300]!, Colors.grey[300]!]
                                  : [_primary, _primary.withValues(alpha: 0.8)],
                              begin: Alignment.centerRight,
                              end: Alignment.centerLeft,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: _submitting
                                ? []
                                : [
                                    BoxShadow(
                                      color: _primary.withValues(alpha: 0.35),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                          ),
                          child: Center(
                            child: _submitting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2.5),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.send_rounded,
                                          color: Colors.white, size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        'إرسال طلب السحب',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── بيانات طريقة الدفع ──────────────────────────────────────────────────────

class _PayMethod {
  final String key;
  final String label;
  final String subLabel;
  final IconData icon;
  final Color color;

  const _PayMethod({
    required this.key,
    required this.label,
    required this.subLabel,
    required this.icon,
    required this.color,
  });
}

// ─── بطاقة طريقة الدفع ───────────────────────────────────────────────────────

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final _PayMethod method;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? method.color : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? method.color : const Color(0xFFE5E7EB),
            width: selected ? 0 : 1.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: method.color.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ]
              : [
                  const BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.2)
                    : method.color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                method.icon,
                color: selected ? Colors.white : method.color,
                size: 22,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              method.label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF1A1D26),
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              method.subLabel,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected
                    ? Colors.white.withValues(alpha: 0.75)
                    : const Color(0xFF9CA3AF),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (selected) ...[
              const SizedBox(height: 6),
              Container(
                width: 20,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── حقل إدخال مخصص ──────────────────────────────────────────────────────────

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.accentColor,
    this.hint,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
  final Color accentColor;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
        prefixIcon: Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: accentColor, size: 16),
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accentColor, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      validator: validator,
    );
  }
}

// ─── عنوان قسم ───────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.label,
    this.color = const Color(0xFF1A1D26),
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Spacer(),
        Text(
          label,
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color == const Color(0xFF1A1D26)
                  ? const Color(0xFF1A1D26)
                  : color),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color == const Color(0xFF1A1D26)
                ? AppThemeArabic.clientPrimary.withValues(alpha: 0.1)
                : color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 14,
            color: color == const Color(0xFF1A1D26)
                ? AppThemeArabic.clientPrimary
                : color,
          ),
        ),
      ],
    );
  }
}

// ─── بطاقة بيضاء ─────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: child,
    );
  }
}
