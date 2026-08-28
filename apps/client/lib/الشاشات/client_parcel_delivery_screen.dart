import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../الثيم/client_theme.dart';
import 'add_new_address_screen.dart';
import 'payment_screen.dart';

class ClientParcelDeliveryScreen extends StatefulWidget {
  const ClientParcelDeliveryScreen({super.key, required this.clientId});

  final String clientId;

  @override
  State<ClientParcelDeliveryScreen> createState() =>
      _ClientParcelDeliveryScreenState();
}

class _ParcelSteps extends StatelessWidget {
  const _ParcelSteps();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: _StepChip(
            icon: Icons.call_received_rounded,
            label: 'استلام',
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _StepChip(
            icon: Icons.outbound_rounded,
            label: 'تسليم',
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _StepChip(
            icon: Icons.payments_outlined,
            label: 'دفع',
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
        color: ClientColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ClientColors.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 17, color: ClientColors.primary),
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

class _PreviewLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _PreviewLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: ClientColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _ClientParcelDeliveryScreenState
    extends State<ClientParcelDeliveryScreen> {
  final _itemController = TextEditingController();
  final _pickupLinkController = TextEditingController();
  final _dropoffLinkController = TextEditingController();
  LatLng? _pickup;
  LatLng? _dropoff;
  String _pickupLabel = 'اختر نقطة الاستلام';
  String _dropoffLabel = 'اختر نقطة التسليم';
  Map<String, dynamic>? _preview;
  bool _loadingPreview = false;
  bool _submitting = false;
  bool _resolvingPickupLink = false;
  bool _resolvingDropoffLink = false;
  Timer? _pickupLinkDebounce;
  Timer? _dropoffLinkDebounce;

  @override
  void dispose() {
    _itemController.dispose();
    _pickupLinkController.dispose();
    _dropoffLinkController.dispose();
    _pickupLinkDebounce?.cancel();
    _dropoffLinkDebounce?.cancel();
    super.dispose();
  }

  LatLng? _parseCoordinates(String raw) {
    final text = Uri.decodeFull(raw)
        .replaceAll('+', ' ')
        .replaceAll('\\u0026', '&')
        .replaceAll('\\x26', '&');
    final patterns = [
      RegExp(
          r'[?&](?:q|query|ll|destination|location)=(-?\d{1,2}(?:\.\d+)?)[, ]+(-?\d{1,3}(?:\.\d+)?)',
          caseSensitive: false),
      RegExp(r'!3d(-?\d{1,2}(?:\.\d+)?)!4d(-?\d{1,3}(?:\.\d+)?)',
          caseSensitive: false),
      RegExp(
          r'/(?:maps/(?:place|search)|place)/(-?\d{1,2}(?:\.\d+)?),(-?\d{1,3}(?:\.\d+)?)',
          caseSensitive: false),
      RegExp(
          r'(?:destination|location|latlng|coordinates)[=:/](-?\d{1,2}(?:\.\d+)?)[,;%20 ]+(-?\d{1,3}(?:\.\d+)?)',
          caseSensitive: false),
      RegExp(
          r'/(?:place|search|dir)/(?:[^/]+/)?(-?\d{1,2}(?:\.\d+)?),(-?\d{1,3}(?:\.\d+)?)',
          caseSensitive: false),
      RegExp(r'@(-?\d{1,2}(?:\.\d+)?)[, ]+(-?\d{1,3}(?:\.\d+)?)',
          caseSensitive: false),
      RegExp(
          r'[?&](?:center|origin)=(-?\d{1,2}(?:\.\d+)?)[, ]+(-?\d{1,3}(?:\.\d+)?)',
          caseSensitive: false),
      RegExp(r'^\s*(-?\d{1,2}(?:\.\d+)?)[, ]+(-?\d{1,3}(?:\.\d+)?)\s*$'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
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
        host.startsWith('google.') ||
        host.contains('.google.') ||
        host.endsWith('.google.com') ||
        host.endsWith('.google.co.uk');
  }

  Future<LatLng?> _resolveGoogleMapsFallback(String value) async {
    try {
      final result = await FirebaseFunctions.instanceFor(region: 'me-central1')
          .httpsCallable('resolveGoogleMapsLocation')
          .call({'mapUrl': value});
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

  Future<LatLng?> _coordinatesFromLink(String raw) async {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || !_isGoogleMapsUrl(uri)) return _parseCoordinates(raw);
    final resolvedByServer = await _resolveGoogleMapsFallback(raw);
    if (resolvedByServer != null) return resolvedByServer;
    final direct = _parseCoordinates(raw);
    if (direct != null) return direct;
    final client = http.Client();
    try {
      var currentUri = uri;
      for (var index = 0; index < 5; index++) {
        final request = http.Request('GET', currentUri)
          ..followRedirects = false
          ..headers.addAll(const {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36',
          });
        final response =
            await client.send(request).timeout(const Duration(seconds: 12));
        final point = _parseCoordinates(currentUri.toString());
        if (point != null) return point;
        final location = response.headers['location'];
        if (location == null ||
            response.statusCode < 300 ||
            response.statusCode >= 400) {
          final point =
              _parseCoordinates(await response.stream.bytesToString());
          return point ?? await _resolveGoogleMapsFallback(raw);
        }
        currentUri = currentUri.resolve(location);
      }
      return _parseCoordinates(currentUri.toString()) ??
          await _resolveGoogleMapsFallback(raw);
    } catch (_) {
      return _resolveGoogleMapsFallback(raw);
    } finally {
      client.close();
    }
  }

  Future<void> _pickPoint(bool pickup) async {
    final selected = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => AddNewAddressScreen(
          userId: widget.clientId,
          userType: 'client',
          resultOnly: true,
          customTitle: pickup ? 'نقطة استلام الغرض' : 'نقطة تسليم الغرض',
          customSaveLabel: 'تأكيد النقطة',
        ),
      ),
    );
    if (selected == null || !mounted) return;
    final lat = (selected['latitude'] as num?)?.toDouble();
    final lng = (selected['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return;
    setState(() {
      if (pickup) {
        _pickup = LatLng(lat, lng);
        _pickupLabel = (selected['addressName'] ?? 'نقطة الاستلام').toString();
      } else {
        _dropoff = LatLng(lat, lng);
        _dropoffLabel = (selected['addressName'] ?? 'نقطة التسليم').toString();
      }
      _preview = null;
    });
  }

  Future<void> _applyLink(bool pickup, {bool showFailure = true}) async {
    final controller = pickup ? _pickupLinkController : _dropoffLinkController;
    setState(() {
      if (pickup) {
        _resolvingPickupLink = true;
      } else {
        _resolvingDropoffLink = true;
      }
    });
    final point = await _coordinatesFromLink(controller.text);
    if (!mounted) return;
    setState(() {
      if (pickup) {
        _resolvingPickupLink = false;
      } else {
        _resolvingDropoffLink = false;
      }
    });
    if (point == null) {
      if (showFailure) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'تعذر قراءة الرابط. ألصق رابط Google Maps كاملًا أو اكتب الإحداثيات.'),
        ));
      }
      return;
    }
    setState(() {
      if (pickup) {
        _pickup = point;
        _pickupLabel = 'نقطة الاستلام من الرابط';
      } else {
        _dropoff = point;
        _dropoffLabel = 'نقطة التسليم من الرابط';
      }
      _preview = null;
    });
  }

  void _onLinkChanged(bool pickup, String value) {
    final timer = pickup ? _pickupLinkDebounce : _dropoffLinkDebounce;
    timer?.cancel();
    if (value.trim().length < 8) return;
    final next = Timer(const Duration(milliseconds: 600),
        () => _applyLink(pickup, showFailure: false));
    if (pickup) {
      _pickupLinkDebounce = next;
    } else {
      _dropoffLinkDebounce = next;
    }
  }

  Future<void> _loadPreview() async {
    if (_pickup == null || _dropoff == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدد نقطتي الاستلام والتسليم أولاً.')),
      );
      return;
    }
    setState(() => _loadingPreview = true);
    try {
      final result = await FirebaseFunctions.instanceFor(region: 'me-central1')
          .httpsCallable('previewClientParcelDelivery')
          .call({
        'pickupLat': _pickup!.latitude,
        'pickupLng': _pickup!.longitude,
        'dropoffLat': _dropoff!.latitude,
        'dropoffLng': _dropoff!.longitude,
      });
      if (mounted) {
        setState(() => _preview = Map<String, dynamic>.from(result.data));
      }
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message ?? 'تعذر حساب الرسوم.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingPreview = false);
      }
    }
  }

  Future<void> _createDelivery() async {
    if (_preview == null ||
        _pickup == null ||
        _dropoff == null ||
        _itemController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('اكتب نوع الغرض واعرض التسعير قبل الدفع.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final result = await FirebaseFunctions.instanceFor(region: 'me-central1')
          .httpsCallable('createClientParcelDelivery')
          .call({
        'pickupLat': _pickup!.latitude,
        'pickupLng': _pickup!.longitude,
        'dropoffLat': _dropoff!.latitude,
        'dropoffLng': _dropoff!.longitude,
        'pickupMapUrl': _pickupLinkController.text.trim(),
        'dropoffMapUrl': _dropoffLinkController.text.trim(),
        'itemDescription': _itemController.text.trim(),
        'deferPayment': true,
      });
      final orderId = (result.data['orderId'] ?? '').toString();
      if (!mounted || orderId.isEmpty) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => PaymentScreen(orderId: orderId)),
      );
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message ?? 'تعذر إنشاء طلب التوصيل.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fee = (_preview?['deliveryFee'] as num?)?.toDouble();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('وصّلها من عميل')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: ClientColors.primary,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'وصّلها',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'أرسل غرضك من أي نقطة إلى أي نقطة. حدد الاستلام والتسليم، راجع الرسوم، ثم أكمل الدفع لتبدأ متابعة المندوب.',
                  style: TextStyle(color: Colors.white, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _ParcelSteps(),
          const SizedBox(height: 16),
          TextField(
            controller: _itemController,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'ما الغرض الذي تريد توصيله؟',
              hintText: 'مثال: مستندات أو طرد صغير',
              prefixIcon: Icon(Icons.inventory_2_outlined),
            ),
          ),
          const SizedBox(height: 12),
          _pointCard(true),
          const SizedBox(height: 12),
          _pointCard(false),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _loadingPreview ? null : _loadPreview,
            icon: _loadingPreview
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.calculate_outlined),
            label: const Text('عرض رسوم التوصيل'),
          ),
          if (fee != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: ClientColors.primary.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(8)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.receipt_long_outlined,
                            color: ClientColors.primary),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text('معاينة وصّلها',
                              style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                        Text('${fee.toStringAsFixed(0)} ج.س',
                            style:
                                const TextStyle(fontWeight: FontWeight.w900)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _PreviewLine(
                      icon: Icons.route_outlined,
                      label: 'المسافة التقريبية',
                      value:
                          '${((_preview?['distanceKm'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)} كم',
                    ),
                    const Text(
                        'بعد المتابعة ستختار طريقة الدفع وترفع الإيصال عند الدفع الإلكتروني.'),
                    const SizedBox(height: 12),
                    SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _submitting ? null : _createDelivery,
                          icon: _submitting
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.payment_outlined),
                          label: const Text('متابعة إلى طرق الدفع'),
                        )),
                  ]),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _pointCard(bool pickup) {
    final label = pickup ? _pickupLabel : _dropoffLabel;
    final controller = pickup ? _pickupLinkController : _dropoffLinkController;
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(pickup ? 'نقطة الاستلام' : 'نقطة التسليم',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(label),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: OutlinedButton.icon(
                        onPressed: () => _pickPoint(pickup),
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('اختيار من الخريطة')))
              ]),
              TextField(
                  controller: controller,
                  onChanged: (value) => _onLinkChanged(pickup, value),
                  onEditingComplete: () => _applyLink(pickup),
                  decoration: InputDecoration(
                      hintText: 'أو ألصق رابط خرائط Google',
                      suffixIcon: IconButton(
                          icon: pickup
                              ? (_resolvingPickupLink
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.my_location_rounded))
                              : (_resolvingDropoffLink
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.my_location_rounded)),
                          onPressed: () => _applyLink(pickup)))),
            ])));
  }
}
