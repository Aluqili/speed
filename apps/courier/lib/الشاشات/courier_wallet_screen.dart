import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'courier_ui.dart';

class CourierWalletScreen extends StatefulWidget {
  final String driverId;

  const CourierWalletScreen({super.key, required this.driverId});

  @override
  State<CourierWalletScreen> createState() => _CourierWalletScreenState();
}

class _CourierWalletScreenState extends State<CourierWalletScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accountNumberController = TextEditingController();
  final _accountNameController = TextEditingController();
  String _selectedMethod = 'bankk';
  bool _saving = false;

  @override
  void dispose() {
    _accountNumberController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  bool _isDeliveredStatus(dynamic rawStatus) {
    final status = (rawStatus ?? '').toString().trim();
    return status == 'delivered' || status == 'تم التوصيل';
  }

  double _toAmount(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString()) ?? 0;
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
        const SnackBar(content: Text('تم حفظ بيانات الحساب بنجاح')),
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
    final driverRef =
        FirebaseFirestore.instance.collection('drivers').doc(widget.driverId);

    return Scaffold(
      appBar: buildCourierAppBar('محفظتي'),
      body: CourierPageBackground(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: driverRef.snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snap.data!.data() ?? <String, dynamic>{};
            final payout =
                (data['payoutAccount'] as Map<String, dynamic>?) ?? <String, dynamic>{};

            final pendingBalance =
                ((data['walletPendingBalance'] ?? 0) as num).toDouble();
            final transferredTotal =
                ((data['walletTransferredTotal'] ?? 0) as num).toDouble();
            final lifetimeEarnings =
                ((data['walletLifetimeEarnings'] ?? 0) as num).toDouble();
            final deliveredOrdersCount =
                ((data['walletDeliveredOrdersCount'] ?? 0) as num).toInt();

            final method =
                (payout['method'] ?? data['payoutMethod'] ?? 'bankk').toString();
            final accountNumber =
                (payout['accountNumber'] ?? data['payoutAccountNumber'] ?? '')
                    .toString();
            final accountName =
                (payout['accountName'] ?? data['payoutAccountName'] ?? '')
                    .toString();

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
                    if (!_isDeliveredStatus(
                        order['orderStatus'] ?? order['status'])) {
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

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    CourierHeroCard(
                      title: '${effectivePendingBalance.toStringAsFixed(2)} ج.س',
                      subtitle: 'الرصيد المتبقي بانتظار التحويل من الإدارة.',
                      icon: Icons.account_balance_wallet_rounded,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: CourierMetricCard(
                            label: 'تم تحويله',
                            value: transferredTotal.toStringAsFixed(1),
                            icon: Icons.outbox_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CourierMetricCard(
                            label: 'طلبات مكتملة',
                            value: '$effectiveDeliveredOrdersCount',
                            icon: Icons.task_alt_rounded,
                            tone: const Color(0xFFE1A44A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    CourierSectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const CourierSectionTitle(
                            title: 'بيانات الاستلام',
                            subtitle: 'الحساب الذي ستُرسل إليه التحويلات المالية.',
                          ),
                          const SizedBox(height: 16),
                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
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
                                      child: Text('تحويل بنكي'),
                                    ),
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
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _accountNumberController,
                                  decoration: const InputDecoration(
                                    labelText: 'رقم الحساب أو المحفظة',
                                  ),
                                  validator: (value) {
                                    if ((value ?? '').trim().isEmpty) {
                                      return 'أدخل رقم الحساب';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _accountNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'اسم صاحب الحساب',
                                  ),
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _saving ? null : _savePayoutAccount,
                                    icon: _saving
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.save_outlined),
                                    label: Text(
                                      _saving
                                          ? 'جاري الحفظ...'
                                          : 'حفظ بيانات الحساب',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (accountNumber.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F1E7),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.verified_user_outlined),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '${_methodLabel(method)} - $accountNumber',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    CourierSectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const CourierSectionTitle(
                            title: 'سجل التحويلات',
                            subtitle: 'كل تحويل مالي تم تسجيله على حسابك.',
                          ),
                          const SizedBox(height: 16),
                          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: driverRef
                                .collection('walletTransactions')
                                .orderBy('createdAt', descending: true)
                                .snapshots(),
                            builder: (context, txSnap) {
                              if (!txSnap.hasData) {
                                return const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(),
                                );
                              }

                              final docs = txSnap.data!.docs;
                              if (docs.isEmpty) {
                                return const CourierEmptyState(
                                  title: 'لا توجد تحويلات بعد',
                                  message:
                                      'عند تسجيل أول تحويل من الإدارة سيظهر هنا تلقائيًا.',
                                  icon: Icons.payments_outlined,
                                );
                              }

                              return Column(
                                children: docs.map((doc) {
                                  final tx = doc.data();
                                  final amount =
                                      ((tx['amount'] ?? 0) as num).toDouble();
                                  final txMethod =
                                      (tx['accountMethod'] ?? '').toString();
                                  final txNumber =
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

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8F1E7),
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: Row(
                                        children: [
                                          const CircleAvatar(
                                            backgroundColor: Color(0xFFFFE5BE),
                                            child: Icon(Icons.payments_rounded),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'تم تحويل ${amount.toStringAsFixed(2)} ج.س',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${_methodLabel(txMethod)} - $txNumber',
                                                  style: const TextStyle(
                                                    color: Color(0xFF7A6857),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            dateText,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF7A6857),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
