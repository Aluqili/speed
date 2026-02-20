import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:getwidget/getwidget.dart';

// import 'client_track_driver_screen.dart';
// import 'client_order_tracking_screen.dart';
// import 'chat_screen.dart';
import 'payment_screen.dart';

class AppColors {
  static const Color primaryColor = Color(0xFFFE724C);
  static const Color backgroundColor = Color(0xFFF5F5F5);
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
  final String orderId;
  const ClientOrderDetailsScreen({Key? key, required this.orderId}) : super(key: key);

  String _getPaymentStatusText(String paymentStatus) {
    switch (paymentStatus) {
      case 'انتظار الدفع':
        return '🔔 بانتظار رفع إيصال الدفع';
      case 'قيد المراجعة':
        return '🔔 بانتظار موافقة الأدمن';
      case 'مرفوض':
      case 'رفض الدفع':
        return '❌ تم رفض الدفع';
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
             '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final orderRef = FirebaseFirestore.instance.collection('orders').doc(orderId);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          centerTitle: true,
          title: const Text('تفاصيل الطلب', style: TextStyle(color: AppColors.primaryColor, fontWeight: FontWeight.bold, fontSize: 20, fontFamily: 'Tajawal')),
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
            final totalWithDelivery = (data['totalWithDelivery'] as num?)?.toDouble() ?? (total + delivery);
            final paymentStatus = (data['paymentStatus'] as String?)?.trim() ?? '';
            final orderStatus   = (data['orderStatus']   as String?)?.trim() ?? '';

            int currentStep = _allSteps.indexOf(orderStatus);
            if (currentStep < 0) currentStep = 0;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // بطاقة حالة الدفع
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      _getPaymentStatusText(paymentStatus),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _getPaymentProgress(paymentStatus),
                        backgroundColor: Colors.grey[300],
                        valueColor: const AlwaysStoppedAnimation(AppColors.primaryColor),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (paymentStatus == 'انتظار الدفع')
                      GFButton(
                        onPressed: () {
                          Get.to(() => PaymentScreen(orderId: orderId));
                        },
                        text: 'رفع إيصال الدفع',
                        color: GFColors.WARNING,
                        fullWidthButton: true,
                      ),
                  ]),
                ),

                const SizedBox(height: 24),

                // معلومات الطلب والفاتورة
                Text('🧾 معلومات الطلب',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                // عرض رقم الطلب الموحّد إذا وجد، وإلا جزء من doc.id
                // عرض رقم الطلب مع آخر 4 أرقام بشكل بارز
                Builder(
                  builder: (_) {
                    String orderNumber = data['orderNumber']?.toString() ?? orderId.substring(0,8);
                    String last4 = orderNumber.length >= 4 ? orderNumber.substring(orderNumber.length - 4) : orderNumber;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('رقم الطلب:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(width: 8),
                            Text(
                              '#$orderNumber',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryColor,
                                fontSize: 22,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
                          child: Row(
                            children: [
                              const Icon(Icons.confirmation_number, color: AppColors.primaryColor, size: 20),
                              const SizedBox(width: 6),
                              Text(
                                'آخر 4 أرقام: ',
                                style: const TextStyle(fontSize: 15, color: Colors.grey, fontWeight: FontWeight.bold),
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
                _buildRow('تاريخ الطلب', _formatDate(data['createdAt']) ?? 'غير متاح'),
                const Divider(height: 32),
                Text('💰 تفاصيل الفاتورة',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildRow('قيمة الأصناف', '${total.toStringAsFixed(2)} ج.س'),
                _buildRow('رسوم التوصيل', delivery == 0 ? 'مجانًا' : '${delivery.toStringAsFixed(2)} ج.س'),
                _buildRow('الإجمالي الكلي', '${totalWithDelivery.toStringAsFixed(2)} ج.س', bold: true),
                const Divider(height: 32),

                // رقم الطلب بشكل بارز أسفل معلومات الطلب
                Row(
                  children: [
                    const Text('رقم الطلب: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(
                      data['orderNumber'] != null
                        ? '#${data['orderNumber']}'
                        : '#${orderId.substring(0,8)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryColor, fontSize: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // الأصناف
                Text('🍽️ الأصناف المطلوبة',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...items.map((item) => Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    leading: const Icon(Icons.restaurant_menu, color: AppColors.primaryColor),
                    title: Text(item['name'] ?? 'اسم غير متاح'),
                    subtitle: Text('الكمية: ${item['quantity']} | السعر: ${item['price']} ج.س'),
                  ),
              )),

                const SizedBox(height: 24),

                // شريط تقدم الطلب الكامل
                Text('🔁 تقدم الطلب',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Column(
                  children: List.generate(_allSteps.length, (i) {
                    final label = _allSteps[i];
                    final done = i < currentStep;
                    final active = i == currentStep;
                    final color = done
                        ? Colors.green
                        : active
                            ? AppColors.primaryColor
                            : Colors.grey;
                    final icon = done
                        ? Icons.check_circle
                        : active
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked;
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                                  color: color)),
                        ],
                      ),
                    );
                  }),
                ),

              ]),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: bold ? AppColors.primaryColor : Colors.black87,
            ),
          ),
        ]),
      );
}
