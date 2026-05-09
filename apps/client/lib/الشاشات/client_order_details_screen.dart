import 'package:flutter/material.dart';
import '../الثيم/client_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:getwidget/getwidget.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:speedstar_core/speedstar_core.dart'
    show formatUnifiedOrderCode, OrderStatusPalette;

import 'client_track_driver_screen.dart';
import 'chat_screen.dart';
import 'payment_screen.dart';
import 'order_rating_sheet.dart';

class AppColors {
  static const Color primaryColor = ClientColors.primary;
  static const Color backgroundColor = ClientColors.lightBackground;
}

const List<String> _allSteps = [
  'انتظار الدفع',
  'قيد المراجعة',
  'قيد التجهيز',
  'قيد التوصيل',
  'تم التوصيل',
  'ملغي',
];

class ClientOrderDetailsScreen extends StatelessWidget {
  String _displayOrderNumber(Map<String, dynamic> data) {
    final candidates = [
      data['orderNumber'],
      data['orderId'],
      orderId,
    ];
    for (final candidate in candidates) {
      final value = (candidate ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return orderId;
  }

  final String orderId;
  const ClientOrderDetailsScreen({super.key, required this.orderId});

  String _normalizeOrderStep(String status) {
    switch (status.trim()) {
      case 'pending_payment':
      case 'انتظار الدفع':
        return 'انتظار الدفع';
      case 'payment_review':
      case 'store_pending':
      case 'قيد المراجعة':
        return 'قيد المراجعة';
      case 'courier_searching':
      case 'courier_offer_pending':
      case 'courier_assigned':
      case 'pickup_ready':
      case 'قيد التجهيز':
        return 'قيد التجهيز';
      case 'picked_up':
      case 'arrived_to_client':
      case 'قيد التوصيل':
        return 'قيد التوصيل';
      case 'delivered':
      case 'تم التوصيل':
        return 'تم التوصيل';
      case 'cancelled':
      case 'store_rejected':
      case 'ملغي':
        return 'ملغي';
      default:
        return 'قيد المراجعة';
    }
  }

  String _normalizePaymentStatus(String paymentStatus) {
    switch (paymentStatus.trim()) {
      case 'pending':
      case 'انتظار الدفع':
        return 'انتظار الدفع';
      case 'under_review':
      case 'قيد المراجعة':
        return 'قيد المراجعة';
      case 'paid':
      case 'تم الدفع':
        return 'تم الدفع';
      case 'rejected':
      case 'رفض الدفع':
        return 'مرفوض';
      default:
        return paymentStatus.trim();
    }
  }

  String _getPaymentStatusText(String paymentStatus) {
    switch (paymentStatus) {
      case 'انتظار الدفع':
        return '🔔 بانتظار رفع إيصال الدفع';
      case 'قيد المراجعة':
        return '🔔 بانتظار موافقة الأدمن';
      case 'مرفوض':
      case 'رفض الدفع':
        return '❌ تم رفض الدفع';
      case 'تم الدفع':
        return '✅ تم استلام الدفع';
      default:
        return '✅ تمت الموافقة على الدفع';
    }
  }

  double _getPaymentProgress(String paymentStatus) {
    switch (paymentStatus) {
      case 'انتظار الدفع':
        return 0.25;
      case 'قيد المراجعة':
        return 0.5;
      default:
        return 1.0;
    }
  }

  String? _formatDate(dynamic ts) {
    if (ts is Timestamp) {
      final dt = ts.toDate();
      return '${dt.day}/${dt.month}/${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return null;
  }

  String _generateChatId(String user1, String user2) {
    final sorted = [user1, user2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  String _resolveDriverPhone(
    Map<String, dynamic> orderData,
    Map<String, dynamic>? driverData,
  ) {
    final candidates = [
      orderData['driverPhone'],
      orderData['driverPhoneNumber'],
      driverData?['phone'],
      driverData?['phoneNumber'],
    ];

    for (final candidate in candidates) {
      final value = (candidate ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  Future<void> _callDriver(BuildContext context, String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    final launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح تطبيق الاتصال.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderRef =
        FirebaseFirestore.instance.collection('orders').doc(orderId);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? ClientColors.surface : Colors.white;
    final cardBorder = isDark ? const Color(0x22FF6B00) : const Color(0x14000000);
    final cardShadow = ClientColors.softCardShadow(
      dark: isDark,
      opacity: 0.06,
      blur: 16,
      offset: const Offset(0, 6),
    );
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textSecondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 0,
          centerTitle: true,
          title: const Text('تفاصيل الطلب',
              style: TextStyle(
                  color: AppColors.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  fontFamily: 'Tajawal')),
          iconTheme: const IconThemeData(color: AppColors.primaryColor),
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: orderRef.snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: GFLoader(type: GFLoaderType.circle));
            }
            if (!snap.hasData || !snap.data!.exists) {
              return const Center(child: Text('لا توجد بيانات لهذا الطلب.'));
            }

            final data = snap.data!.data()! as Map<String, dynamic>;
            final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
            final total = (data['total'] as num?)?.toDouble() ?? 0.0;
            final delivery = (data['deliveryFee'] as num?)?.toDouble() ?? 0.0;
            final largeOrderFee =
                (data['largeOrderFee'] as num?)?.toDouble() ?? 0.0;
            final totalWithDelivery =
                (data['totalWithDelivery'] as num?)?.toDouble() ??
                    (total + delivery + largeOrderFee);
            final walletUsedAmount =
                (data['walletUsedAmount'] as num?)?.toDouble() ??
                (data['walletRequestedAmount'] as num?)?.toDouble() ?? 0.0;
            final discountAmount =
                (data['discountAmount'] as num?)?.toDouble() ?? 0.0;
            final amountPaidExternal =
                (data['externalPaidAmount'] as num?)?.toDouble() ?? 0.0;
            final rawPaymentStatus =
                (data['paymentStatus'] as String?)?.trim() ?? '';
            final rawOrderStatus =
                ((data['orderStatus'] ?? data['status']) as String?)?.trim() ??
                    '';
            final paymentStatus = _normalizePaymentStatus(rawPaymentStatus);
            final orderStatus = _normalizeOrderStep(rawOrderStatus);
            final assignedDriverId =
                (data['assignedDriverId'] ?? '').toString().trim();
            final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
            final clientId =
                (data['clientId'] ?? currentUserId).toString().trim();
            final clientName =
                (data['clientName'] ?? data['name'] ?? 'العميل').toString();
            final restaurantName =
                (data['restaurantName'] ?? 'غير معروف').toString().trim();
            final displayOrderNumber = _displayOrderNumber(data);
            final canRateOrder = canSubmitOrderRating(data);
            final restaurantRating =
                ((data['restaurantRating'] as num?)?.toDouble() ?? 0).round();
            final courierRating =
                ((data['courierRating'] as num?)?.toDouble() ?? 0).round();
            final restaurantComment =
                (data['restaurantComment'] ?? '').toString().trim();
            final courierComment =
                (data['courierComment'] ?? '').toString().trim();

            int currentStep = _allSteps.indexOf(orderStatus);
            if (currentStep < 0) currentStep = 0;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // بطاقة حالة الدفع
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cardBorder),
                        boxShadow: cardShadow,
                      ),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getPaymentStatusText(paymentStatus),
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryColor),
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: _getPaymentProgress(paymentStatus),
                                backgroundColor: Colors.grey[300],
                                valueColor: const AlwaysStoppedAnimation(
                                    AppColors.primaryColor),
                                minHeight: 8,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (paymentStatus == 'انتظار الدفع')
                              GFButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          PaymentScreen(orderId: orderId),
                                    ),
                                  );
                                },
                                text: 'رفع إيصال الدفع',
                                color: GFColors.WARNING,
                                fullWidthButton: true,
                              ),
                          ]),
                    ),

                    if (assignedDriverId.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('drivers')
                            .doc(assignedDriverId)
                            .snapshots(),
                        builder: (context, driverSnap) {
                          final driverData =
                              driverSnap.data?.data() as Map<String, dynamic>?;
                          final driverName = (data['driverName'] ??
                                  driverData?['name'] ??
                                  'المندوب')
                              .toString();
                          final driverPhone =
                              _resolveDriverPhone(data, driverData);
                          final canChat = clientId.isNotEmpty;

                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: cardBorder),
                              boxShadow: cardShadow,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'تواصل مع $driverName',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                    ),
                                  ),
                                ),
                                IconButton.filledTonal(
                                  onPressed: !canChat
                                      ? null
                                      : () {
                                          final chatId = _generateChatId(
                                            clientId,
                                            assignedDriverId,
                                          );
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => ChatScreen(
                                                currentUserId: clientId,
                                                otherUserId: assignedDriverId,
                                                currentUserRole: 'client',
                                                chatId: chatId,
                                                currentUserName: clientName,
                                              ),
                                            ),
                                          );
                                        },
                                  tooltip: 'دردشة مع المندوب',
                                  icon: const Icon(Icons.chat_bubble_outline),
                                ),
                                const SizedBox(width: 8),
                                IconButton.filledTonal(
                                  onPressed: driverPhone.isEmpty
                                      ? null
                                      : () => _callDriver(
                                            context,
                                            driverPhone,
                                          ),
                                  tooltip: 'اتصال بالمندوب',
                                  icon: const Icon(Icons.call_outlined),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],

                    const SizedBox(height: 24),

                    // معلومات الطلب والفاتورة
                    Text('معلومات الطلب',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textPrimary)),
                    const SizedBox(height: 8),
                    // عرض رقم الطلب الموحّد إذا وجد، وإلا جزء من doc.id
                    // عرض رقم الطلب مع آخر 4 أرقام بشكل بارز
                    Builder(
                      builder: (_) {
                        final orderNumber = displayOrderNumber;
                        String last4 = orderNumber.length >= 4
                            ? orderNumber.substring(orderNumber.length - 4)
                            : orderNumber;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('رقم الطلب:',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: textPrimary)),
                                const SizedBox(width: 8),
                                Text(
                                  orderNumber,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryColor,
                                    fontSize: 22,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text('المطعم:',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: textPrimary)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    restaurantName.isEmpty
                                        ? 'غير معروف'
                                        : restaurantName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.only(top: 4.0, bottom: 8.0),
                              child: Row(
                                children: [
                                  const Icon(Icons.confirmation_number,
                                      color: AppColors.primaryColor, size: 20),
                                  const SizedBox(width: 6),
                                  Text(
                                    'آخر 4 أرقام: ',
                                    style: TextStyle(
                                        fontSize: 15,
                                        color: textSecondary,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    last4,
                                    style: TextStyle(
                                      fontSize: 20,
                                      color: textPrimary,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    _buildRow(context, 'تاريخ الطلب',
                        _formatDate(data['createdAt']) ?? 'غير متاح'),
                    const Divider(height: 32),
                    Text('تفاصيل الفاتورة',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textPrimary)),
                    const SizedBox(height: 8),
                    _buildRow(context,
                        'قيمة الأصناف', '${total.toStringAsFixed(2)} ج.س'),
                    _buildRow(context,
                        'رسوم التوصيل',
                        delivery == 0
                            ? 'مجانًا'
                            : '${delivery.toStringAsFixed(2)} ج.س'),
                    if (largeOrderFee > 0)
                      _buildRow(
                        context,
                        'رسوم الخدمة',
                        '${largeOrderFee.toStringAsFixed(2)} ج.س',
                        subtle: true,
                      ),
                    if (discountAmount > 0)
                      _buildRow(context, 'خصم الرمز الترويجي',
                          '-${discountAmount.toStringAsFixed(2)} ج.س',
                          valueColor: Colors.green),
                    _buildRow(context, 'الإجمالي',
                        '${totalWithDelivery.toStringAsFixed(2)} ج.س',
                        bold: walletUsedAmount <= 0),
                    if (walletUsedAmount > 0) ...[
                      _buildRow(context, 'خصم المحفظة',
                          '-${walletUsedAmount.toStringAsFixed(2)} ج.س',
                          valueColor: Colors.green),
                      _buildRow(
                          context,
                          'المبلغ المدفوع فعلياً',
                          amountPaidExternal <= 0
                              ? 'مدفوع بالكامل من المحفظة'
                              : '${amountPaidExternal.toStringAsFixed(2)} ج.س',
                          bold: true,
                          valueColor: amountPaidExternal <= 0
                              ? Colors.green
                              : AppColors.primaryColor),
                    ],
                    const Divider(height: 32),

                    // رقم الطلب بشكل بارز أسفل معلومات الطلب
                    Row(
                      children: [
                        Text('رقم الطلب: ',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: textPrimary)),
                        Text(
                          formatUnifiedOrderCode(
                            orderNumber: data['orderNumber'],
                            orderId: data['orderId'],
                            docId: orderId,
                          ),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryColor,
                              fontSize: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // الأصناف
                    Text('الأصناف المطلوبة',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textPrimary)),
                    const SizedBox(height: 8),
                    ...items.map((item) => Card(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: const Icon(Icons.restaurant_menu,
                                color: AppColors.primaryColor),
                            title: Text(item['name'] ?? 'اسم غير متاح'),
                            subtitle: Text(
                                'الكمية: ${item['quantity']} | السعر: ${item['price']} ج.س'),
                          ),
                        )),

                    const SizedBox(height: 24),

                    // شريط تقدم الطلب الكامل
                    Text('تقدم الطلب',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textPrimary)),
                    const SizedBox(height: 12),
                    Column(
                      children: List.generate(_allSteps.length, (i) {
                        final label = _allSteps[i];
                        final done = i < currentStep;
                        final active = i == currentStep;
                        final color = done
                            ? OrderStatusPalette.delivered
                            : active
                                ? OrderStatusPalette.colorForStatus(label)
                                : OrderStatusPalette.neutral;
                        final icon = done
                            ? Icons.check_circle
                            : active
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked;
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(icon, color: color),
                              const SizedBox(width: 12),
                              Text(label,
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: active
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: color)),
                            ],
                          ),
                        );
                      }),
                    ),

                    if (assignedDriverId.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('drivers')
                            .doc(assignedDriverId)
                            .snapshots(),
                        builder: (context, driverSnap) {
                          final driverData =
                              driverSnap.data?.data() as Map<String, dynamic>?;
                          final driverName = (data['driverName'] ??
                                  driverData?['name'] ??
                                  'المندوب')
                              .toString();
                          final driverPhone =
                              _resolveDriverPhone(data, driverData);

                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: cardBorder),
                              boxShadow: cardShadow,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '🛵 خيارات المندوب: $driverName',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                  ),
                                ),
                                if (driverPhone.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'رقم المندوب: $driverPhone',
                                    style:
                                        TextStyle(color: textSecondary),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                ClientTrackDriverScreen(
                                              orderId: orderId,
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.location_on),
                                      label: const Text('تتبع المندوب'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],

                    const SizedBox(height: 24),

                    if (canRateOrder)
                      _buildRatingActionCard(
                        context,
                        orderId: orderId,
                        orderData: data,
                      )
                    else if (restaurantRating > 0)
                      _buildSubmittedRatingCard(
                        context: context,
                        restaurantName: restaurantName,
                        restaurantRating: restaurantRating,
                        restaurantComment: restaurantComment,
                        courierRating: courierRating,
                        courierComment: courierComment,
                        courierName:
                            (data['driverName'] ?? 'المندوب').toString().trim(),
                      ),
                  ]),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, String label, String value,
          {bool bold = false, bool subtle = false, Color? valueColor}) =>
      Padding(
        padding: EdgeInsets.symmetric(vertical: subtle ? 2 : 4),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(
            label,
            style: TextStyle(
              fontSize: subtle ? 13 : 16,
              color: subtle
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: subtle ? 13 : 16,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: valueColor ??
                  (bold
                      ? AppColors.primaryColor
                      : Theme.of(context).colorScheme.onSurface),
            ),
          ),
        ]),
      );

  Widget _buildRatingActionCard(
    BuildContext context, {
    required String orderId,
    required Map<String, dynamic> orderData,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryColor.withValues(alpha: 0.12)),
        boxShadow: ClientColors.softCardShadow(
          opacity: 0.06,
          blur: 16,
          offset: const Offset(0, 6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '⭐ قيّم الطلب',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'يمكنك الآن تقييم المطعم والمندوب، وسيظهر تقييم المطعم لبقية العملاء.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                showOrderRatingSheet(
                  context,
                  orderId: orderId,
                  orderData: orderData,
                );
              },
              icon: const Icon(Icons.star_rate_rounded),
              label: const Text('تقييم الآن'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmittedRatingCard({
    required BuildContext context,
    required String restaurantName,
    required int restaurantRating,
    required String restaurantComment,
    required int courierRating,
    required String courierComment,
    required String courierName,
  }) {
    Widget ratingLine(String title, int value, String comment) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  )),
              const Spacer(),
              ...List.generate(
                5,
                (index) => Icon(
                  index < value
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: Colors.amber,
                  size: 18,
                ),
              ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              comment,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.28)),
        boxShadow: ClientColors.softCardShadow(
          opacity: 0.06,
          blur: 16,
          offset: const Offset(0, 6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '✅ تم إرسال تقييمك',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ratingLine(restaurantName.isEmpty ? 'المطعم' : restaurantName,
              restaurantRating, restaurantComment),
          if (courierRating > 0) ...[
            const SizedBox(height: 12),
            ratingLine(courierName.isEmpty ? 'المندوب' : courierName,
                courierRating, courierComment),
          ],
        ],
      ),
    );
  }
}
