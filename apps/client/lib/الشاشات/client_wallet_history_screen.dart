import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ClientWalletHistoryScreen extends StatefulWidget {
  final String clientId;
  const ClientWalletHistoryScreen({Key? key, required this.clientId}) : super(key: key);

  @override
  State<ClientWalletHistoryScreen> createState() => _ClientWalletHistoryScreenState();
}

class _ClientWalletHistoryScreenState extends State<ClientWalletHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('سجل المحفظة'),
          backgroundColor: Colors.white,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Color(0xFFFE724C)),
          elevation: 1,
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('wallet_recharges')
              .where('clientId', isEqualTo: widget.clientId)
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('لا يوجد عمليات شحن حتى الآن'));
            }
            final docs = snapshot.data!.docs;
            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: Icon(Icons.account_balance_wallet, color: Color(0xFFFE724C)),
                    title: Text('المبلغ: ${data['amount']} ج.س', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('الحالة: ${data['status']}', style: const TextStyle(color: Colors.grey)),
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
