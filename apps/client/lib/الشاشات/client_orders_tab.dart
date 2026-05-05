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
                  fontSize: 18,
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
    final isTracking = orderStatus == 'courier_assigned' ||
        orderStatus == 'pickup_ready' ||
        orderStatus == 'قيد التوصيل' ||
        orderStatus == 'picked_up' ||
        orderStatus == 'arrived_to_client';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.055),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── رأس البطاقة: الحالة والتاريخ ─────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.06),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Text(
                  createdAt != null
                      ? '${createdAt.day}/${createdAt.month}/${createdAt.year}'
                      : '',
                  style:
                      const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                ),
                const Spacer(),
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.only(left: 6),
                  decoration: BoxDecoration(
                      color: statusColor, shape: BoxShape.circle),
                ),
                Text(
                  displayStatus,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.5),

          // ─── جسم البطاقة: المطعم والمبلغ ──────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // إجمالي الطلب
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'الإجمالي',
                      style: TextStyle(
                          color: Color(0xFF9CA3AF), fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$total ج.س',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                // اسم المطعم ورقم الطلب
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        restaurantName.isEmpty ? 'غير معروف' : restaurantName,
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Color(0xFF1A1D26),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        displayOrderNumber.isEmpty ? orderId : displayOrderNumber,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            color: Color(0xFF9CA3AF), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // أيقونة المطعم
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.storefront_rounded,
                      color: primaryColor, size: 20),
                ),
              ],
            ),
          ),

          // ─── أزرار الإجراء ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(children: [
              // زر إعادة الطلب أو التتبع أو التقييم
              if (canRateOrder) ...[
                Expanded(
                  child: _actionButton(
                    label: 'تقييم الطلب',
                    icon: Icons.star_rounded,
                    outline: true,
                    onTap: () => showOrderRatingSheet(
                      context,
                      orderId: orderId,
                      orderData: data,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ] else if (isTracking) ...[
                Expanded(
                  child: _actionButton(
                    label: 'تتبع المندوب',
                    icon: Icons.location_on_rounded,
                    outline: true,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ClientTrackDriverScreen(orderId: orderId),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ] else if (isDelivered) ...[
                Expanded(
                  child: _actionButton(
                    label: 'إعادة الطلب',
                    icon: Icons.replay_rounded,
                    outline: true,
                    onTap: () => _reorder(context, data),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: _actionButton(
                  label: 'التفاصيل',
                  icon: Icons.receipt_long_rounded,
                  outline: false,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ClientOrderDetailsScreen(orderId: orderId),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required bool outline,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: outline ? Colors.transparent : primaryColor,
          borderRadius: BorderRadius.circular(12),
          border: outline
              ? Border.all(color: primaryColor.withValues(alpha: 0.5))
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 15,
                color: outline ? primaryColor : Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: outline ? primaryColor : Colors.white,
              ),
            ),
          ],
        ),
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
