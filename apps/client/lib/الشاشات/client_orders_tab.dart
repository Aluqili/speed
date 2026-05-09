// lib/screens/client_orders_tab.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speedstar_core/speedstar_core.dart' show OrderStatusPalette;
import '../الثيم/client_theme.dart';
import 'cart_provider.dart';
import 'client_cart_screen.dart';
import 'client_order_details_screen.dart';
import 'client_track_driver_screen.dart';
import 'order_rating_sheet.dart';

class ClientOrdersTab extends StatefulWidget {
  final String clientId;
  const ClientOrdersTab({super.key, required this.clientId});

  @override
  State<ClientOrdersTab> createState() => _ClientOrdersTabState();
}

class _ClientOrdersTabState extends State<ClientOrdersTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  static const Color primaryColor = ClientColors.primary;

  static const _activeOrderStatuses = [
    'انتظار الدفع',
    'payment_review',
    'store_pending',
    'courier_searching',
    'courier_offer_pending',
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

  // مراحل تقدم الطلب النشط بالترتيب
  static const _progressSteps = [
    ('payment_review', 'الدفع', Icons.payments_rounded),
    ('store_pending', 'التجهيز', Icons.restaurant_rounded),
    ('courier_searching', 'المندوب', Icons.delivery_dining_rounded),
    ('picked_up', 'في الطريق', Icons.directions_bike_rounded),
    ('arrived_to_client', 'وصل', Icons.check_circle_rounded),
  ];

  int _stepIndex(String status) {
    if (status == 'payment_review' || status == 'انتظار الدفع') return 0;
    if (status == 'store_pending' || status == 'قيد المراجعة' ||
        status == 'قيد التجهيز') {
      return 1;
    }
    if (status == 'courier_searching' || status == 'courier_offer_pending') {
      return 2;
    }
    if (status == 'courier_assigned' || status == 'pickup_ready' ||
        status == 'picked_up' || status == 'قيد التوصيل') {
      return 3;
    }
    if (status == 'arrived_to_client') return 4;
    return -1;
  }

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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          centerTitle: true,
          title: const Text(
            'طلباتي',
            style: TextStyle(
              color: ClientColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          automaticallyImplyLeading: false,
          elevation: 0,
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: primaryColor,
            labelColor: primaryColor,
            unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
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
          return const Center(
            child: CircularProgressIndicator(color: primaryColor),
          );
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
        final filtered = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final paymentStatus = (data['paymentStatus'] as String?) ?? '';
          final orderStatus =
              (data['orderStatus'] as String? ?? data['status'] as String? ?? '');
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
                  size: 64,
                  color: ClientColors.textSecondary.withValues(alpha: 0.25),
                ),
                const SizedBox(height: 16),
                Text(
                  active ? 'لا توجد طلبات نشطة حالياً' : 'لا توجد طلبات سابقة',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface),
                ),
                const SizedBox(height: 8),
                Text(
                  active
                      ? 'ستظهر طلباتك الجارية هنا'
                      : 'طلباتك المكتملة والملغاة ستظهر هنا',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final doc = filtered[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildOrderCard(doc.id, data, active: active);
          },
        );
      },
    );
  }

  Widget _buildOrderCard(String orderId, Map<String, dynamic> data,
      {required bool active}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? ClientColors.surface : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final textSec = isDark ? ClientColors.textSecondary : const Color(0xFF6B6B6B);
    final paymentStatus = (data['paymentStatus'] as String?) ?? '';
    final orderStatus =
        (data['orderStatus'] as String? ?? data['status'] as String? ?? '');
    final displayStatus = paymentStatus == 'انتظار الدفع'
        ? 'بانتظار رفع إيصال الدفع'
        : _statusText(orderStatus);
    final statusColor = _statusColor(orderStatus, paymentStatus);
    final total =
        (data['totalWithDelivery'] as num? ?? 0).toStringAsFixed(2);
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final restaurantName =
        (data['restaurantName'] ?? 'غير معروف').toString();
    final restaurantImage =
        (data['restaurantImage'] ?? '').toString().trim();
    final displayOrderNumber =
        ((data['orderNumber'] ?? data['orderId'] ?? orderId).toString())
            .trim();
    final canRateOrder = canSubmitOrderRating(data);
    final isDelivered =
        orderStatus == 'delivered' || orderStatus == 'تم التوصيل';
    final isTracking = orderStatus == 'courier_assigned' ||
        orderStatus == 'pickup_ready' ||
        orderStatus == 'قيد التوصيل' ||
        orderStatus == 'picked_up' ||
        orderStatus == 'arrived_to_client';
    final currentStep = _stepIndex(
        paymentStatus == 'انتظار الدفع' ? 'payment_review' : orderStatus);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x171C110A), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1C110A),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── رأس البطاقة ───────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? ClientColors.primary.withValues(alpha: 0.10)
                  : ClientColors.primary.withValues(alpha: 0.06),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Text(
                  createdAt != null
                      ? '${createdAt.day}/${createdAt.month}/${createdAt.year}'
                      : '',
                  style: TextStyle(color: textSec, fontSize: 12),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                            color: statusColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        displayStatus,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.5),

          // ─── جسم البطاقة ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // إجمالي الطلب
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الإجمالي',
                      style: TextStyle(
                          color: textSec,
                          fontSize: 11),
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
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        displayOrderNumber.isEmpty ? orderId : displayOrderNumber,
                        textAlign: TextAlign.right,
                        style: TextStyle(color: textSec, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // صورة المطعم أو أيقونة بديلة
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: restaurantImage.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: restaurantImage,
                          width: 38,
                          height: 38,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _RestaurantIconBox(),
                        )
                      : _RestaurantIconBox(),
                ),
              ],
            ),
          ),

          // ─── شريط تقدم الطلب (للطلبات النشطة فقط) ─────────────
          if (active && currentStep >= 0) ...[
            const Divider(height: 1, thickness: 0.5),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: _OrderProgressBar(
                steps: _progressSteps,
                currentStep: currentStep,
                statusColor: statusColor,
              ),
            ),
          ],

          // ─── أزرار الإجراء ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
            child: Row(children: [
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: outline
              ? ClientColors.primary.withValues(alpha: 0.10)
              : ClientColors.primary,
          borderRadius: BorderRadius.circular(9),
          border: outline
              ? Border.all(color: const Color(0x171C110A))
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: outline ? ClientColors.primary : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  String _statusText(String status) =>
      OrderStatusPalette.displayText(status);

  Color _statusColor(String orderStatus, String paymentStatus) =>
      OrderStatusPalette.colorForStatus(
        orderStatus,
        paymentStatus: paymentStatus,
      );

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
      final itemId =
          (item['id'] ?? item['menuItemId'] ?? name).toString().trim();
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

// ─── أيقونة بديلة للمطعم ──────────────────────────────────────────────────

class _RestaurantIconBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: ClientColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.storefront_rounded,
          color: ClientColors.primary, size: 20),
    );
  }
}

// ─── شريط تقدم الطلب ──────────────────────────────────────────────────────

class _OrderProgressBar extends StatelessWidget {
  final List<(String, String, IconData)> steps;
  final int currentStep;
  final Color statusColor;

  const _OrderProgressBar({
    required this.steps,
    required this.currentStep,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          // خط الفاصل
          final stepIdx = i ~/ 2;
          final done = stepIdx < currentStep;
          return Expanded(
            child: Container(
              height: 2,
              color: done
                  ? statusColor
                  : ClientColors.textSecondary.withValues(alpha: 0.2),
            ),
          );
        }
        final stepIdx = i ~/ 2;
        final (_, label, icon) = steps[stepIdx];
        final done = stepIdx <= currentStep;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: done
                    ? statusColor
                    : ClientColors.textSecondary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 15,
                color: done
                    ? Colors.white
                    : ClientColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: done ? FontWeight.w700 : FontWeight.w400,
                color: done
                    ? statusColor
                    : ClientColors.textSecondary,
              ),
            ),
          ],
        );
      }),
    );
  }
}
