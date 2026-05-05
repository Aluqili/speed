// lib/screens/client_orders_tab.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speedstar_core/speedstar_core.dart' show OrderStatusPalette;
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';
import 'cart_provider.dart';
import 'client_cart_screen.dart';
import 'client_order_details_screen.dart';
import 'client_track_driver_screen.dart';
import 'order_rating_sheet.dart';

class ClientOrdersTab extends StatefulWidget {
  final String clientId;
  const ClientOrdersTab({Key? key, required this.clientId}) : super(key: key);

  @override
  State<ClientOrdersTab> createState() => _ClientOrdersTabState();
}

class _ClientOrdersTabState extends State<ClientOrdersTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  static const Color primaryColor = AppThemeArabic.clientPrimary;
  static const Color backgroundColor = AppThemeArabic.clientBackground;

  static const _activeOrderStatuses = [
    'انتظار الدفع',
    'payment_review',
    'store_pending',
    'courier_searching',
    'courier_assigned',
    'pickup_ready',
    'picked_up',
    'arrived_to_client',
    'قيد المراجعة',
    'قيد التجهيز',
    'قيد التوصيل',
  ];
  static const _pastOrderStatuses = [
    'delivered',
    'store_rejected',
    'cancelled',
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
          title: const Text('طلباتي',
              style: TextStyle(
                  color: _ClientOrdersTabState.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  fontFamily: 'Tajawal')),
          iconTheme:
              const IconThemeData(color: _ClientOrdersTabState.primaryColor),
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
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = [...(snapshot.data?.docs ?? [])];
        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTs = aData['createdAt'] as Timestamp?;
          final bTs = bData['createdAt'] as Timestamp?;
          final aMs = aTs?.millisecondsSinceEpoch ?? 0;
          final bMs = bTs?.millisecondsSinceEpoch ?? 0;
          return bMs.compareTo(aMs);
        });
        // فلترة محلية حسب الحقلين paymentStatus و orderStatus
        final filtered = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final paymentStatus = (data['paymentStatus'] as String?) ?? '';
          final orderStatus = (data['orderStatus'] as String? ??
              data['status'] as String? ??
              '');
          final combined =
              paymentStatus == 'انتظار الدفع' ? 'انتظار الدفع' : orderStatus;
          return active
              ? _activeOrderStatuses.contains(combined)
              : _pastOrderStatuses.contains(combined);
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  active
                      ? Icons.hourglass_empty_rounded
                      : Icons.receipt_long_outlined,
                  size: 72,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  active ? 'لا توجد طلبات نشطة حالياً' : 'لا توجد طلبات سابقة',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  active
                      ? 'ستظهر طلباتك الجارية هنا'
                      : 'طلباتك المكتملة والملغاة ستظهر هنا',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
              ],
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
    final orderStatus =
        (data['orderStatus'] as String? ?? data['status'] as String? ?? '');
    final displayStatus = paymentStatus == 'انتظار الدفع'
        ? 'بانتظار رفع إيصال الدفع'
        : _statusText(orderStatus);
    final statusColor = _statusColor(orderStatus, paymentStatus);
    final total = (data['totalWithDelivery'] as num? ?? 0).toStringAsFixed(2);
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final restaurantName = (data['restaurantName'] ?? 'غير معروف').toString();
    final displayOrderNumber =
        ((data['orderNumber'] ?? data['orderId'] ?? orderId).toString()).trim();
    final canRateOrder = canSubmitOrderRating(data);
    final isDelivered =
        orderStatus == 'delivered' || orderStatus == 'تم التوصيل';
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
              displayOrderNumber.isEmpty ? orderId : displayOrderNumber,
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
          Row(
            children: [
              const Icon(Icons.storefront, size: 18, color: primaryColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  restaurantName.isEmpty ? 'غير معروف' : restaurantName,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ClientOrderDetailsScreen(orderId: orderId),
                    ),
                  );
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
            if (canRateOrder) ...[
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    showOrderRatingSheet(
                      context,
                      orderId: orderId,
                      orderData: data,
                    );
                  },
                  icon: const Icon(Icons.star_rate_rounded),
                  label: const Text('قيّم'),
                ),
              ),
            ] else if (orderStatus == 'courier_assigned' ||
                orderStatus == 'pickup_ready' ||
                orderStatus == 'قيد التوصيل' ||
                orderStatus == 'picked_up' ||
                orderStatus == 'arrived_to_client') ...[
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ClientTrackDriverScreen(orderId: orderId),
                      ),
                    );
                  },
                  icon: const Icon(Icons.location_on_outlined),
                  label: const Text('تتبع'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: BorderSide(color: primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ] else if (isDelivered) ...[
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _reorder(context, data),
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('إعادة الطلب'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: BorderSide(color: primaryColor),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ]),
        ]),
      ),
    );
  }

  String _statusText(String status) {
    return OrderStatusPalette.displayText(status);
  }

  Color _statusColor(String orderStatus, String paymentStatus) {
    return OrderStatusPalette.colorForStatus(
      orderStatus,
      paymentStatus: paymentStatus,
    );
  }

  Future<void> _reorder(
      BuildContext context, Map<String, dynamic> orderData) async {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final rawItems = orderData['items'];
    if (rawItems == null || rawItems is! List || rawItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد عناصر لإعادة الطلب')),
      );
      return;
    }

    final restaurantId =
        (orderData['restaurantId'] ?? '').toString().trim();
    if (restaurantId.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تعذر تحديد المطعم')));
      return;
    }

    // إذا كانت السلة تحتوي على مطعم مختلف، اسأل المستخدم
    if (cart.cartItems.isNotEmpty &&
        cart.cartItems.first.restaurantId != restaurantId) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('استبدال السلة'),
            content: const Text(
                'سلتك الحالية تحتوي على عناصر من مطعم آخر. هل تريد مسحها وإعادة هذا الطلب؟'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('إلغاء')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('تأكيد')),
            ],
          ),
        ),
      );
      if (confirm != true) return;
      await cart.clearCart();
    } else {
      await cart.clearCart();
    }

    int added = 0;
    for (final raw in rawItems) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final name = (item['name'] ?? '').toString().trim();
      final price = (item['price'] as num?)?.toDouble() ?? 0.0;
      final qty = (item['quantity'] as num?)?.toInt() ?? 1;
      final itemId = (item['id'] ?? item['menuItemId'] ?? name)
          .toString()
          .trim();
      if (itemId.isEmpty || name.isEmpty) continue;

      final cartItem = CartItem(
        id: itemId,
        restaurantId: restaurantId,
        menuItemId: (item['menuItemId'] ?? '').toString(),
        sizeKey: item['sizeKey']?.toString(),
        sizeLabel: item['sizeLabel']?.toString(),
        name: name,
        description: (item['description'] ?? '').toString(),
        quantity: qty,
        price: price,
      );
      await cart.addToCart(cartItem);
      added++;
    }

    if (!context.mounted) return;
    if (added == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر إضافة العناصر إلى السلة')));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تمت إضافة $added عنصر إلى السلة'),
        action: SnackBarAction(
          label: 'فتح السلة',
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ClientCartScreen())),
        ),
      ),
    );
  }
}
