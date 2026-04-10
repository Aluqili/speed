import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:getwidget/getwidget.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';
import 'package:speedstar_core/speedstar_core.dart'
    show formatUnifiedOrderCode, OrderStatusPalette;

import 'client_track_driver_screen.dart';
import 'chat_screen.dart';
import 'payment_screen.dart';

class AppColors {
  static const Color primaryColor = AppThemeArabic.clientPrimary;
  static const Color backgroundColor = AppThemeArabic.clientBackground;
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
  const ClientOrderDetailsScreen({Key? key, required this.orderId})
      : super(key: key);

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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          centerTitle: true,
          title: const Text('تفاصيل الطلب',
              style: TextStyle(
                  color: AppColors.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  fontFamily: 'Tajawal')),
          iconTheme: const IconThemeData(color: AppColors.primaryColor),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
          ),
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
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getPaymentStatusText(paymentStatus),
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
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
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'تواصل مع $driverName',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
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
                    Text('🧾 معلومات الطلب',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
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
                                const Text('رقم الطلب:',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
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
                                const Text('المطعم:',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    restaurantName.isEmpty
                                        ? 'غير معروف'
                                        : restaurantName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
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
                                    style: const TextStyle(
                                        fontSize: 15,
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    last4,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      color: Colors.black,
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
                    _buildRow('تاريخ الطلب',
                        _formatDate(data['createdAt']) ?? 'غير متاح'),
                    const Divider(height: 32),
                    Text('💰 تفاصيل الفاتورة',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _buildRow(
                        'قيمة الأصناف', '${total.toStringAsFixed(2)} ج.س'),
                    _buildRow(
                        'رسوم التوصيل',
                        delivery == 0
                            ? 'مجانًا'
                            : '${delivery.toStringAsFixed(2)} ج.س'),
                    if (largeOrderFee > 0)
                      _buildRow('رسوم الطلبات الكبيرة',
                          '${largeOrderFee.toStringAsFixed(2)} ج.س'),
                    _buildRow('الإجمالي الكلي',
                        '${totalWithDelivery.toStringAsFixed(2)} ج.س',
                        bold: true),
                    const Divider(height: 32),

                    // رقم الطلب بشكل بارز أسفل معلومات الطلب
                    Row(
                      children: [
                        const Text('رقم الطلب: ',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
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
                    Text('🍽️ الأصناف المطلوبة',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
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
                    Text('🔁 تقدم الطلب',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
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
                            color: color.withOpacity(0.1),
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
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '🛵 خيارات المندوب: $driverName',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (driverPhone.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'رقم المندوب: $driverPhone',
                                    style:
                                        const TextStyle(color: Colors.black54),
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
                  ]),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: bold ? AppColors.primaryColor : Colors.black87,
            ),
          ),
        ]),
      );
}
