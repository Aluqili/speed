import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter/gestures.dart'
    show EagerGestureRecognizer, OneSequenceGestureRecognizer;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import 'store_order_details_screen.dart';

class StoreRequestCourierScreen extends StatefulWidget {
  final String restaurantId;

  const StoreRequestCourierScreen({super.key, required this.restaurantId});

  @override
  State<StoreRequestCourierScreen> createState() =>
      _StoreRequestCourierScreenState();
}

class _StoreRequestCourierScreenState extends State<StoreRequestCourierScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappPhoneController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _mapUrlController = TextEditingController();
  GoogleMapController? _mapController;
  LatLng? _destination;
  Map<String, dynamic>? _preview;
  bool _loadingPreview = false;
  bool _submitting = false;
  bool _resolvingMapUrl = false;
  Timer? _mapUrlDebounce;

  HttpsCallable _callable(String name) =>
      FirebaseFunctions.instanceFor(region: 'me-central1').httpsCallable(name);

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _whatsappPhoneController.dispose();
    _descriptionController.dispose();
    _mapUrlController.dispose();
    _mapUrlDebounce?.cancel();
    super.dispose();
  }

  LatLng? _parseGoogleMapsCoordinates(String value) {
    final decodedValue = Uri.decodeFull(value)
        .replaceAll('+', ' ')
        .replaceAll('\\u0026', '&')
        .replaceAll('\\x26', '&');
    final patterns = [
      RegExp(
          r'(?:[?&](?:q|query|ll|destination|center|origin)=|@)(-?\d{1,2}(?:\.\d+)?)[, ]+(-?\d{1,3}(?:\.\d+)?)',
          caseSensitive: false),
      RegExp(r'!3d(-?\d{1,2}(?:\.\d+)?)!4d(-?\d{1,3}(?:\.\d+)?)',
          caseSensitive: false),
      RegExp(
          r'/maps/(?:place|search)/(-?\d{1,2}(?:\.\d+)?),(-?\d{1,3}(?:\.\d+)?)',
          caseSensitive: false),
      RegExp(r'/place/(-?\d{1,2}(?:\.\d+)?),(-?\d{1,3}(?:\.\d+)?)',
          caseSensitive: false),
      RegExp(
          r'(?:destination|location|latlng|coordinates)[=:/](-?\d{1,2}(?:\.\d+)?)[,;%20 ]+(-?\d{1,3}(?:\.\d+)?)',
          caseSensitive: false),
      RegExp(
          r'/(?:place|search|dir)/(?:[^/]+/)?(-?\d{1,2}(?:\.\d+)?),(-?\d{1,3}(?:\.\d+)?)',
          caseSensitive: false),
      RegExp(r'^\s*(-?\d{1,2}(?:\.\d+)?)[, ]+(-?\d{1,3}(?:\.\d+)?)\s*$'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(decodedValue);
      if (match == null) continue;
      final lat = double.tryParse(match.group(1)!);
      final lng = double.tryParse(match.group(2)!);
      if (lat != null && lng != null && lat.abs() <= 90 && lng.abs() <= 180) {
        return LatLng(lat, lng);
      }
    }
    return null;
  }

  bool _isGoogleMapsUrl(Uri uri) {
    final host = uri.host.toLowerCase();
    return host == 'maps.app.goo.gl' ||
        host == 'goo.gl' ||
        host == 'google.com' ||
        host == 'google.co.uk' ||
        host.startsWith('google.') ||
        host.contains('.google.') ||
        host.endsWith('.google.com') ||
        host.endsWith('.google.co.uk');
  }

  Future<LatLng?> _resolveGoogleMapsFallback(String value) async {
    try {
      final result = await _callable('resolveGoogleMapsLocation').call({
        'mapUrl': value,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      final lat = (data['lat'] as num?)?.toDouble();
      final lng = (data['lng'] as num?)?.toDouble();
      if (lat == null || lng == null || lat.abs() > 90 || lng.abs() > 180) {
        return null;
      }
      return LatLng(lat, lng);
    } on FirebaseFunctionsException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<LatLng?> _coordinatesFromMapInput(String value) async {
    final directCoordinates = _parseGoogleMapsCoordinates(value);
    if (directCoordinates != null) return directCoordinates;

    final uri = Uri.tryParse(value);
    if (uri == null || !_isGoogleMapsUrl(uri)) return null;
    const headers = {
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36',
      'Accept-Language': 'ar,en-US;q=0.9,en;q=0.8',
    };
    try {
      final client = http.Client();
      try {
        Uri currentUri = uri;
        for (var redirectCount = 0; redirectCount < 5; redirectCount++) {
          final request = http.Request('GET', currentUri)
            ..followRedirects = false
            ..headers.addAll(headers);
          final streamedResponse =
              await client.send(request).timeout(const Duration(seconds: 12));
          final redirectTarget = streamedResponse.headers['location'];
          final currentPoint =
              _parseGoogleMapsCoordinates(currentUri.toString());
          if (currentPoint != null) return currentPoint;
          if (redirectTarget == null ||
              streamedResponse.statusCode < 300 ||
              streamedResponse.statusCode >= 400) {
            final body = await streamedResponse.stream.bytesToString();
            final point = _parseGoogleMapsCoordinates(currentUri.toString()) ??
                _parseGoogleMapsCoordinates(body);
            return point ?? await _resolveGoogleMapsFallback(value);
          }
          currentUri = currentUri.resolve(redirectTarget);
        }
        return _parseGoogleMapsCoordinates(currentUri.toString()) ??
            await _resolveGoogleMapsFallback(value);
      } finally {
        client.close();
      }
    } catch (_) {
      return _resolveGoogleMapsFallback(value);
    }
  }

  Future<void> _applyMapUrl({bool showFailure = true}) async {
    if (_resolvingMapUrl) return;
    setState(() => _resolvingMapUrl = true);
    final point = await _coordinatesFromMapInput(_mapUrlController.text.trim());
    if (!mounted) return;
    setState(() => _resolvingMapUrl = false);
    if (point == null) {
      if (showFailure) {
        _showMessage(
            'تعذر قراءة الرابط. ألصق رابط Google Maps كاملًا أو اكتب الإحداثيات مثل 15.50,32.56');
      }
      return;
    }
    setState(() {
      _destination = point;
      _preview = null;
    });
    await _moveMapTo(point);
    _showMessage(
        'تم تحديد موقع المستلم على الخريطة. اضغط معاينة رسوم التوصيل لاعتماده.');
  }

  void _onMapUrlChanged(String value) {
    _mapUrlDebounce?.cancel();
    if (value.trim().length < 8) return;
    _mapUrlDebounce = Timer(const Duration(milliseconds: 600), () {
      _applyMapUrl(showFailure: false);
    });
  }

  Future<void> _moveMapTo(LatLng point) async {
    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: point, zoom: 16)),
    );
  }

  Future<void> _previewDelivery() async {
    if (_destination == null) {
      _showMessage('حدد موقع العميل من الخريطة أو الصق رابطاً بالإحداثيات');
      return;
    }
    setState(() => _loadingPreview = true);
    try {
      final result = await _callable('previewStoreDirectDelivery').call({
        'restaurantId': widget.restaurantId,
        'clientLat': _destination!.latitude,
        'clientLng': _destination!.longitude,
      });
      if (!mounted) return;
      setState(() => _preview = Map<String, dynamic>.from(result.data as Map));
    } on FirebaseFunctionsException catch (error) {
      _showMessage(error.message ?? 'تعذر احتساب الرسوم');
    } catch (_) {
      _showMessage('تعذر احتساب الرسوم حالياً');
    } finally {
      if (mounted) setState(() => _loadingPreview = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() ||
        _destination == null ||
        _preview == null) {
      _showMessage('أكمل البيانات واعرض معاينة الرسوم أولاً');
      return;
    }
    setState(() => _submitting = true);
    try {
      final result = await _callable('createStoreDirectDelivery').call({
        'restaurantId': widget.restaurantId,
        'clientName': _nameController.text.trim(),
        'clientPhone': _phoneController.text.trim(),
        'clientWhatsappPhone': _whatsappPhoneController.text.trim(),
        'packageDescription': _descriptionController.text.trim(),
        'clientMapUrl': _mapUrlController.text.trim(),
        'clientLat': _destination!.latitude,
        'clientLng': _destination!.longitude,
      });
      final resultData = Map<String, dynamic>.from(result.data as Map);
      final orderId = resultData['orderId'] as String;
      final trackingUrl = (resultData['trackingUrl'] ?? '').toString().trim();
      if (mounted && trackingUrl.isNotEmpty) {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('تم إنشاء الطلب'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'سيتم إرسال رابط التتبع للعميل تلقائياً عند قبول المندوب. يمكنك نسخه يدوياً عند الحاجة.',
                ),
                const SizedBox(height: 12),
                SelectableText(trackingUrl),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('حسناً'),
              ),
            ],
          ),
        );
      }
      final order = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .get();
      if (!mounted || !order.exists) return;
      final data = Map<String, dynamic>.from(order.data()!);
      data['docId'] = order.id;
      await Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => StoreOrderDetailsScreen(orderData: data),
      ));
    } on FirebaseFunctionsException catch (error) {
      _showMessage(error.message ?? 'تعذر إرسال الطلب');
    } catch (_) {
      _showMessage('تعذر إرسال الطلب حالياً');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final destination = _destination;
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(title: const Text('وصّلها من المتجر')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B00), Color(0xFF14B8A6)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'وصّلها من المتجر',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'أدخل بيانات المستلم وموقعه، يعاين النظام الرسوم، ثم يرسل الطلب للمندوبين ويرسل رابط متابعة للعميل عند القبول.',
                    style: TextStyle(color: Colors.white, height: 1.45),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const _DirectDeliverySteps(),
            const SizedBox(height: 18),
            const Text('بيانات المستلم',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'اسم العميل'),
                validator: (value) =>
                    value!.trim().isEmpty ? 'الاسم مطلوب' : null),
            const SizedBox(height: 10),
            TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'رقم هاتف العميل',
                  helperText: 'يستخدم للاتصال ورسالة التتبع عند عدم إدخال واتساب منفصل',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (value) =>
                    value!.trim().isEmpty ? 'رقم الهاتف مطلوب' : null),
            const SizedBox(height: 10),
            TextFormField(
                controller: _whatsappPhoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    labelText: 'رقم واتساب العميل (اختياري)',
                    helperText: 'اتركه فارغاً إذا كان نفس رقم الهاتف')),
            const SizedBox(height: 10),
            TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'وصف الإرسالية',
                  hintText: 'مثال: كيس منتجات، دواء، مستندات، طلب متجر',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                )),
            const SizedBox(height: 22),
            const Text('موقع العميل',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            TextField(
                controller: _mapUrlController,
                keyboardType: TextInputType.url,
                onChanged: _onMapUrlChanged,
                onEditingComplete: _applyMapUrl,
                decoration: InputDecoration(
                    labelText: 'رابط Google Maps أو إحداثيات العميل',
                    hintText: 'https://maps.google.com/... أو 15.50,32.56',
                    helperText: 'يمكنك اللصق أو الضغط على الخريطة لتحديد النقطة',
                    suffixIcon: IconButton(
                        icon: _resolvingMapUrl
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.my_location_rounded),
                        tooltip: 'استخدام الرابط',
                        onPressed: _applyMapUrl))),
            const SizedBox(height: 8),
            SizedBox(
              height: 260,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                      target: destination ?? const LatLng(15.5007, 32.5599),
                      zoom: destination == null ? 11 : 15),
                  onMapCreated: (controller) {
                    _mapController = controller;
                    if (_destination != null) _moveMapTo(_destination!);
                  },
                  onTap: (point) => setState(() {
                    _destination = point;
                    _preview = null;
                  }),
                  gestureRecognizers: {
                    Factory<OneSequenceGestureRecognizer>(
                      () => EagerGestureRecognizer(),
                    ),
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: false,
                  markers: destination == null
                      ? {}
                      : {
                          Marker(
                              markerId: const MarkerId('client'),
                              position: destination)
                        },
                ),
              ),
            ),
            if (destination != null) ...[
              const SizedBox(height: 8),
              Text(
                'النقطة المحددة: ${destination.latitude.toStringAsFixed(5)}, ${destination.longitude.toStringAsFixed(5)}',
                style: const TextStyle(color: Colors.black54),
              ),
            ],
            const SizedBox(height: 14),
            OutlinedButton.icon(
                onPressed: _loadingPreview ? null : _previewDelivery,
                icon: _loadingPreview
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.calculate_outlined),
                label: const Text('معاينة رسوم التوصيل')),
            if (_preview != null) _FeePreview(data: _preview!),
            const SizedBox(height: 12),
            FilledButton.icon(
                onPressed: _submitting || _preview == null ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.local_shipping_outlined),
                label: const Text('تأكيد وإرسال الطلب')),
          ],
        ),
      ),
    );
  }
}

class _DirectDeliverySteps extends StatelessWidget {
  const _DirectDeliverySteps();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: _StepChip(
            icon: Icons.person_outline_rounded,
            label: 'المستلم',
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _StepChip(
            icon: Icons.location_on_outlined,
            label: 'الموقع',
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _StepChip(
            icon: Icons.payments_outlined,
            label: 'الرسوم',
          ),
        ),
      ],
    );
  }
}

class _StepChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StepChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 17, color: const Color(0xFFFF6B00)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeePreview extends StatelessWidget {
  final Map<String, dynamic> data;
  const _FeePreview({required this.data});

  num _number(String key) =>
      data[key] is num ? data[key] as num : num.tryParse('${data[key]}') ?? 0;

  @override
  Widget build(BuildContext context) {
    final fee = _number('deliveryFee');
    final balanceAfter = _number('walletBalanceAfterDebit');
    final distanceKm = _number('distanceKm');
    final driverShare = _number('driverShare');
    return Card(
      margin: const EdgeInsets.only(top: 14),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_outlined, color: Color(0xFFFF6B00)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('معاينة وصّلها',
                    style:
                        TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              ),
              Text('${fee.toStringAsFixed(0)} ج.س',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 17)),
            ],
          ),
          const SizedBox(height: 12),
          _PreviewLine(
            icon: Icons.route_outlined,
            label: 'المسافة التقريبية',
            value: '${distanceKm.toStringAsFixed(1)} كم',
          ),
          _PreviewLine(
            icon: Icons.delivery_dining_outlined,
            label: 'حصة المندوب المتوقعة',
            value: '${driverShare.toStringAsFixed(0)} ج.س',
          ),
          _PreviewLine(
            icon: Icons.account_balance_wallet_outlined,
            label: 'رصيد المتجر بعد الخصم',
            value: '${balanceAfter.toStringAsFixed(0)} ج.س',
            valueColor: balanceAfter < 0 ? Colors.red : Colors.green,
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B00).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'بعد التأكيد سيتم إنشاء طلب مباشر، خصم الرسوم من محفظة المتجر، وإرسال رابط متابعة للعميل عند قبول المندوب.',
              style: TextStyle(height: 1.45),
            ),
          ),
        ]),
      ),
    );
  }
}

class _PreviewLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _PreviewLine({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.black54),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
