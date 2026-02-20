import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

import 'chat_screen.dart' show ChatScreen;
import 'courier_order_map_screen.dart';
import 'courier_order_actions.dart';

class CourierOrderDetailsScreen extends StatefulWidget {
  final String orderId;
  final String driverId;

  const CourierOrderDetailsScreen({
    Key? key,
    required this.orderId,
    required this.driverId,
  }) : super(key: key);

  @override
  State<CourierOrderDetailsScreen> createState() => _CourierOrderDetailsScreenState();
}

class _CourierOrderDetailsScreenState extends State<CourierOrderDetailsScreen> {
  File? _deliveryImage;
  bool _uploading = false;
  Map<String, dynamic>? orderData;
  double deliveryFee = 0;

  @override
  void initState() {
    super.initState();
    _loadOrderData();
  }

  Future<void> _loadOrderData() async {
    final docSnapshot = await FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .get();

    if (docSnapshot.exists) {
      final data = docSnapshot.data()!;
      if (data['assignedDriverId'] != null && data['assignedDriverId'] != widget.driverId) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم استلام هذا الطلب بواسطة مندوب آخر')),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      if (data['restaurantLat'] != null && data['restaurantLng'] != null &&
          data['clientLat'] != null && data['clientLng'] != null) {
        double distanceInKm = _calculateDistance(
          data['restaurantLat'], data['restaurantLng'],
          data['clientLat'], data['clientLng'],
        );
        deliveryFee = 700 + (distanceInKm * 100).roundToDouble();
      }

      setState(() {
        orderData = data;
      });
    }
  }

  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double R = 6371;
    double dLat = _deg2rad(lat2 - lat1);
    double dLon = _deg2rad(lng2 - lng1);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) => deg * (pi / 180);

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _deliveryImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImageToCloudinary(File imageFile) async {
    const cloudName = 'dvnzloec6';
    const uploadPreset = 'flutter_unsigned';

    final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    final response = await request.send();
    if (response.statusCode == 200) {
      final resStr = await response.stream.bytesToString();
      final resData = json.decode(resStr);
      return resData['secure_url'];
    } else {
      return null;
    }
  }

  Future<void> _confirmDelivery() async {
    if (_deliveryImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى التقاط صورة لإثبات التسليم')),
      );
      return;
    }

    setState(() => _uploading = true);

    final imageUrl = await _uploadImageToCloudinary(_deliveryImage!);

    if (imageUrl == null) {
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل رفع الصورة. حاول مرة أخرى.')),
      );
      return;
    }

    // تأكيد وجود deliveryFeeForDriver في الطلب
    final docSnapshot = await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).get();
    double? deliveryFeeForDriver = docSnapshot.data()?['deliveryFeeForDriver']?.toDouble();
    if (deliveryFeeForDriver == null || deliveryFeeForDriver == 0) {
      // إعادة حسابها إذا لم تكن موجودة
      if (orderData != null && orderData!['restaurantLat'] != null && orderData!['restaurantLng'] != null && orderData!['clientLat'] != null && orderData!['clientLng'] != null) {
        double distanceInKm = _calculateDistance(
          orderData!['restaurantLat'], orderData!['restaurantLng'],
          orderData!['clientLat'], orderData!['clientLng'],
        );
        deliveryFeeForDriver = 700 + (distanceInKm * 100).roundToDouble();
      } else {
        deliveryFeeForDriver = deliveryFee;
      }
    }
    await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).update({
      'status': 'تم التوصيل',
      'deliveryImage': imageUrl,
      'deliveredAt': Timestamp.now(),
      'deliveryFeeForDriver': deliveryFeeForDriver,
    });

    setState(() => _uploading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تأكيد التسليم بنجاح')),
    );
    Navigator.pop(context);
  }

  Future<void> _acceptOrder() async {
    if (orderData == null) return;

    await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).update({
      'assignedDriverId': widget.driverId,
      'status': 'بانتظار المطعم',
      'deliveryFeeForDriver': deliveryFee,
      'acceptedAt': Timestamp.now(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم قبول الطلب، بانتظار تجهيز المطعم')),
    );

    _loadOrderData();
  }

  String _generateChatId(String user1, String user2) {
    final ids = [user1, user2]..sort();
    return ids.join('_');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الطلب', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFE724C), fontFamily: 'Tajawal', fontSize: 20)),
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFFFE724C)),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
        ),
      ),
      backgroundColor: const Color(0xFFF5F5F5),
      body: orderData == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  // رقم الطلب بشكل موحد وبارز
                  Row(
                    children: [
                      const Text('رقم الطلب: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(
                        orderData!['orderNumber'] != null
                          ? '#${orderData!['orderNumber']}'
                          : '#${widget.orderId.substring(0,8)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange, fontSize: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('العميل: ${orderData!['clientName'] ?? "غير متوفر"}'),
                  Text('العنوان: ${orderData!['deliveryAddressName'] ?? "غير متوفر"}'),
                  Text('الحالة الحالية: ${orderData!['status'] ?? "غير متوفر"}'),
                  const SizedBox(height: 12),
                  Text('رسوم التوصيل الخاصة بك: $deliveryFee ج.س',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                  const SizedBox(height: 20),

                  // قسم إجراءات المندوب (اختياري) يوفر أزرار الانتقال والتسليم
                  CourierOrderActions(orderId: widget.orderId),

                  if (orderData?['assignedDriverId'] == null)
                    ElevatedButton.icon(
                      onPressed: _acceptOrder,
                      icon: const Icon(Icons.check),
                      label: const Text('قبول الطلب'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        minimumSize: const Size.fromHeight(48),
                      ),
                    )
                  else if (orderData?['assignedDriverId'] == widget.driverId)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('صورة إثبات التسليم:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        if (_deliveryImage != null)
                          Image.file(_deliveryImage!, height: 200)
                        else if (orderData?['deliveryImage'] != null)
                          Image.network(orderData!['deliveryImage'], height: 200)
                        else
                          const Text('لم يتم التقاط صورة بعد.'),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('التقاط صورة للتسليم'),
                        ),
                        const SizedBox(height: 16),
                        _uploading
                            ? const Center(child: CircularProgressIndicator())
                            : ElevatedButton.icon(
                                onPressed: _confirmDelivery,
                                icon: const Icon(Icons.check_circle),
                                label: const Text('تأكيد التسليم'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                              ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            if (orderData?['restaurantLat'] != null &&
                                orderData?['restaurantLng'] != null &&
                                orderData?['clientLat'] != null &&
                                orderData?['clientLng'] != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CourierOrderMapScreen(
                                    restaurantLat: orderData!['restaurantLat'],
                                    restaurantLng: orderData!['restaurantLng'],
                                    clientLat: orderData!['clientLat'],
                                    clientLng: orderData!['clientLng'],
                                  ),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('لا توجد بيانات موقع المطعم أو العميل')),
                              );
                            }
                          },
                          icon: const Icon(Icons.map),
                          label: const Text('عرض الخريطة'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                        ),
                      ],
                    )
                  else
                    const Center(child: Text('هذا الطلب تم استلامه بواسطة مندوب آخر.')),

                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final doc = await FirebaseFirestore.instance.collection('drivers').doc(widget.driverId).get();
                      final driverName = doc.data()?['name'] ?? 'مندوب';
                      final chatId = _generateChatId(widget.driverId, orderData!['clientId']);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            currentUserId: widget.driverId,
                            otherUserId: orderData!['clientId'],
                            currentUserRole: 'driver',
                            chatId: chatId,
                            currentUserName: driverName,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('الدردشة مع العميل'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
