import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';

import 'client_wallet_history_screen.dart';
import 'client_wallet_recharge_screen.dart';

class ClientWalletScreen extends StatefulWidget {
  final String clientId;
  const ClientWalletScreen({Key? key, required this.clientId}) : super(key: key);

  @override
  State<ClientWalletScreen> createState() => _ClientWalletScreenState();
}

class _ClientWalletScreenState extends State<ClientWalletScreen> {
  double _resolveWalletBalance(Map<String, dynamic>? data) {
    if (data == null) return 0.0;
    final candidates = [
      data['walletBalance'],
      data['wallet'],
      data['balance'],
    ];
    for (final candidate in candidates) {
      if (candidate is num) return candidate.toDouble();
      final parsed = double.tryParse((candidate ?? '').toString());
      if (parsed != null) return parsed;
    }
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('محفظتي'),
          backgroundColor: Colors.white,
          centerTitle: true,
          iconTheme: const IconThemeData(color: AppThemeArabic.clientPrimary),
          elevation: 1,
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('clients')
              .doc(widget.clientId)
              .snapshots(),
          builder: (context, clientSnapshot) {
            final clientData = clientSnapshot.data?.data() as Map<String, dynamic>?;
            final balance = _resolveWalletBalance(clientData);

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('wallet_recharges')
                  .where('clientId', isEqualTo: widget.clientId)
                  .limit(5)
                  .snapshots(),
              builder: (context, rechargeSnapshot) {
                final rechargeDocs = List<QueryDocumentSnapshot>.from(
                  rechargeSnapshot.data?.docs ?? const [],
                )
                  ..sort((a, b) {
                    final aTs = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                    final bTs = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                    return (bTs?.millisecondsSinceEpoch ?? 0)
                        .compareTo(aTs?.millisecondsSinceEpoch ?? 0);
                  });
                final pendingCount = rechargeDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = (data['status'] ?? '').toString().toLowerCase();
                  return status == 'pending' ||
                      status == 'pending_review' ||
                      status == 'under_review' ||
                      status == 'قيد المراجعة';
                }).length;

                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.account_balance_wallet,
                            size: 64,
                            color: AppThemeArabic.clientPrimary,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'رصيدك الحالي',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${balance.toStringAsFixed(2)} ج.س',
                            style: const TextStyle(
                              fontSize: 30,
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              pendingCount > 0
                                  ? 'لديك $pendingCount طلب شحن قيد المراجعة'
                                  : 'لا توجد طلبات شحن معلقة الآن',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ClientWalletRechargeScreen(
                                    clientId: widget.clientId,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('شحن المحفظة'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppThemeArabic.clientPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              textStyle:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ClientWalletHistoryScreen(
                                    clientId: widget.clientId,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.history),
                            label: const Text('سجل الشحن'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppThemeArabic.clientPrimary,
                              side: const BorderSide(
                                color: AppThemeArabic.clientPrimary,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'آخر طلبات الشحن',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 12),
                    if (rechargeDocs.isEmpty)
                      const Center(child: Text('لا يوجد سجل شحن حتى الآن'))
                    else
                      ...rechargeDocs.take(5).map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final createdAt = data['createdAt'] as Timestamp?;
                        final createdText = createdAt == null
                            ? ''
                            : createdAt.toDate().toString().substring(0, 16);
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: const Icon(
                              Icons.account_balance_wallet,
                              color: AppThemeArabic.clientPrimary,
                            ),
                            title: Text(
                              '${((data['amount'] ?? 0) as num).toDouble().toStringAsFixed(2)} ج.س',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              'الحالة: ${(data['status'] ?? 'pending').toString()}',
                            ),
                            trailing: Text(
                              createdText,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        );
                      }),
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
