import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';

class StoreWalletScreen extends StatefulWidget {
  final String restaurantId;
  const StoreWalletScreen({Key? key, required this.restaurantId})
      : super(key: key);

  @override
  State<StoreWalletScreen> createState() => _StoreWalletScreenState();
}

class _StoreWalletScreenState extends State<StoreWalletScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accountNumberController = TextEditingController();
  final _accountNameController = TextEditingController();
  String _selectedMethod = 'bankk';
  bool _saving = false;

  String _normalizeMethod(dynamic rawMethod) {
    final value = rawMethod.toString().trim().toLowerCase();
    switch (value) {
      case 'bankk':
      case 'bankak':
      case 'bankak_wallet':
      case 'bankak wallet':
      case 'بنكك':
        return 'bankk';
      case 'ocash':
      case 'okash':
      case 'o_cash':
      case 'أوكاش':
        return 'ocash';
      case 'fawry':
      case 'fawri':
      case 'فوري':
        return 'fawry';
      case 'bank_transfer':
      case 'bank transfer':
      case 'bank-transfer':
      case 'تحويل بنكي':
        return 'bank_transfer';
      default:
        return 'bankk';
    }
  }

  @override
  void dispose() {
    _accountNumberController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  String _methodLabel(String method) {
    switch (_normalizeMethod(method)) {
      case 'bankk':
        return 'بنكك';
      case 'ocash':
        return 'أوكاش';
      case 'fawry':
        return 'فوري';
      case 'bank_transfer':
        return 'تحويل بنكي';
      default:
        return method;
    }
  }

  Widget _walletMetric(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(color: color, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Future<void> _savePayoutAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.restaurantId)
          .set({
        'payoutAccount': {
          'method': _selectedMethod,
          'accountNumber': _accountNumberController.text.trim(),
          'accountName': _accountNameController.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        'payoutMethod': _selectedMethod,
        'payoutAccountNumber': _accountNumberController.text.trim(),
        'payoutAccountName': _accountNameController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم حفظ بيانات الحساب بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حفظ بيانات الحساب: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final storeRef = FirebaseFirestore.instance
        .collection('restaurants')
        .doc(widget.restaurantId);

    return Scaffold(
      backgroundColor: AppThemeArabic.storeBackground,
      appBar: AppBar(
        title: const Text('محفظة المطعم'),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: storeRef.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snap.data!.data() ?? <String, dynamic>{};
          final payout = (data['payoutAccount'] as Map<String, dynamic>?) ??
              <String, dynamic>{};

          final pendingBalance =
              ((data['walletPendingBalance'] ?? 0) as num).toDouble();
          final transferredTotal =
              ((data['walletTransferredTotal'] ?? 0) as num).toDouble();
          final lifetimeEarnings =
              ((data['walletLifetimeEarnings'] ?? 0) as num).toDouble();
          final deliveredOrdersCount =
              ((data['walletDeliveredOrdersCount'] ?? 0) as num).toInt();

          final method = _normalizeMethod(
            payout['method'] ?? data['payoutMethod'] ?? 'bankk',
          );
          final accountNumber =
              (payout['accountNumber'] ?? data['payoutAccountNumber'] ?? '')
                  .toString();
          final accountName =
              (payout['accountName'] ?? data['payoutAccountName'] ?? '')
                  .toString();

          if (_accountNumberController.text.isEmpty &&
              accountNumber.isNotEmpty) {
            _accountNumberController.text = accountNumber;
          }
          if (_accountNameController.text.isEmpty && accountName.isNotEmpty) {
            _accountNameController.text = accountName;
          }
          if (_selectedMethod != method && method.isNotEmpty) {
            _selectedMethod = method;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ملخص المستحقات',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 17)),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppThemeArabic.storePrimary,
                                Color(0xFF16A085)
                              ],
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                            ),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('المبلغ المتبقي للتحويل',
                                  style: TextStyle(color: Colors.white70)),
                              const SizedBox(height: 8),
                              Text(
                                '${pendingBalance.toStringAsFixed(2)} ج.س',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 28,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _walletMetric(
                                'تم تحويله',
                                '${transferredTotal.toStringAsFixed(0)} ج.س',
                                Icons.payments_outlined,
                                Colors.green),
                            const SizedBox(width: 10),
                            _walletMetric(
                                'إجمالي الأرباح',
                                '${lifetimeEarnings.toStringAsFixed(0)} ج.س',
                                Icons.trending_up,
                                Colors.orange),
                            const SizedBox(width: 10),
                            _walletMetric(
                                'طلبات مكتملة',
                                '$deliveredOrdersCount',
                                Icons.checklist_rtl,
                                AppThemeArabic.storePrimary),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('بيانات الحساب لاستلام التحويلات',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            value: _selectedMethod,
                            items: const [
                              DropdownMenuItem(
                                  value: 'bankk', child: Text('بنكك')),
                              DropdownMenuItem(
                                  value: 'ocash', child: Text('أوكاش')),
                              DropdownMenuItem(
                                  value: 'fawry', child: Text('فوري')),
                              DropdownMenuItem(
                                  value: 'bank_transfer',
                                  child: Text('تحويل بنكي')),
                            ],
                            onChanged: _saving
                                ? null
                                : (value) {
                                    if (value == null) return;
                                    setState(() => _selectedMethod = value);
                                  },
                            decoration:
                                const InputDecoration(labelText: 'طريقة الدفع'),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _accountNumberController,
                            decoration: const InputDecoration(
                                labelText: 'رقم الحساب / رقم المحفظة'),
                            validator: (value) {
                              if ((value ?? '').trim().isEmpty) {
                                return 'أدخل رقم الحساب';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _accountNameController,
                            decoration: const InputDecoration(
                                labelText: 'اسم صاحب الحساب (اختياري)'),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _saving ? null : _savePayoutAccount,
                              child: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('حفظ بيانات الحساب'),
                            ),
                          ),
                          if (accountNumber.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Chip(
                                avatar: const Icon(
                                    Icons.account_balance_wallet_outlined,
                                    size: 18),
                                label: Text(
                                    'الحساب الحالي: ${_methodLabel(method)} - $accountNumber'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('سجل التحويلات من الإدارة',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: storeRef
                              .collection('walletTransactions')
                              .orderBy('createdAt', descending: true)
                              .snapshots(),
                          builder: (context, txSnap) {
                            if (!txSnap.hasData) {
                              return const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: CircularProgressIndicator(),
                              );
                            }

                            final docs = txSnap.data!.docs;
                            if (docs.isEmpty) {
                              return const Text('لا توجد تحويلات بعد.',
                                  style: TextStyle(color: Colors.grey));
                            }

                            return Column(
                              children: docs.map((doc) {
                                final tx = doc.data();
                                final amount =
                                    ((tx['amount'] ?? 0) as num).toDouble();
                                final method =
                                    _normalizeMethod(tx['accountMethod']);
                                final accountNumber =
                                    (tx['accountNumber'] ?? '').toString();
                                final ts = tx['createdAt'];
                                final dateText = ts is Timestamp
                                    ? ts
                                        .toDate()
                                        .toLocal()
                                        .toString()
                                        .split('.')
                                        .first
                                    : '-';
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    border:
                                        Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.payments,
                                          color: Colors.green),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                'تم تحويل ${amount.toStringAsFixed(2)} ج.س',
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            Text(
                                                '${_methodLabel(method)} - $accountNumber',
                                                style: const TextStyle(
                                                    color: Colors.grey)),
                                          ],
                                        ),
                                      ),
                                      Text(dateText,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey)),
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
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
