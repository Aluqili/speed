import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' as intl;
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';

import 'client_wallet_history_screen.dart';
import 'client_wallet_recharge_screen.dart';
import 'client_wallet_withdrawal_screen.dart';

class ClientWalletScreen extends StatefulWidget {
  final String clientId;
  const ClientWalletScreen({Key? key, required this.clientId})
      : super(key: key);

  @override
  State<ClientWalletScreen> createState() => _ClientWalletScreenState();
}

class _ClientWalletScreenState extends State<ClientWalletScreen> {
  static const _primary = AppThemeArabic.clientPrimary;

  double _resolveWalletBalance(Map<String, dynamic>? data) {
    if (data == null) return 0.0;
    for (final key in ['walletBalance', 'wallet', 'balance']) {
      final v = data[key];
      if (v is num) return v.toDouble();
      final parsed = double.tryParse((v ?? '').toString());
      if (parsed != null) return parsed;
    }
    return 0.0;
  }

  ({String label, Color color, IconData icon}) _resolveStatus(String raw) {
    final s = raw.toLowerCase().trim();
    if (s == 'approved' || s == 'مقبول' || s == 'completed') {
      return (
        label: 'مقبول',
        color: Colors.green,
        icon: Icons.check_circle_rounded
      );
    }
    if (s == 'rejected' || s == 'مرفوض' || s == 'declined') {
      return (
        label: 'مرفوض',
        color: Colors.red,
        icon: Icons.cancel_rounded
      );
    }
    return (
      label: 'قيد المراجعة',
      color: Colors.orange,
      icon: Icons.hourglass_top_rounded
    );
  }

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '';
    final date = ts.toDate().toLocal();
    return intl.DateFormat('d MMM yyyy  hh:mm a', 'ar').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          title: const Text('محفظتي',
              style: TextStyle(color: _primary, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          centerTitle: true,
          iconTheme: const IconThemeData(color: _primary),
          elevation: 0.5,
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('clients')
              .doc(widget.clientId)
              .snapshots(),
          builder: (context, clientSnapshot) {
            final clientData =
                clientSnapshot.data?.data() as Map<String, dynamic>?;
            final balance = _resolveWalletBalance(clientData);

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('wallet_recharges')
                  .where('clientId', isEqualTo: widget.clientId)
                  .orderBy('createdAt', descending: true)
                  .limit(10)
                  .snapshots(),
              builder: (context, rechargeSnapshot) {
                final rechargeDocs =
                    rechargeSnapshot.data?.docs ?? const [];

                final pendingCount = rechargeDocs.where((doc) {
                  final s = ((doc.data() as Map<String, dynamic>)['status'] ??
                          '')
                      .toString()
                      .toLowerCase();
                  return s == 'pending' ||
                      s == 'pending_review' ||
                      s == 'under_review' ||
                      s == 'قيد المراجعة';
                }).length;

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('wallet_withdrawals')
                      .where('clientId', isEqualTo: widget.clientId)
                      .orderBy('createdAt', descending: true)
                      .limit(10)
                      .snapshots(),
                  builder: (context, withdrawalSnapshot) {
                    final withdrawalDocs =
                        withdrawalSnapshot.data?.docs ?? const [];

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                    // ─── بطاقة الرصيد ──────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 28),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _primary,
                            _primary.withValues(alpha: 0.75)
                          ],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: _primary.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.account_balance_wallet_rounded,
                              size: 48, color: Colors.white),
                          const SizedBox(height: 12),
                          const Text('رصيدك الحالي',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 14)),
                          const SizedBox(height: 6),
                          Text(
                            '${balance.toStringAsFixed(2)} ج.س',
                            style: const TextStyle(
                              fontSize: 36,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (pendingCount > 0) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$pendingCount طلب شحن قيد المراجعة',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ─── أزرار الإجراءات ───────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ClientWalletRechargeScreen(
                                    clientId: widget.clientId),
                              ),
                            ),
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('شحن المحفظة'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              textStyle: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: balance <= 0
                                ? null
                                : () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ClientWalletWithdrawalScreen(
                                          clientId: widget.clientId,
                                          walletBalance: balance,
                                        ),
                                      ),
                                    ),
                            icon: const Icon(Icons.arrow_circle_up_rounded),
                            label: const Text('سحب رصيد'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  Colors.orange.withValues(alpha: 0.3),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              textStyle: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ClientWalletHistoryScreen(
                                    clientId: widget.clientId),
                              ),
                            ),
                            icon: const Icon(Icons.history_rounded),
                            label: const Text('السجل'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _primary,
                              side: const BorderSide(color: _primary),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ─── آخر طلبات الشحن ───────────────────────────
                    if (rechargeDocs.isNotEmpty) ...[
                      const Text(
                        'آخر طلبات الشحن',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 10),
                      ...rechargeDocs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final amount =
                            ((data['amount'] ?? 0) as num).toDouble();
                        final ts = data['createdAt'];
                        final dateStr = _formatDate(
                            ts is Timestamp ? ts : null);
                        final status =
                            _resolveStatus((data['status'] ?? '').toString());

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: const [
                              BoxShadow(
                                  color: Color(0x0A000000),
                                  blurRadius: 6,
                                  offset: Offset(0, 2))
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: status.color
                                      .withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(status.icon,
                                    color: status.color, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${amount.toStringAsFixed(2)} ج.س',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15),
                                    ),
                                    if (dateStr.isNotEmpty)
                                      Text(dateStr,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[500])),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: status.color
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  status.label,
                                  style: TextStyle(
                                      color: status.color,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ] else ...[
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Column(
                            children: [
                              Icon(Icons.inbox_rounded,
                                  size: 48, color: Colors.grey[300]),
                              const SizedBox(height: 8),
                              Text('لا يوجد سجل شحن حتى الآن',
                                  style: TextStyle(color: Colors.grey[500])),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // ─── طلبات السحب ───────────────────────────────
                    if (withdrawalDocs.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'طلبات السحب',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 10),
                      ...withdrawalDocs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final amount =
                            ((data['amount'] ?? 0) as num).toDouble();
                        final ts = data['createdAt'];
                        final dateStr = _formatDate(
                            ts is Timestamp ? ts : null);
                        final status = _resolveStatus(
                            (data['status'] ?? '').toString());
                        final method =
                            (data['paymentMethod'] ?? '').toString();
                        final account =
                            (data['accountNumber'] ?? '').toString();

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: const [
                              BoxShadow(
                                  color: Color(0x0A000000),
                                  blurRadius: 6,
                                  offset: Offset(0, 2))
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: status.color
                                      .withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                    Icons.arrow_circle_up_rounded,
                                    color: status.color,
                                    size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${amount.toStringAsFixed(2)} ج.س',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15),
                                    ),
                                    if (method.isNotEmpty)
                                      Text(method,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600])),
                                    if (account.isNotEmpty)
                                      Text(account,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[500])),
                                    if (dateStr.isNotEmpty)
                                      Text(dateStr,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[400])),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: status.color
                                      .withValues(alpha: 0.1),
                                  borderRadius:
                                      BorderRadius.circular(20),
                                ),
                                child: Text(
                                  status.label,
                                  style: TextStyle(
                                      color: status.color,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
