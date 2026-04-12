import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';

String _walletStatusText(String status) {
  switch (status.trim().toLowerCase()) {
    case 'pending_review':
    case 'pending':
    case 'under_review':
      return 'قيد المراجعة';
    case 'approved':
    case 'paid':
      return 'تمت الموافقة';
    case 'rejected':
      return 'مرفوض';
    default:
      return status;
  }
}

class ClientWalletHistoryScreen extends StatefulWidget {
  final String clientId;
  const ClientWalletHistoryScreen({Key? key, required this.clientId}) : super(key: key);

  @override
  State<ClientWalletHistoryScreen> createState() => _ClientWalletHistoryScreenState();
}

class _ClientWalletHistoryScreenState extends State<ClientWalletHistoryScreen> {
  Query<Map<String, dynamic>> _historyQuery() {
    return FirebaseFirestore.instance
        .collection('wallet_recharges')
      .where('clientId', isEqualTo: widget.clientId);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('سجل المحفظة'),
          backgroundColor: Colors.white,
          centerTitle: true,
          iconTheme: const IconThemeData(color: AppThemeArabic.clientPrimary),
          elevation: 1,
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _historyQuery().snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.history_toggle_off,
                        size: 44,
                        color: AppThemeArabic.clientPrimary,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'تعذر تحميل سجل الشحن الآن.',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('لا يوجد عمليات شحن حتى الآن'));
            }
            final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
              snapshot.data!.docs,
            )
              ..sort((a, b) {
                final aTs = a.data()['createdAt'] as Timestamp?;
                final bTs = b.data()['createdAt'] as Timestamp?;
                return (bTs?.millisecondsSinceEpoch ?? 0)
                    .compareTo(aTs?.millisecondsSinceEpoch ?? 0);
              });
            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: Icon(Icons.account_balance_wallet, color: AppThemeArabic.clientPrimary),
                    title: Text('المبلغ: ${data['amount']} ج.س', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      'الحالة: ${_walletStatusText((data['status'] ?? '').toString())}\n'
                      'الطريقة: ${_walletMethodLabel((data['paymentMethod'] ?? '').toString())}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    trailing: Text(
                      data['createdAt'] != null
                          ? (data['createdAt'] as Timestamp).toDate().toString().substring(0, 16)
                          : '',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

String _walletMethodLabel(String method) {
  switch (method.trim().toLowerCase()) {
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
