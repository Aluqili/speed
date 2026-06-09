import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:getwidget/getwidget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:get_storage/get_storage.dart'; // âœ… Ù„Ø¥Ø²Ø§Ù„Ø© Ø§Ù„Ø·Ù„Ø¨ Ù…Ù† Ø§Ù„ØªØ®Ø²ÙŠÙ† Ø§Ù„Ù…Ø­Ù„ÙŠ
import 'package:speedstar_core/Ø§Ù„Ø«ÙŠÙ…/Ø«ÙŠÙ…_Ø§Ù„ØªØ·Ø¨ÙŠÙ‚.dart';
import 'package:speedstar_core/speedstar_core.dart'
    show formatUnifiedOrderCode, OrderStatusPalette;
import '../helpers/courier_runtime_helpers.dart';
import 'chat_screen.dart';
import 'courier_ui.dart';

class CourierConfirmDeliveryScreen extends StatefulWidget {
  final String orderId;
  final String driverId;

  const CourierConfirmDeliveryScreen({
    super.key,
    required this.orderId,
    required this.driverId,
  });

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
    if (_proofImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ø§Ù„ØªÙ‚Ø· ØµÙˆØ±Ø© Ø¥Ø«Ø¨Ø§Øª Ø§Ù„ØªØ³Ù„ÙŠÙ… Ø£ÙˆÙ„Ø§Ù‹')),
      );
      return;
    }
    if (_uploading) return;

    setState(() => _uploading = true);

    try {
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(_proofImage!.path,
            resourceType: CloudinaryResourceType.Image),
      );

      await FirebaseFunctions.instanceFor(region: 'me-central1')
          .httpsCallable('courierUpdateOrderStage')
          .call({
        'orderId': widget.orderId,
        'driverId': widget.driverId,
        'stage': 'delivered',
        'proofImageUrl': response.secureUrl,
      });

      // âœ… Ø¥Ø²Ø§Ù„Ø© Ø§Ù„Ø·Ù„Ø¨ Ù…Ù† Ø§Ù„ØªØ®Ø²ÙŠÙ† Ø§Ù„Ù…Ø­Ù„ÙŠ
      final box = GetStorage();
      box.remove('current_order');

      setState(() => _uploading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('âœ… ØªÙ… Ø±ÙØ¹ Ø¥Ø«Ø¨Ø§Øª Ø§Ù„ØªØ³Ù„ÙŠÙ…')),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ÙØ´Ù„ Ø¥Ù†Ù‡Ø§Ø¡ Ø§Ù„Ø·Ù„Ø¨: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
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
    await launchCourierPhoneCall(context, rawPhone);
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
    final paymentMethod = (orderData['paymentMethod'] ?? 'ØºÙŠØ± Ù…Ø­Ø¯Ø¯').toString();
    final status =
        (orderData['orderStatus'] ?? orderData['status'] ?? 'ØºÙŠØ± Ù…Ø­Ø¯Ø¯')
            .toString();
    final totalWithDelivery =
        (orderData['totalWithDelivery'] ?? orderData['total'] ?? 0).toString();
    final driverFee = courierToDouble(
      orderData['deliveryFeeForDriver'] ?? orderData['deliveryFee'],
    );

    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        title: const Text(
          'ØªÙØ§ØµÙŠÙ„ Ø§Ù„Ø·Ù„Ø¨',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        collapsedTextColor: Colors.black87,
        textColor: Colors.black87,
        iconColor: Colors.black87,
        collapsedIconColor: Colors.black87,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _detailRow(
            'Ø±Ù‚Ù… Ø§Ù„Ø·Ù„Ø¨',
            formatUnifiedOrderCode(
              orderNumber: orderData['orderNumber'],
              orderId: orderData['orderId'],
              docId: widget.orderId,
            ),
          ),
          _detailRow(
              'Ø§Ù„Ø¹Ù…ÙŠÙ„', (orderData['clientName'] ?? 'ØºÙŠØ± Ù…Ø¹Ø±ÙˆÙ').toString()),
          _detailRow('Ø§Ù„Ù…Ø·Ø¹Ù…',
              (orderData['restaurantName'] ?? 'ØºÙŠØ± Ù…Ø¹Ø±ÙˆÙ').toString()),
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
                'Ø§Ù„Ø­Ø§Ù„Ø©: ${OrderStatusPalette.displayText(status)}',
                style: TextStyle(
                  color: OrderStatusPalette.colorForStatus(status),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          _detailRow('Ø·Ø±ÙŠÙ‚Ø© Ø§Ù„Ø¯ÙØ¹', paymentMethod),
          _detailRow('Ø§Ù„Ø¥Ø¬Ù…Ø§Ù„ÙŠ', '$totalWithDelivery Ø¬.Ø³'),
          if (driverFee > 0)
            _detailRow('Ø±Ø³ÙˆÙ… Ø§Ù„ØªÙˆØµÙŠÙ„', '${courierFormatMoney(driverFee)} Ø¬.Ø³'),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Ø§Ù„Ø¹Ù†Ø§ØµØ±',
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ),
          const SizedBox(height: 6),
          if (items.isEmpty)
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Ù„Ø§ ØªÙˆØ¬Ø¯ Ø¹Ù†Ø§ØµØ±',
                style: TextStyle(color: Colors.black87),
              ),
            )
          else
            ...items.map((item) {
              final map = (item is Map<String, dynamic>)
                  ? item
                  : Map<String, dynamic>.from(item as Map);
              final name = (map['name'] ?? 'Ø¹Ù†ØµØ±').toString();
              final qty = (map['quantity'] ?? 1).toString();
              return Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'â€¢ $name Ã— $qty',
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
            backgroundColor:
                AppThemeArabic.courierPrimary.withValues(alpha: 0.12),
            child: const Icon(Icons.verified_outlined,
                color: AppThemeArabic.courierPrimary),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ø§Ù„Ù…Ø±Ø­Ù„Ø© 3 Ù…Ù† 3 Â· ØªØ£ÙƒÙŠØ¯ Ø§Ù„ØªØ³Ù„ÙŠÙ…',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Ø§Ù„ØªÙ‚Ø· ØµÙˆØ±Ø© ÙˆØ§Ø¶Ø­Ø© ÙƒØ¥Ø«Ø¨Ø§Øª Ø«Ù… Ø£Ù†Ù‡Ù Ø§Ù„Ø·Ù„Ø¨.',
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
    final clientName = _orderData?['clientName'] ?? 'ØºÙŠØ± Ù…Ø¹Ø±ÙˆÙ';
    final clientPhone = _resolveClientPhone(_orderData);
    final clientId = (_orderData?['clientId'] ?? '').toString();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: buildCourierAppBar('إثبات التسليم'),
      body: CourierPageBackground(
        child: _orderData == null
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
                      const Text('ðŸ‘¤ Ù…Ø¹Ù„ÙˆÙ…Ø§Øª Ø§Ù„Ø¹Ù…ÙŠÙ„:',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Row(children: [
                        const Icon(Icons.person,
                            color: AppThemeArabic.courierPrimary),
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
                            color: AppThemeArabic.courierPrimary),
                        const SizedBox(width: 8),
                        Text(
                          clientPhone.isEmpty ? 'ØºÙŠØ± Ù…ØªØ§Ø­' : clientPhone,
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
                                          'Ù„Ø§ ÙŠÙ…ÙƒÙ† ÙØªØ­ Ø§Ù„Ø¯Ø±Ø¯Ø´Ø© Ù„Ø¹Ø¯Ù… ØªÙˆÙØ± Ù…Ø¹Ø±Ù Ø§Ù„Ø¹Ù…ÙŠÙ„')),
                                );
                                return;
                              }
                              final doc = await FirebaseFirestore.instance
                                  .collection('drivers')
                                  .doc(widget.driverId)
                                  .get();
                              final driverName = doc.data()?['name'] ?? 'Ù…Ù†Ø¯ÙˆØ¨';
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
                            text: 'Ø¯Ø±Ø¯Ø´Ø©',
                            icon: const Icon(Icons.chat, size: 18),
                            size: GFSize.SMALL,
                            color: AppThemeArabic.courierPrimary,
                            shape: GFButtonShape.pills,
                          ),
                          GFButton(
                            onPressed: () => _callClient(clientPhone),
                            text: 'Ø§ØªØµØ§Ù„',
                            icon: const Icon(Icons.call, size: 18),
                            size: GFSize.SMALL,
                            color: AppThemeArabic.clientSuccess,
                            shape: GFButtonShape.pills,
                          ),
                          GFButton(
                            onPressed: clientPhone.isEmpty
                                ? null
                                : () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: clientPhone),
                                    );
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('ØªÙ… Ù†Ø³Ø® Ø±Ù‚Ù… Ø§Ù„Ø¹Ù…ÙŠÙ„')),
                                    );
                                  },
                            text: 'Ù†Ø³Ø®',
                            icon: const Icon(Icons.copy, size: 18),
                            size: GFSize.SMALL,
                            color: AppThemeArabic.courierAccent,
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
                        ? 'âœ… Ø­Ø§Ù„Ø© Ø§Ù„Ø¯ÙØ¹: ØªÙ… Ø§Ù„Ø¯ÙØ¹ Ù…Ø³Ø¨Ù‚Ù‹Ø§'
                        : 'â— Ø­Ø§Ù„Ø© Ø§Ù„Ø¯ÙØ¹: Ù„Ù… ÙŠØªÙ… Ø§Ù„Ø¯ÙØ¹ Ø¨Ø¹Ø¯ â€” ÙŠØ¬Ø¨ ØªØ­ØµÙŠÙ„ $total Ø¬.Ø³',
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
                        'ðŸ“¸ Ø¥Ø«Ø¨Ø§Øª Ø§Ù„ØªØ³Ù„ÙŠÙ…',
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
                              'Ù„Ù… ÙŠØªÙ… Ø§Ø®ØªÙŠØ§Ø± ØµÙˆØ±Ø© Ø¨Ø¹Ø¯',
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
                        onPressed: _uploading ? null : _pickImage,
                        text: 'Ø§Ø®ØªÙŠØ§Ø± Ø§Ù„ØµÙˆØ±Ø©',
                        icon: const Icon(Icons.camera_alt),
                        color: AppThemeArabic.courierPrimary,
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
                        text: _uploading ? 'Ø¬Ø§Ø±ÙŠ Ø§Ù„Ø±ÙØ¹...' : 'Ø¥Ù†Ù‡Ø§Ø¡ Ø§Ù„Ø·Ù„Ø¨',
                        icon: const Icon(Icons.done),
                        color: AppThemeArabic.courierAccent,
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
        ),
    );
  }
}

