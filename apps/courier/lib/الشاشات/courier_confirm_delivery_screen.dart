import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:getwidget/getwidget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:get_storage/get_storage.dart'; // ✅ لإزالة الطلب من التخزين المحلي
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
  State<CourierConfirmDeliveryScreen> createState() => _CourierConfirmDeliveryScreenState();
}

class _CourierConfirmDeliveryScreenState extends State<CourierConfirmDeliveryScreen> {
  File? _proofImage;
  bool _uploading = false;
  Map<String, dynamic>? _orderData;

  final cloudinary = CloudinaryPublic('dvnzloec6', 'flutter_unsigned');

  @override
  void initState() {
    super.initState();
    _loadOrderData();
  }

  Future<void> _loadOrderData() async {
    final doc = await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).get();
    if (doc.exists) {
      setState(() {
        _orderData = doc.data();
      });
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 75);
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
        CloudinaryFile.fromFile(_proofImage!.path, resourceType: CloudinaryResourceType.Image),
      );

      await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).update({
        'status': 'تم التوصيل',
        'deliveredAt': Timestamp.now(),
        'proofImageUrl': response.secureUrl,
      });

      // ✅ إزالة الطلب من التخزين المحلي
      final box = GetStorage();
      box.remove('currentOrderId');

      setState(() => _uploading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم رفع إثبات التسليم')),
        );
        Get.offAllNamed('/driverHome');
      }
    } catch (e) {
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل رفع الصورة: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = (_orderData?['totalWithDelivery'] ?? 0).toDouble();
    final isPaid = _orderData?['paid'] == true;
    final clientName = _orderData?['clientName'] ?? 'غير معروف';
    final clientPhone = _orderData?['clientPhone'] ?? 'غير متاح';
    final clientId = _orderData?['clientId'];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('إثبات التسليم', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _orderData == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('👤 معلومات العميل:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Row(children: [
                        const Icon(Icons.person, color: Color(0xFFF57C00)),
                        const SizedBox(width: 8),
                        Text(clientName, style: const TextStyle(fontSize: 16)),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        const Icon(Icons.phone_android, color: Color(0xFFF57C00)),
                        const SizedBox(width: 8),
                        Text(clientPhone, style: const TextStyle(fontSize: 16)),
                      ]),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GFButton(
                            onPressed: () async {
                              final doc = await FirebaseFirestore.instance.collection('drivers').doc(widget.driverId).get();
                              final driverName = doc.data()?['name'] ?? 'مندوب';
                              Get.to(() => ChatScreen(
                                currentUserId: widget.driverId,
                                otherUserId: clientId,
                                currentUserRole: 'driver',
                                chatId: widget.orderId,
                                currentUserName: driverName,
                              ));
                            },
                            text: 'دردشة',
                            icon: const Icon(Icons.chat, size: 18),
                            size: GFSize.SMALL,
                            color: const Color(0xFFF57C00),
                            shape: GFButtonShape.pills,
                          ),
                          GFButton(
                            onPressed: () async {
                              final Uri phoneUri = Uri.parse("tel:$clientPhone");
                              if (await canLaunchUrl(phoneUri)) {
                                await launchUrl(phoneUri);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('❌ لا يمكن فتح الاتصال')),
                                );
                              }
                            },
                            text: 'اتصال',
                            icon: const Icon(Icons.call, size: 18),
                            size: GFSize.SMALL,
                            color: GFColors.SUCCESS,
                            shape: GFButtonShape.pills,
                          ),
                        ],
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text('💵 حالة الدفع:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  isPaid ? '✅ تم الدفع مسبقًا' : '❗ لم يتم الدفع بعد — يجب تحصيل $total ج.س',
                  style: TextStyle(fontSize: 16, color: isPaid ? Colors.green : Colors.redAccent),
                ),
                const SizedBox(height: 24),
                const Text('📸 إثبات التسليم:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _proofImage != null
                    ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(_proofImage!))
                    : const Text('لم يتم اختيار صورة بعد'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GFButton(
                        onPressed: _pickImage,
                        text: 'اختيار الصورة',
                        icon: const Icon(Icons.camera_alt),
                        color: const Color(0xFFF57C00),
                        fullWidthButton: true,
                        shape: GFButtonShape.pills,
                        size: GFSize.LARGE,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GFButton(
                        onPressed: _uploading ? null : _uploadAndFinish,
                        text: _uploading ? 'جاري الرفع...' : 'إنهاء الطلب',
                        icon: const Icon(Icons.done),
                        color: GFColors.SUCCESS,
                        fullWidthButton: true,
                        shape: GFButtonShape.pills,
                        size: GFSize.LARGE,
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
