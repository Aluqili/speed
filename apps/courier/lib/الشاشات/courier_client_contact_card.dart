import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';

import '../helpers/courier_runtime_helpers.dart';
import 'chat_screen.dart';

class CourierClientContactCard extends StatefulWidget {
  const CourierClientContactCard({
    super.key,
    required this.orderData,
    required this.driverId,
    this.compact = false,
  });

  final Map<String, dynamic> orderData;
  final String driverId;
  final bool compact;

  @override
  State<CourierClientContactCard> createState() =>
      _CourierClientContactCardState();
}

class _CourierClientContactCardState extends State<CourierClientContactCard> {
  String _clientName = '';
  String _clientPhone = '';
  bool _loadingClient = false;

  String get _clientId =>
      (widget.orderData['clientId'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _clientName = _resolveClientName(widget.orderData);
    _clientPhone = _resolveClientPhone(widget.orderData);
    if ((_clientName.isEmpty || _clientPhone.isEmpty) && _clientId.isNotEmpty) {
      _loadClientProfile();
    }
  }

  @override
  void didUpdateWidget(CourierClientContactCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderData != widget.orderData) {
      _clientName = _resolveClientName(widget.orderData);
      _clientPhone = _resolveClientPhone(widget.orderData);
      if ((_clientName.isEmpty || _clientPhone.isEmpty) &&
          _clientId.isNotEmpty) {
        _loadClientProfile();
      }
    }
  }

  String _firstText(Iterable<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  String _resolveClientName(Map<String, dynamic> data) {
    final client = data['client'];
    return _firstText([
      data['clientName'],
      data['customerName'],
      if (client is Map<String, dynamic>) client['name'],
      if (client is Map<String, dynamic>) client['fullName'],
    ]);
  }

  String _resolveClientPhone(Map<String, dynamic> data) {
    final client = data['client'];
    return _firstText([
      data['clientPhone'],
      data['clientPhoneNumber'],
      data['customerPhone'],
      data['customerPhoneNumber'],
      data['phone'],
      data['phoneNumber'],
      if (client is Map<String, dynamic>) client['phone'],
      if (client is Map<String, dynamic>) client['phoneNumber'],
    ]);
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _findClientDoc() async {
    final firestore = FirebaseFirestore.instance;
    final directDoc = await firestore.collection('clients').doc(_clientId).get();
    if (directDoc.exists) return directDoc;

    for (final field in const ['ownerUid', 'uid', 'userId']) {
      final query = await firestore
          .collection('clients')
          .where(field, isEqualTo: _clientId)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) return query.docs.first;
    }
    return null;
  }

  Future<void> _loadClientProfile() async {
    if (_loadingClient) return;
    setState(() => _loadingClient = true);
    try {
      final doc = await _findClientDoc();
      final data = doc?.data() ?? <String, dynamic>{};
      final name = _firstText([
        data['name'],
        data['fullName'],
        data['displayName'],
      ]);
      final phone = _firstText([
        data['phone'],
        data['phoneNumber'],
        data['mobile'],
      ]);
      if (!mounted) return;
      setState(() {
        if (_clientName.isEmpty && name.isNotEmpty) _clientName = name;
        if (_clientPhone.isEmpty && phone.isNotEmpty) _clientPhone = phone;
      });
    } catch (_) {
      // Keep order data fallback.
    } finally {
      if (mounted) setState(() => _loadingClient = false);
    }
  }

  String _generateChatId(String user1, String user2) {
    final ids = [user1, user2]..sort();
    return ids.join('_');
  }

  Future<void> _openChat() async {
    if (_clientId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن فتح الدردشة لعدم توفر معرف العميل')),
      );
      return;
    }

    final driverDoc = await FirebaseFirestore.instance
        .collection('drivers')
        .doc(widget.driverId)
        .get();
    final driverName = (driverDoc.data()?['name'] ??
            driverDoc.data()?['fullName'] ??
            'مندوب')
        .toString();

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          currentUserId: widget.driverId,
          otherUserId: _clientId,
          currentUserRole: 'driver',
          chatId: _generateChatId(widget.driverId, _clientId),
          currentUserName: driverName,
        ),
      ),
    );
  }

  Future<void> _copyPhone() async {
    final phone = _clientPhone.trim();
    if (phone.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: phone));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ رقم العميل')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = _clientName.isNotEmpty ? _clientName : 'العميل';
    final phone = _clientPhone.trim();
    final hasPhone = phone.isNotEmpty;

    return Container(
      padding: EdgeInsets.all(widget.compact ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor:
                    AppThemeArabic.courierPrimary.withValues(alpha: 0.12),
                child: const Icon(Icons.person_rounded,
                    color: AppThemeArabic.courierPrimary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppThemeArabic.courierTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hasPhone
                          ? normalizeCourierPhone(phone)
                          : (_loadingClient ? 'جاري جلب الرقم...' : 'رقم العميل غير متاح'),
                      style: const TextStyle(
                        color: AppThemeArabic.courierTextSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed:
                    hasPhone ? () => launchCourierPhoneCall(context, phone) : null,
                icon: const Icon(Icons.call_rounded, size: 18),
                label: const Text('اتصال'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppThemeArabic.courierAccent,
                  foregroundColor: Colors.white,
                ),
              ),
              OutlinedButton.icon(
                onPressed: _clientId.isEmpty ? null : _openChat,
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                label: const Text('دردشة'),
              ),
              OutlinedButton.icon(
                onPressed: hasPhone ? _copyPhone : null,
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('نسخ'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
