import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';

import '../helpers/courier_runtime_helpers.dart';
import '../الخدمات/location_service.dart';
import 'courier_ui.dart';

class CourierBatchTripScreen extends StatefulWidget {
  final String orderId;
  final String driverId;

  const CourierBatchTripScreen({
    super.key,
    required this.orderId,
    required this.driverId,
  });

  @override
  State<CourierBatchTripScreen> createState() => _CourierBatchTripScreenState();
}

class _CourierBatchTripScreenState extends State<CourierBatchTripScreen> {
  final Set<int> _processingStops = <int>{};
  GoogleMapController? _mapController;
  int? _selectedStopIndex;
  bool _endingTrip = false;

  bool _isProcessing(int index) => _processingStops.contains(index);

  Future<void> _updateStop({
    required int index,
    required String status,
    String pin = '',
    String failureReason = '',
  }) async {
    if (_isProcessing(index)) return;
    setState(() => _processingStops.add(index));
    try {
      await courierInvokeCallable(
        'courierUpdateBatchStop',
        {
          'orderId': widget.orderId,
          'driverId': widget.driverId,
          'stopIndex': index,
          'status': status,
          'pin': pin,
          'failureReason': failureReason,
        },
        timeout: const Duration(seconds: 12),
        maxAttempts: 2,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث حالة العميل')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            courierFriendlyFunctionsError(
              e,
              fallback: 'تعذر تحديث حالة العميل الآن.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _processingStops.remove(index));
    }
  }

  Future<void> _completeTrip() async {
    if (_endingTrip) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إنهاء الرحلة'),
        content: const Text(
          'سيتم إغلاق الرحلة بعد التأكد من أن كل العملاء إما تم تسليمهم أو نقلهم لقائمة التعذر/المرتجع.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('إنهاء'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _endingTrip = true);
    try {
      await courierInvokeCallable(
        'courierCompleteBatchTrip',
        {
          'orderId': widget.orderId,
          'driverId': widget.driverId,
        },
        timeout: const Duration(seconds: 14),
        maxAttempts: 2,
      );
      await LocationService.instance
          .stopAfterOrderCompletionIfIdle(widget.driverId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إنهاء الرحلة')),
      );
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            courierFriendlyFunctionsError(
              e,
              fallback: 'تعذر إنهاء الرحلة الآن.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _endingTrip = false);
    }
  }

  Future<void> _askPinAndDeliver(int index) async {
    final controller = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد التسليم'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'PIN من العميل'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (pin == null || pin.isEmpty) return;
    await _updateStop(index: index, status: 'delivered', pin: pin);
  }

  Future<void> _askFailureReason(int index) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تعذر الاستلام'),
        content: TextField(
          controller: controller,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'سبب التعذر',
            hintText: 'مثال: العميل لا يرد أو غير موجود',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('نقل للتعذر'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || reason.isEmpty) return;
    await _updateStop(index: index, status: 'deferred', failureReason: reason);
  }

  Future<void> _requestRemoveStop(int index) async {
    if (_isProcessing(index)) return;
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('طلب إزالة الطلبية'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'سبب الإزالة',
            hintText: 'مثال: لا أستطيع حمل هذه الطلبية مع باقي الرحلة',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('إرسال للمتجر'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || reason.isEmpty) return;
    setState(() => _processingStops.add(index));
    try {
      await courierInvokeCallable(
        'courierRequestRemoveBatchStop',
        {
          'orderId': widget.orderId,
          'driverId': widget.driverId,
          'stopIndex': index,
          'reason': reason,
        },
        timeout: const Duration(seconds: 12),
        maxAttempts: 2,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال طلب الإزالة للمتجر')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            courierFriendlyFunctionsError(
              e,
              fallback: 'تعذر إرسال طلب الإزالة الآن.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _processingStops.remove(index));
    }
  }

  Future<void> _openWhatsapp(String rawPhone, String clientName) async {
    final normalized = normalizeCourierPhone(rawPhone).replaceAll('+', '');
    if (normalized.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('رقم العميل غير متاح')),
      );
      return;
    }
    final text = Uri.encodeComponent(
      'مرحباً ${clientName.isEmpty ? '' : clientName}، معك مندوب SpeedStar بخصوص طلبك.',
    );
    final uri = Uri.parse('https://wa.me/$normalized?text=$text');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح واتساب')),
      );
    }
  }

  Future<void> _callPhone(String rawPhone) async {
    final normalized = normalizeCourierPhone(rawPhone);
    if (normalized.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('رقم العميل غير متاح')),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: normalized);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح تطبيق الاتصال')),
      );
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'next':
      case 'on_the_way':
        return 'في الطريق';
      case 'delivered':
        return 'تم التسليم';
      case 'failed':
        return 'تعذر التسليم';
      case 'deferred':
        return 'مؤجل/لم يستلم';
      case 'returned':
        return 'مرتجع';
      case 'removal_requested':
        return 'بانتظار موافقة المتجر';
      case 'removal_rejected':
        return 'رفض المتجر الإزالة';
      default:
        return 'بانتظار التنفيذ';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'delivered':
        return Colors.green;
      case 'failed':
      case 'deferred':
      case 'returned':
        return Colors.red;
      case 'next':
      case 'on_the_way':
        return AppThemeArabic.courierPrimary;
      case 'removal_requested':
      case 'removal_rejected':
        return Colors.orange;
      default:
        return AppThemeArabic.courierTextSecondary;
    }
  }

  bool _isActiveStatus(String status) {
    return !['delivered', 'failed', 'deferred', 'returned'].contains(status);
  }

  LatLng? _pickupLatLng(Map<String, dynamic> data) {
    final raw = data['restaurantLocation'] ?? data['pickupLocation'];
    if (raw is GeoPoint) return LatLng(raw.latitude, raw.longitude);
    if (raw is Map) {
      final lat = courierToDouble(raw['lat'] ?? raw['latitude']);
      final lng = courierToDouble(raw['lng'] ?? raw['longitude']);
      if (lat != 0 && lng != 0) return LatLng(lat, lng);
    }
    final lat = courierToDouble(data['restaurantLat'] ?? data['pickupLat']);
    final lng = courierToDouble(data['restaurantLng'] ?? data['pickupLng']);
    if (lat == 0 || lng == 0) return null;
    return LatLng(lat, lng);
  }

  LatLng? _stopLatLng(Map<String, dynamic> stop) {
    final lat = courierToDouble(stop['clientLat'] ?? stop['lat']);
    final lng = courierToDouble(stop['clientLng'] ?? stop['lng']);
    if (lat == 0 || lng == 0) return null;
    return LatLng(lat, lng);
  }

  BitmapDescriptor _markerIcon(String status) {
    if (status == 'delivered') {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    }
    if (status == 'failed' || status == 'deferred' || status == 'returned') {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    }
    if (status == 'on_the_way' || status == 'next') {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    }
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
  }

  Set<Marker> _buildMarkers({
    required Map<String, dynamic> data,
    required List<_IndexedStop> stops,
  }) {
    final markers = <Marker>{};
    final pickup = _pickupLatLng(data);
    if (pickup != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('batch-pickup'),
          position: pickup,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: (data['restaurantName'] ?? 'نقطة الاستلام').toString(),
            snippet: 'استلام كل طلبيات الرحلة من هنا',
          ),
        ),
      );
    }

    for (final item in stops) {
      final location = _stopLatLng(item.data);
      if (location == null) continue;
      final status = (item.data['status'] ?? 'pending').toString();
      final name = (item.data['clientName'] ?? 'عميل').toString();
      final zone = (item.data['zoneName'] ?? '').toString();
      final isSelected = _selectedStopIndex == item.index;
      markers.add(
        Marker(
          markerId: MarkerId('batch-stop-${item.index}'),
          position: location,
          icon: isSelected
              ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet)
              : _markerIcon(status),
          infoWindow: InfoWindow(
            title: '${item.displayNumber}. $name',
            snippet: [zone, _statusText(status)]
                .where((v) => v.isNotEmpty)
                .join(' - '),
          ),
          onTap: () => setState(() => _selectedStopIndex = item.index),
        ),
      );
    }
    return markers;
  }

  Set<Polyline> _buildPolylines({
    required Map<String, dynamic> data,
    required List<_IndexedStop> stops,
  }) {
    final points = <LatLng>[
      if (_pickupLatLng(data) != null) _pickupLatLng(data)!,
      ...stops.map((item) => _stopLatLng(item.data)).whereType<LatLng>(),
    ];
    if (points.length < 2) return const <Polyline>{};
    return {
      Polyline(
        polylineId: const PolylineId('batch-route'),
        points: points,
        color: AppThemeArabic.courierPrimary,
        width: 5,
      ),
    };
  }

  List<_IndexedStop> _readStops(Map<String, dynamic> data) {
    final rawStops = (data['batchStops'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final indexed = <_IndexedStop>[];
    for (var index = 0; index < rawStops.length; index += 1) {
      indexed.add(_IndexedStop(index: index, data: rawStops[index]));
    }
    indexed.sort((a, b) {
      final sequenceA = (a.data['sequence'] as num?)?.toInt() ?? a.index;
      final sequenceB = (b.data['sequence'] as num?)?.toInt() ?? b.index;
      return sequenceA.compareTo(sequenceB);
    });
    for (var i = 0; i < indexed.length; i += 1) {
      indexed[i] = indexed[i].copyWith(displayNumber: i + 1);
    }
    return indexed;
  }

  void _focusMap(List<LatLng> points) {
    final controller = _mapController;
    if (controller == null || points.isEmpty) return;
    if (points.length == 1) {
      controller.animateCamera(CameraUpdate.newLatLngZoom(points.first, 15));
      return;
    }
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final point in points.skip(1)) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }
    controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        72,
      ),
    );
  }

  Widget _buildMap(Map<String, dynamic> data, List<_IndexedStop> stops) {
    final points = <LatLng>[
      if (_pickupLatLng(data) != null) _pickupLatLng(data)!,
      ...stops.map((item) => _stopLatLng(item.data)).whereType<LatLng>(),
    ];
    if (points.isEmpty) {
      return const CourierSectionCard(
        child: Text('لا توجد إحداثيات كافية لرسم الخريطة لهذه الرحلة.'),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 280,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: points.first,
            zoom: points.length == 1 ? 15 : 12,
          ),
          markers: _buildMarkers(data: data, stops: stops),
          polylines: _buildPolylines(data: data, stops: stops),
          myLocationButtonEnabled: true,
          myLocationEnabled: true,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          onMapCreated: (controller) {
            _mapController = controller;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _focusMap(points);
            });
          },
        ),
      ),
    );
  }

  Widget _buildStopSection({
    required String title,
    required List<_IndexedStop> stops,
    required IconData icon,
    required Color color,
  }) {
    return CourierSectionCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(
                '$title (${stops.length})',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (stops.isEmpty)
            const Text(
              'لا توجد عناصر هنا الآن',
              style: TextStyle(color: AppThemeArabic.courierTextSecondary),
            )
          else
            ...stops.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildStopCard(item),
                )),
        ],
      ),
    );
  }

  Widget _buildStopSwitcher(List<_IndexedStop> stops) {
    if (stops.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: stops.map((item) {
          final selected = _selectedStopIndex == item.index;
          final status = (item.data['status'] ?? 'pending').toString();
          final location = _stopLatLng(item.data);
          return Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: ChoiceChip(
              selected: selected,
              label: Text('${item.displayNumber}'),
              avatar: Icon(
                Icons.person_pin_circle_rounded,
                size: 18,
                color: selected ? Colors.white : _statusColor(status),
              ),
              selectedColor: AppThemeArabic.courierPrimary,
              labelStyle: TextStyle(
                color:
                    selected ? Colors.white : AppThemeArabic.courierTextPrimary,
                fontWeight: FontWeight.w900,
              ),
              onSelected: (_) {
                setState(() => _selectedStopIndex = item.index);
                if (location != null) {
                  _mapController?.animateCamera(
                    CameraUpdate.newLatLngZoom(location, 15),
                  );
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPickupSummary(Map<String, dynamic> data, List<_IndexedStop> stops) {
    final pickupName =
        (data['restaurantName'] ?? data['storeName'] ?? 'نقطة الاستلام')
            .toString();
    final pickupAddress = (data['restaurantAddress'] ??
            data['pickupAddress'] ??
            data['deliveryAddress'] ??
            '')
        .toString()
        .trim();
    final pickup = _pickupLatLng(data);
    final points = <LatLng>[
      if (pickup != null) pickup,
      ...stops.map((item) => _stopLatLng(item.data)).whereType<LatLng>(),
    ];

    return CourierSectionCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.storefront_rounded,
                  color: AppThemeArabic.courierPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pickupName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: points.isEmpty ? null : () => _focusMap(points),
                icon: const Icon(Icons.fit_screen_rounded),
                label: const Text('كل الرحلة'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'استلام واحد لكل طلبيات الرحلة، ثم التوصيل حسب ترتيب العملاء.',
            style: const TextStyle(color: AppThemeArabic.courierTextSecondary),
          ),
          if (pickupAddress.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('العنوان: $pickupAddress'),
          ],
        ],
      ),
    );
  }

  _IndexedStop? _selectedStop(List<_IndexedStop> stops) {
    if (stops.isEmpty) return null;
    final selectedIndex = _selectedStopIndex;
    if (selectedIndex != null) {
      for (final item in stops) {
        if (item.index == selectedIndex) return item;
      }
    }
    for (final item in stops) {
      final status = (item.data['status'] ?? 'pending').toString();
      if (_isActiveStatus(status)) return item;
    }
    return stops.first;
  }

  Widget _buildStopCard(_IndexedStop item) {
    final stop = item.data;
    final status = (stop['status'] ?? 'pending').toString();
    final processing = _isProcessing(item.index);
    final clientName = (stop['clientName'] ?? 'عميل').toString();
    final clientPhone = (stop['clientPhone'] ?? '').toString();
    final stopCode = (stop['stopCode'] ?? stop['publicStopCode'] ?? '')
        .toString()
        .trim();
    final failureReason = (stop['failureReason'] ?? '').toString().trim();
    final removalReason = (stop['removalReason'] ?? '').toString().trim();
    final codAmount = courierToDouble(stop['codAmount']);
    final canWork = !['delivered', 'returned', 'removal_requested'].contains(status);
    final isDeferred = status == 'failed' || status == 'deferred' || status == 'returned';
    final canRequestRemoval =
        ['pending', 'next', 'removal_rejected'].contains(status);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: _statusColor(status).withValues(alpha: 0.12),
                child: Text(
                  '${item.displayNumber}',
                  style: TextStyle(
                    color: _statusColor(status),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  stopCode.isEmpty ? clientName : '$clientName - $stopCode',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                _statusText(status),
                style: TextStyle(color: _statusColor(status), fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (stopCode.isNotEmpty)
            Text(
              'رقم الطلب: $stopCode',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          Text('الهاتف: ${clientPhone.isEmpty ? '-' : clientPhone}'),
          Text('المنطقة: ${stop['zoneName'] ?? '-'}'),
          if ((stop['addressText'] ?? '').toString().trim().isNotEmpty)
            Text('العنوان: ${stop['addressText']}'),
          if ((stop['packageDescription'] ?? '').toString().trim().isNotEmpty)
            Text('الوصف: ${stop['packageDescription']}'),
          if (codAmount > 0)
            Text('تحصيل: ${courierFormatMoney(codAmount)} ج.س'),
          if (failureReason.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'سبب التعذر: $failureReason',
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
              ),
            ),
          if (removalReason.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'سبب طلب الإزالة: $removalReason',
                style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w700),
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: processing ? null : () => _callPhone(clientPhone),
                icon: const Icon(Icons.call_outlined),
                label: const Text('اتصال'),
              ),
              OutlinedButton.icon(
                onPressed: processing ? null : () => _openWhatsapp(clientPhone, clientName),
                icon: const Icon(Icons.chat_outlined),
                label: const Text('واتساب'),
              ),
              if (canWork) ...[
                if (canRequestRemoval)
                  TextButton.icon(
                    onPressed:
                        processing ? null : () => _requestRemoveStop(item.index),
                    icon: const Icon(Icons.remove_circle_outline),
                    label: const Text('طلب إزالة'),
                  ),
                OutlinedButton.icon(
                  onPressed: processing
                      ? null
                      : () => _updateStop(index: item.index, status: 'on_the_way'),
                  icon: const Icon(Icons.navigation_outlined),
                  label: const Text('في الطريق'),
                ),
                FilledButton.icon(
                  onPressed: processing ? null : () => _askPinAndDeliver(item.index),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('تم التسليم'),
                ),
                TextButton.icon(
                  onPressed: processing ? null : () => _askFailureReason(item.index),
                  icon: const Icon(Icons.report_outlined),
                  label: const Text('تعذر'),
                ),
              ],
              if (isDeferred && status != 'returned')
                TextButton.icon(
                  onPressed: processing
                      ? null
                      : () => _updateStop(index: item.index, status: 'pending'),
                  icon: const Icon(Icons.undo_rounded),
                  label: const Text('إرجاع للقائمة'),
                ),
              if (status != 'delivered' && status != 'returned')
                TextButton.icon(
                  onPressed: processing
                      ? null
                      : () => _updateStop(index: item.index, status: 'returned'),
                  icon: const Icon(Icons.assignment_return_outlined),
                  label: const Text('مرتجع'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildCourierAppBar('تنفيذ الرحلة المجمعة'),
      body: CourierPageBackground(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('orders').doc(widget.orderId).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data?.data();
            if (data == null) {
              return const CourierEmptyState(
                title: 'الرحلة غير موجودة',
                message: 'تعذر تحميل بيانات الرحلة.',
                icon: Icons.route_outlined,
              );
            }
            final stops = _readStops(data);
            final batchCode = (data['batchCode'] ??
                    data['publicBatchCode'] ??
                    data['orderNumber'] ??
                    widget.orderId)
                .toString()
                .trim();
            final activeStops = stops
                .where((item) => _isActiveStatus((item.data['status'] ?? 'pending').toString()))
                .toList();
            final deferredStops = stops
                .where((item) => ['failed', 'deferred', 'returned']
                    .contains((item.data['status'] ?? '').toString()))
                .toList();
            final deliveredStops = stops
                .where((item) => (item.data['status'] ?? '').toString() == 'delivered')
                .toList();
            final selectedStop = _selectedStop(stops);
            if (selectedStop != null && _selectedStopIndex == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _selectedStopIndex == null) {
                  setState(() => _selectedStopIndex = selectedStop.index);
                }
              });
            }
            final canEndTrip = stops.isNotEmpty && activeStops.isEmpty;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                CourierHeroCard(
                  title: 'رحلة $batchCode',
                  subtitle:
                      '${stops.length} توقفات | تم التسليم: ${deliveredStops.length} | قيد التوصيل: ${activeStops.length} | متعذر/مرتجع: ${deferredStops.length}',
                  icon: Icons.route_rounded,
                ),
                const SizedBox(height: 16),
                _buildPickupSummary(data, stops),
                const SizedBox(height: 12),
                _buildMap(data, stops),
                const SizedBox(height: 12),
                _buildStopSwitcher(stops),
                if (selectedStop != null) ...[
                  const SizedBox(height: 12),
                  CourierSectionCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'العميل المحدد الآن',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildStopCard(selectedStop),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: canEndTrip && !_endingTrip ? _completeTrip : null,
                  icon: _endingTrip
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.flag_rounded),
                  label: const Text('إنهاء الرحلة'),
                ),
                if (!canEndTrip)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'يمكن إنهاء الرحلة بعد تسليم كل العملاء أو نقل المتبقين إلى التعذر/المرتجع.',
                      style: TextStyle(color: AppThemeArabic.courierTextSecondary),
                    ),
                  ),
                const SizedBox(height: 16),
                _buildStopSection(
                  title: 'قيد التوصيل',
                  stops: activeStops,
                  icon: Icons.delivery_dining_rounded,
                  color: AppThemeArabic.courierPrimary,
                ),
                const SizedBox(height: 14),
                _buildStopSection(
                  title: 'تعذر أو مرتجع',
                  stops: deferredStops,
                  icon: Icons.report_outlined,
                  color: Colors.red,
                ),
                const SizedBox(height: 14),
                _buildStopSection(
                  title: 'تم تسليمها',
                  stops: deliveredStops,
                  icon: Icons.verified_rounded,
                  color: Colors.green,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _IndexedStop {
  const _IndexedStop({
    required this.index,
    required this.data,
    this.displayNumber = 0,
  });

  final int index;
  final int displayNumber;
  final Map<String, dynamic> data;

  _IndexedStop copyWith({int? displayNumber}) {
    return _IndexedStop(
      index: index,
      data: data,
      displayNumber: displayNumber ?? this.displayNumber,
    );
  }
}
