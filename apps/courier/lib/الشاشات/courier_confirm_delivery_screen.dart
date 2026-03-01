import 'dart:io';
import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:get_storage/get_storage.dart'; // ✅ لإزالة الطلب من التخزين المحلي
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';
import 'package:speedstar_core/speedstar_core.dart'
    show formatUnifiedOrderCode, OrderStatusPalette;
import 'chat_screen.dart';

class CourierConfirmDeliveryScreen extends StatefulWidget {
  final String orderId;
  final String driverId;

  const CourierConfirmDeliveryScreen({
    Key? key,
    required this.orderId,
    required this.driverId,
  }) : super(key: key);

  @override
  State<CourierConfirmDeliveryScreen> createState() =>
      _CourierConfirmDeliveryScreenState();
}

class _CourierConfirmDeliveryScreenState
    extends State<CourierConfirmDeliveryScreen> {
  File? _proofImage;
  bool _uploading = false;
  Map<String, dynamic>? _orderData;

  final cloudinary = CloudinaryPublic('dvnzloec6', 'flutter_unsigned');

  @override
  void initState() {
    super.initState();
    final box = GetStorage();
    box.write('current_order', {
      'orderId': widget.orderId,
      'stage': 'arrived_to_client',
    });
    _loadOrderData();
  }

  Future<void> _loadOrderData() async {
    final doc = await FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .get();
    if (doc.exists) {
      final data = Map<String, dynamic>.from(doc.data()!);
      final clientId = (data['clientId'] ?? '').toString();
      final hasClientName =
          (data['clientName'] ?? '').toString().trim().isNotEmpty;
      final hasClientPhone =
          (data['clientPhone'] ?? '').toString().trim().isNotEmpty;

      if (clientId.isNotEmpty && (!hasClientName || !hasClientPhone)) {
        DocumentSnapshot<Map<String, dynamic>>? clientDoc;
        final directClientDoc = await FirebaseFirestore.instance
            .collection('clients')
            .doc(clientId)
            .get();
        if (directClientDoc.exists) {
          clientDoc = directClientDoc;
        } else {
          final byOwner = await FirebaseFirestore.instance
              .collection('clients')
              .where('ownerUid', isEqualTo: clientId)
              .limit(1)
              .get();
          if (byOwner.docs.isNotEmpty) {
            clientDoc = byOwner.docs.first;
          } else {
            final byUid = await FirebaseFirestore.instance
                .collection('clients')
                .where('uid', isEqualTo: clientId)
                .limit(1)
                .get();
            if (byUid.docs.isNotEmpty) {
              clientDoc = byUid.docs.first;
            } else {
              final byUserId = await FirebaseFirestore.instance
                  .collection('clients')
                  .where('userId', isEqualTo: clientId)
                  .limit(1)
                  .get();
              if (byUserId.docs.isNotEmpty) {
                clientDoc = byUserId.docs.first;
              }
            }
          }
        }

        if (clientDoc != null && clientDoc.exists) {
          final clientData = clientDoc.data() ?? <String, dynamic>{};
          final clientName =
              (clientData['name'] ?? clientData['fullName'] ?? '')
                  .toString()
                  .trim();
          if (clientName.isNotEmpty) {
            data['clientName'] = clientName;
          }
          if ((data['clientPhone'] ?? '').toString().trim().isEmpty) {
            final clientPhone =
                (clientData['phone'] ?? clientData['phoneNumber'] ?? '')
                    .toString()
                    .trim();
            if (clientPhone.isNotEmpty) {
              data['clientPhone'] = clientPhone;
            }
          }
        }
      }

      setState(() {
        _orderData = data;
      });
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.camera, imageQuality: 75);
    if (picked != null) {
      setState(() {
        _proofImage = File(picked.path);
      });
    }
  }

  Future<void> _uploadAndFinish() async {
    if (_proofImage == null) return;

    setState(() => _uploading = true);

    try {
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(_proofImage!.path,
            resourceType: CloudinaryResourceType.Image),
      );

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({
        'status': 'delivered',
        'orderStatus': 'delivered',
        'deliveredAt': Timestamp.now(),
        'proofImageUrl': response.secureUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ✅ إزالة الطلب من التخزين المحلي
      final box = GetStorage();
      box.remove('current_order');

      setState(() => _uploading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم رفع إثبات التسليم')),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل رفع الصورة: $e')),
      );
    }
  }

  String _normalizePhone(String phone) {
    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    const englishDigits = '0123456789';
    var normalized = phone;
    for (var index = 0; index < arabicDigits.length; index++) {
      normalized =
          normalized.replaceAll(arabicDigits[index], englishDigits[index]);
    }
    normalized = normalized.replaceAll(RegExp(r'[^0-9+]'), '');
    return normalized;
  }

  String _resolveClientPhone(Map<String, dynamic>? orderData) {
    final data = orderData ?? <String, dynamic>{};
    final candidates = [
      data['clientPhone'],
      data['clientPhoneNumber'],
      data['phone'],
      data['phoneNumber'],
      (data['client'] is Map<String, dynamic>)
          ? (data['client'] as Map<String, dynamic>)['phone']
          : null,
      (data['client'] is Map<String, dynamic>)
          ? (data['client'] as Map<String, dynamic>)['phoneNumber']
          : null,
    ];

    for (final candidate in candidates) {
      final value = (candidate ?? '').toString().trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  Future<void> _callClient(String rawPhone) async {
    final phone = _normalizePhone(rawPhone);
    if (phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('رقم هاتف العميل غير متوفر أو غير صالح')),
      );
      return;
    }

    final phoneUri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri, mode: LaunchMode.externalApplication);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('❌ لا يمكن فتح الاتصال')),
    );
  }

  String _generateChatId(String user1, String user2) {
    final sorted = [user1, user2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetails(Map<String, dynamic> orderData) {
    final items = (orderData['items'] as List?) ?? const [];
    final paymentMethod = (orderData['paymentMethod'] ?? 'غير محدد').toString();
    final status =
        (orderData['orderStatus'] ?? orderData['status'] ?? 'غير محدد')
            .toString();
    final totalWithDelivery =
        (orderData['totalWithDelivery'] ?? orderData['total'] ?? 0).toString();

    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        title: const Text(
          'تفاصيل الطلب',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        collapsedTextColor: Colors.black87,
        textColor: Colors.black87,
        iconColor: Colors.black87,
        collapsedIconColor: Colors.black87,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _detailRow(
            'رقم الطلب',
            formatUnifiedOrderCode(
              orderNumber: orderData['orderNumber'],
              orderId: orderData['orderId'],
              docId: widget.orderId,
            ),
          ),
          _detailRow(
              'العميل', (orderData['clientName'] ?? 'غير معروف').toString()),
          _detailRow('المطعم',
              (orderData['restaurantName'] ?? 'غير معروف').toString()),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: OrderStatusPalette.backgroundForStatus(status),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'الحالة: ${OrderStatusPalette.displayText(status)}',
                style: TextStyle(
                  color: OrderStatusPalette.colorForStatus(status),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          _detailRow('طريقة الدفع', paymentMethod),
          _detailRow('الإجمالي', '$totalWithDelivery ج.س'),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'العناصر',
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ),
          const SizedBox(height: 6),
          if (items.isEmpty)
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'لا توجد عناصر',
                style: TextStyle(color: Colors.black87),
              ),
            )
          else
            ...items.map((item) {
              final map = (item is Map<String, dynamic>)
                  ? item
                  : Map<String, dynamic>.from(item as Map);
              final name = (map['name'] ?? 'عنصر').toString();
              final qty = (map['quantity'] ?? 1).toString();
              return Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '• $name × $qty',
                  style: const TextStyle(color: Colors.black87),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildJourneyHeader() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppThemeArabic.clientPrimary.withOpacity(0.12),
            child: const Icon(Icons.verified_outlined,
                color: AppThemeArabic.clientPrimary),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'المرحلة 3 من 3 · تأكيد التسليم',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'التقط صورة واضحة كإثبات ثم أنهِ الطلب.',
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = (_orderData?['totalWithDelivery'] ?? 0).toDouble();
    final paymentStatus = (_orderData?['paymentStatus'] ?? '').toString();
    final isPaid = _orderData?['paid'] == true || paymentStatus == 'paid';
    final clientName = _orderData?['clientName'] ?? 'غير معروف';
    final clientPhone = _resolveClientPhone(_orderData);
    final clientId = (_orderData?['clientId'] ?? '').toString();

    return Scaffold(
      backgroundColor: AppThemeArabic.clientBackground,
      appBar: AppBar(
        title: const Text('إثبات التسليم',
            style: TextStyle(
                color: AppThemeArabic.clientPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 20,
                fontFamily: 'Tajawal')),
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppThemeArabic.clientPrimary),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
        ),
      ),
      body: _orderData == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildJourneyHeader(),
                const SizedBox(height: 12),
                _buildOrderDetails(_orderData!),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('👤 معلومات العميل:',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Row(children: [
                        const Icon(Icons.person,
                            color: AppThemeArabic.clientPrimary),
                        const SizedBox(width: 8),
                        Text(
                          clientName,
                          style: const TextStyle(
                              fontSize: 16, color: Colors.black87),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        const Icon(Icons.phone_android,
                            color: AppThemeArabic.clientPrimary),
                        const SizedBox(width: 8),
                        Text(
                          clientPhone.isEmpty ? 'غير متاح' : clientPhone,
                          style: const TextStyle(
                              fontSize: 16, color: Colors.black87),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GFButton(
                            onPressed: () async {
                              if (clientId.isEmpty) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'لا يمكن فتح الدردشة لعدم توفر معرف العميل')),
                                );
                                return;
                              }
                              final doc = await FirebaseFirestore.instance
                                  .collection('drivers')
                                  .doc(widget.driverId)
                                  .get();
                              final driverName = doc.data()?['name'] ?? 'مندوب';
                              if (!mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    currentUserId: widget.driverId,
                                    otherUserId: clientId,
                                    currentUserRole: 'driver',
                                    chatId: _generateChatId(
                                        widget.driverId, clientId),
                                    currentUserName: driverName,
                                  ),
                                ),
                              );
                            },
                            text: 'دردشة',
                            icon: const Icon(Icons.chat, size: 18),
                            size: GFSize.SMALL,
                            color: AppThemeArabic.clientPrimary,
                            shape: GFButtonShape.pills,
                          ),
                          GFButton(
                            onPressed: () => _callClient(clientPhone),
                            text: 'اتصال',
                            icon: const Icon(Icons.call, size: 18),
                            size: GFSize.SMALL,
                            color: AppThemeArabic.clientSuccess,
                            shape: GFButtonShape.pills,
                          ),
                        ],
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isPaid ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isPaid
                        ? '✅ حالة الدفع: تم الدفع مسبقًا'
                        : '❗ حالة الدفع: لم يتم الدفع بعد — يجب تحصيل $total ج.س',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color:
                          isPaid ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📸 إثبات التسليم',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _proofImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(_proofImage!),
                            )
                          : const Text(
                              'لم يتم اختيار صورة بعد',
                              style: TextStyle(color: Colors.black87),
                            ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GFButton(
                        onPressed: _pickImage,
                        text: 'اختيار الصورة',
                        icon: const Icon(Icons.camera_alt),
                        color: AppThemeArabic.clientPrimary,
                        fullWidthButton: true,
                        shape: GFButtonShape.pills,
                        size: GFSize.LARGE,
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GFButton(
                        onPressed: _uploading ? null : _uploadAndFinish,
                        text: _uploading ? 'جاري الرفع...' : 'إنهاء الطلب',
                        icon: const Icon(Icons.done),
                        color: AppThemeArabic.clientSuccess,
                        fullWidthButton: true,
                        shape: GFButtonShape.pills,
                        size: GFSize.LARGE,
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
