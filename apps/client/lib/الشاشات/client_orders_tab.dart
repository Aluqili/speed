// lib/screens/client_orders_tab.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'client_order_details_screen.dart';
import 'client_track_driver_screen.dart';

class ClientOrdersTab extends StatefulWidget {
  final String clientId;
  const ClientOrdersTab({Key? key, required this.clientId}) : super(key: key);

  @override
  State<ClientOrdersTab> createState() => _ClientOrdersTabState();
}

class _ClientOrdersTabState extends State<ClientOrdersTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  static const Color primaryColor = Color(0xFFFE724C);
  static const Color backgroundColor = Color(0xFFF5F5F5);

  static const _activeOrderStatuses = [
    'انتظار الدفع',
    'قيد المراجعة',
    'قيد التجهيز',
    'قيد التوصيل',
  ];
  static const _pastOrderStatuses = [
    'تم التوصيل',
    'ملغي',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _ClientOrdersTabState.backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          centerTitle: true,
          title: const Text('طلباتي', style: TextStyle(color: _ClientOrdersTabState.primaryColor, fontWeight: FontWeight.bold, fontSize: 20, fontFamily: 'Tajawal')),
          iconTheme: const IconThemeData(color: _ClientOrdersTabState.primaryColor),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
          ),
          automaticallyImplyLeading: false, // إخفاء سهم الرجوع
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: _ClientOrdersTabState.primaryColor,
            labelColor: _ClientOrdersTabState.primaryColor,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: 'نشطة'),
              Tab(text: 'السابقة'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildOrdersList(active: true),
            _buildOrdersList(active: false),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersList({required bool active}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('clientId', isEqualTo: widget.clientId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        // فلترة محلية حسب الحقلين paymentStatus و orderStatus
        final filtered = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final paymentStatus = (data['paymentStatus'] as String?) ?? '';
          final orderStatus = (data['orderStatus'] as String?) ?? '';
          final combined = paymentStatus == 'انتظار الدفع'
              ? 'انتظار الدفع'
              : orderStatus;
          return active
              ? _activeOrderStatuses.contains(combined)
              : _pastOrderStatuses.contains(combined);
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Text(
              active ? 'لا توجد طلبات حالية' : 'لا توجد طلبات سابقة',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final doc = filtered[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildOrderCard(doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildOrderCard(String orderId, Map<String, dynamic> data) {
    final paymentStatus = (data['paymentStatus'] as String?) ?? '';
    final orderStatus = (data['orderStatus'] as String?) ?? '';
    final displayStatus = paymentStatus == 'انتظار الدفع'
        ? 'بانتظار رفع إيصال الدفع'
        : _statusText(orderStatus);
    final statusColor = _statusColor(orderStatus, paymentStatus);
    final total = (data['totalWithDelivery'] as num? ?? 0).toStringAsFixed(2);
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.receipt, color: primaryColor),
            const SizedBox(width: 8),
            Text(
              '#${orderId.substring(0, 8)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Text(
              createdAt != null
                  ? '${createdAt.day}/${createdAt.month}/${createdAt.year}'
                  : 'غير متاح',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.monetization_on, size: 18, color: primaryColor),
            const SizedBox(width: 4),
            Text('$total ج.س', style: const TextStyle(fontSize: 14)),
            const Spacer(),
            Chip(
              label: Text(displayStatus,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: statusColor)),
              backgroundColor: statusColor.withOpacity(0.15),
            ),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Get.to(() =>
                      ClientOrderDetailsScreen(orderId: orderId));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                icon: const Icon(Icons.info_outline),
                label: const Text('تفاصيل'),
              ),
            ),
            const SizedBox(width: 12),
            if (orderStatus == 'قيد التوصيل')
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Get.to(() =>
                        ClientTrackDriverScreen(orderId: orderId));
                  },
                  icon: const Icon(Icons.location_on_outlined),
                  label: const Text('تتبع'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: BorderSide(color: primaryColor),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
          ]),
        ]),
      ),
    );
  }

  String _statusText(String status) {
    switch (status) {
      case 'قيد المراجعة':
        return 'قيد المراجعة';
      case 'قيد التجهيز':
        return 'قيد التجهيز';
      case 'قيد التوصيل':
        return 'قيد التوصيل';
      case 'تم التوصيل':
        return 'تم التوصيل';
      case 'ملغي':
        return 'ملغي';
      default:
        return status;
    }
  }

  Color _statusColor(String orderStatus, String paymentStatus) {
    if (paymentStatus == 'انتظار الدفع') {
      return Colors.orange;
    }
    switch (orderStatus) {
      case 'قيد المراجعة':
        return Colors.orange;
      case 'قيد التجهيز':
        return Colors.blue;
      case 'قيد التوصيل':
        return Colors.green;
      case 'تم التوصيل':
        return Colors.teal;
      case 'ملغي':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
