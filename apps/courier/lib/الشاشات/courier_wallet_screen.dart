import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';

class CourierWalletScreen extends StatefulWidget {
  final String driverId;
  const CourierWalletScreen({Key? key, required this.driverId}) : super(key: key);

  @override
  State<CourierWalletScreen> createState() => _CourierWalletScreenState();
}

class _CourierWalletScreenState extends State<CourierWalletScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accountNumberController = TextEditingController();
  final _accountNameController = TextEditingController();
  String _selectedMethod = 'bankk';
  bool _saving = false;

  bool _isDeliveredStatus(dynamic rawStatus) {
    final status = (rawStatus ?? '').toString().trim();
    return status == 'delivered' || status == 'تم التوصيل';
  }

  double _toAmount(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString()) ?? 0;
  }

  @override
  void dispose() {
    _accountNumberController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  String _methodLabel(String method) {
    switch (method) {
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

  Future<void> _savePayoutAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(widget.driverId)
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
    final driverRef = FirebaseFirestore.instance.collection('drivers').doc(widget.driverId);

    return Scaffold(
      backgroundColor: AppThemeArabic.clientBackground,
      appBar: AppBar(
        title: const Text('محفظة المندوب', style: TextStyle(color: AppThemeArabic.clientPrimary, fontWeight: FontWeight.bold, fontSize: 20, fontFamily: 'Tajawal')),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 1,
        iconTheme: const IconThemeData(color: AppThemeArabic.clientPrimary),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: driverRef.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snap.data!.data() ?? <String, dynamic>{};
          final payout = (data['payoutAccount'] as Map<String, dynamic>?) ?? <String, dynamic>{};

          final pendingBalance = ((data['walletPendingBalance'] ?? 0) as num).toDouble();
          final transferredTotal = ((data['walletTransferredTotal'] ?? 0) as num).toDouble();
          final lifetimeEarnings = ((data['walletLifetimeEarnings'] ?? 0) as num).toDouble();
          final deliveredOrdersCount = ((data['walletDeliveredOrdersCount'] ?? 0) as num).toInt();

          final method = (payout['method'] ?? data['payoutMethod'] ?? 'bankk').toString();
          final accountNumber = (payout['accountNumber'] ?? data['payoutAccountNumber'] ?? '').toString();
          final accountName = (payout['accountName'] ?? data['payoutAccountName'] ?? '').toString();

          if (_accountNumberController.text.isEmpty && accountNumber.isNotEmpty) {
            _accountNumberController.text = accountNumber;
          }
          if (_accountNameController.text.isEmpty && accountName.isNotEmpty) {
            _accountNameController.text = accountName;
          }
          if (_selectedMethod != method && method.isNotEmpty) {
            _selectedMethod = method;
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .where('assignedDriverId', isEqualTo: widget.driverId)
                .snapshots(),
            builder: (context, ordersSnap) {
              var effectivePendingBalance = pendingBalance;
              var effectiveLifetimeEarnings = lifetimeEarnings;
              var effectiveDeliveredOrdersCount = deliveredOrdersCount;

              if (ordersSnap.hasData) {
                var derivedLifetimeEarnings = 0.0;
                var derivedDeliveredOrdersCount = 0;

                for (final orderDoc in ordersSnap.data!.docs) {
                  final order = orderDoc.data();
                  if (!_isDeliveredStatus(order['orderStatus'] ?? order['status'])) {
                    continue;
                  }

                  derivedDeliveredOrdersCount += 1;
                  derivedLifetimeEarnings += _toAmount(
                    order['deliveryFeeForDriver'] ?? order['deliveryFee'],
                  );
                }

                effectiveLifetimeEarnings = derivedLifetimeEarnings;
                effectiveDeliveredOrdersCount = derivedDeliveredOrdersCount;
                effectivePendingBalance = math.max(
                  0,
                  effectiveLifetimeEarnings - transferredTotal,
                ).toDouble();
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('ملخص المستحقات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                            const SizedBox(height: 10),
                            Text('المبلغ المتبقي للتحويل: ${effectivePendingBalance.toStringAsFixed(2)} ج.س',
                                style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                            Text('إجمالي ما تم تحويله: ${transferredTotal.toStringAsFixed(2)} ج.س'),
                            Text('إجمالي مستحقاتك التاريخية: ${effectiveLifetimeEarnings.toStringAsFixed(2)} ج.س'),
                            Text('عدد الطلبات المكتملة: $effectiveDeliveredOrdersCount طلب'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('بيانات الحساب لاستلام التحويلات',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            value: _selectedMethod,
                            items: const [
                              DropdownMenuItem(value: 'bankk', child: Text('بنكك')),
                              DropdownMenuItem(value: 'ocash', child: Text('أوكاش')),
                              DropdownMenuItem(value: 'fawry', child: Text('فوري')),
                              DropdownMenuItem(value: 'bank_transfer', child: Text('تحويل بنكي')),
                            ],
                            onChanged: _saving
                                ? null
                                : (value) {
                                    if (value == null) return;
                                    setState(() => _selectedMethod = value);
                                  },
                            decoration: const InputDecoration(labelText: 'طريقة الدفع'),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _accountNumberController,
                            decoration: const InputDecoration(labelText: 'رقم الحساب / رقم المحفظة'),
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
                            decoration: const InputDecoration(labelText: 'اسم صاحب الحساب (اختياري)'),
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
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('حفظ بيانات الحساب'),
                            ),
                          ),
                          if (accountNumber.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'الحساب الحالي: ${_methodLabel(method)} - $accountNumber',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('سجل التحويلات من الإدارة',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: driverRef
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
                              return const Text('لا توجد تحويلات بعد.', style: TextStyle(color: Colors.grey));
                            }

                            return Column(
                              children: docs.map((doc) {
                                final tx = doc.data();
                                final amount = ((tx['amount'] ?? 0) as num).toDouble();
                                final method = (tx['accountMethod'] ?? '').toString();
                                final accountNumber = (tx['accountNumber'] ?? '').toString();
                                final ts = tx['createdAt'];
                                final dateText = ts is Timestamp
                                    ? ts.toDate().toLocal().toString().split('.').first
                                    : '-';
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.payments, color: Colors.green),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('تم تحويل ${amount.toStringAsFixed(2)} ج.س',
                                                style: const TextStyle(fontWeight: FontWeight.bold)),
                                            Text('${_methodLabel(method)} - $accountNumber',
                                                style: const TextStyle(color: Colors.grey)),
                                          ],
                                        ),
                                      ),
                                      Text(dateText, style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
          );
        },
      ),
    );
  }
}
