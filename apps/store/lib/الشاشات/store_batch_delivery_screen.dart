import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class StoreBatchDeliveryScreen extends StatefulWidget {
  final String restaurantId;

  const StoreBatchDeliveryScreen({super.key, required this.restaurantId});

  @override
  State<StoreBatchDeliveryScreen> createState() =>
      _StoreBatchDeliveryScreenState();
}

class _StoreBatchDeliveryScreenState extends State<StoreBatchDeliveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pickupTimeController = TextEditingController();
  final List<_BatchStopForm> _stops = [_BatchStopForm(), _BatchStopForm()];
  Map<String, dynamic>? _preview;
  bool _loadingPreview = false;
  bool _submitting = false;
  List<Map<String, dynamic>> _lastPreviewStops = const [];
  List<Map<String, dynamic>> _lastTrackingLinks = const [];

  HttpsCallable _callable(String name) =>
      FirebaseFunctions.instanceFor(region: 'me-central1').httpsCallable(name);

  @override
  void dispose() {
    _pickupTimeController.dispose();
    for (final stop in _stops) {
      stop.dispose();
    }
    super.dispose();
  }

  num _number(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? 0;
  }

  ({double lat, double lng})? _parseCoordinates(String value) {
    final decoded = Uri.decodeFull(value)
        .replaceAll('+', ' ')
        .replaceAll('\\u0026', '&')
        .replaceAll('\\x26', '&');
    final patterns = [
      RegExp(
        r'(?:[?&](?:q|query|ll|destination|center|origin)=|@)(-?\d{1,2}(?:\.\d+)?)[, ]+(-?\d{1,3}(?:\.\d+)?)',
        caseSensitive: false,
      ),
      RegExp(r'!3d(-?\d{1,2}(?:\.\d+)?)!4d(-?\d{1,3}(?:\.\d+)?)'),
      RegExp(r'^\s*(-?\d{1,2}(?:\.\d+)?)[, ]+(-?\d{1,3}(?:\.\d+)?)\s*$'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(decoded);
      if (match == null) continue;
      final lat = double.tryParse(match.group(1)!);
      final lng = double.tryParse(match.group(2)!);
      if (lat != null && lng != null && lat.abs() <= 90 && lng.abs() <= 180) {
        return (lat: lat, lng: lng);
      }
    }
    return null;
  }

  Future<({double lat, double lng})?> _resolveStopCoordinates(
      String value) async {
    final direct = _parseCoordinates(value);
    if (direct != null) return direct;
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) return null;
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
      return (lat: lat, lng: lng);
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> _payloadStops() {
    return _stops.map((stop) {
      final point = _parseCoordinates(stop.mapUrl.text.trim());
      return {
        'clientName': stop.name.text.trim(),
        'clientPhone': stop.phone.text.trim(),
        'clientWhatsappPhone': stop.whatsappPhone.text.trim(),
        'zoneName': stop.zone.text.trim(),
        'addressText': stop.address.text.trim(),
        'packageDescription': stop.description.text.trim(),
        'clientMapUrl': stop.mapUrl.text.trim(),
        if (point != null) 'clientLat': point.lat,
        if (point != null) 'clientLng': point.lng,
        'codAmount':
            num.tryParse(stop.codAmount.text.trim().replaceAll(',', '.')) ?? 0,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _payloadStopsWithResolvedMaps() async {
    final payload = _payloadStops();
    for (var i = 0; i < payload.length; i += 1) {
      final stop = payload[i];
      final hasCoordinates =
          stop['clientLat'] is num && stop['clientLng'] is num;
      final mapUrl = (stop['clientMapUrl'] ?? '').toString().trim();
      if (hasCoordinates || mapUrl.isEmpty) continue;
      final point = await _resolveStopCoordinates(mapUrl);
      if (point == null) continue;
      stop['clientLat'] = point.lat;
      stop['clientLng'] = point.lng;
    }
    return payload;
  }

  Future<void> _previewDelivery() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loadingPreview = true;
      _preview = null;
    });
    try {
      final stops = await _payloadStopsWithResolvedMaps();
      final result = await _callable('previewStoreBatchDelivery').call({
        'restaurantId': widget.restaurantId,
        'stops': stops,
      });
      if (!mounted) return;
      setState(() {
        _preview = Map<String, dynamic>.from(result.data as Map);
        _lastPreviewStops = stops;
      });
    } on FirebaseFunctionsException catch (error) {
      _showMessage(error.message ?? 'تعذر حساب الرحلات المجمعة');
    } catch (_) {
      _showMessage('تعذر حساب الرحلات المجمعة حالياً');
    } finally {
      if (mounted) setState(() => _loadingPreview = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_preview == null) {
      _showMessage('اعرض المعاينة أولاً قبل الإرسال');
      return;
    }
    setState(() => _submitting = true);
    try {
      final stops = await _payloadStopsWithResolvedMaps();
      final result = await _callable('createStoreBatchDelivery').call({
        'restaurantId': widget.restaurantId,
        'pickupTimeText': _pickupTimeController.text.trim(),
        'stops': stops,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      final links = (data['trackingLinks'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      setState(() => _lastTrackingLinks = links);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('تم إنشاء الرحلات'),
          content: Text(
            'تم تقسيم ${data['totalStops']} طلبية إلى ${data['totalTrips']} رحلة وإرسالها للمندوبين.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      _showMessage(error.message ?? 'تعذر إنشاء الرحلات المجمعة');
    } catch (_) {
      _showMessage('تعذر إنشاء الرحلات المجمعة حالياً');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _respondRemovalRequest({
    required String orderId,
    required int stopIndex,
    required String decision,
  }) async {
    try {
      await _callable('storeRespondBatchStopRemoval').call({
        'restaurantId': widget.restaurantId,
        'orderId': orderId,
        'stopIndex': stopIndex,
        'decision': decision,
      });
      _showMessage(decision == 'approve'
          ? 'تمت الموافقة على إزالة الطلبية'
          : 'تم رفض إزالة الطلبية');
    } on FirebaseFunctionsException catch (error) {
      _showMessage(error.message ?? 'تعذر تنفيذ القرار');
    } catch (_) {
      _showMessage('تعذر تنفيذ القرار حالياً');
    }
  }

  void _importCsvText(String text) {
    final rows = text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (rows.isEmpty) return;
    final parsed = <_BatchStopForm>[];
    for (final row in rows) {
      final cells = row.split(',').map((cell) => cell.trim()).toList();
      if (cells.length < 3) continue;
      final stop = _BatchStopForm();
      stop.name.text = cells.elementAt(0);
      stop.phone.text = cells.elementAt(1);
      stop.zone.text = cells.elementAt(2);
      if (cells.length > 3) stop.address.text = cells.elementAt(3);
      if (cells.length > 4) stop.mapUrl.text = cells.elementAt(4);
      if (cells.length > 5) stop.description.text = cells.elementAt(5);
      if (cells.length > 6) stop.codAmount.text = cells.elementAt(6);
      if (cells.length > 7) stop.whatsappPhone.text = cells.elementAt(7);
      parsed.add(stop);
    }
    if (parsed.length < 2) {
      _showMessage('CSV يجب أن يحتوي على طلبيتين على الأقل');
      for (final stop in parsed) {
        stop.dispose();
      }
      return;
    }
    setState(() {
      for (final stop in _stops) {
        stop.dispose();
      }
      _stops
        ..clear()
        ..addAll(parsed.take(30));
      _preview = null;
      _lastTrackingLinks = const [];
      _lastPreviewStops = const [];
    });
  }

  Future<void> _showCsvImportDialog() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('استيراد CSV'),
        content: TextField(
          controller: controller,
          minLines: 6,
          maxLines: 12,
          decoration: const InputDecoration(
            hintText:
                'الاسم, الهاتف, المنطقة, العنوان, رابط الخرائط, الوصف, التحصيل, رقم واتساب اختياري',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('استيراد'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text == null) return;
    _importCsvText(text);
  }

  void _addStop() {
    if (_stops.length >= 30) {
      _showMessage('الحد الأعلى 30 طلبية في الدفعة الواحدة');
      return;
    }
    setState(() {
      _stops.add(_BatchStopForm());
      _preview = null;
      _lastPreviewStops = const [];
    });
  }

  void _removeStop(int index) {
    if (_stops.length <= 2) {
      _showMessage('أقل عدد للتوصيل المجمع هو طلبيتان');
      return;
    }
    setState(() {
      final removed = _stops.removeAt(index);
      removed.dispose();
      _preview = null;
      _lastPreviewStops = const [];
    });
  }

  Future<void> _applyStopMapUrl(int index) async {
    if (index < 0 || index >= _stops.length) return;
    final stop = _stops[index];
    final value = stop.mapUrl.text.trim();
    if (value.isEmpty) {
      _showMessage('أضف رابط خرائط أو إحداثيات أولاً');
      return;
    }
    final point = await _resolveStopCoordinates(value);
    if (point == null) {
      _showMessage('تعذر قراءة موقع الطلبية ${index + 1}');
      return;
    }
    setState(() {
      stop.mapUrl.text =
          '${point.lat.toStringAsFixed(6)},${point.lng.toStringAsFixed(6)}';
      _preview = null;
      _lastPreviewStops = const [];
    });
    _showMessage('تم تحديد موقع الطلبية ${index + 1}');
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return Scaffold(
      appBar: AppBar(title: const Text('توصيل مجمّع')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _pickupTimeController,
              decoration: const InputDecoration(
                labelText: 'وقت الاستلام المتوقع (اختياري)',
                hintText: 'مثال: اليوم 5 مساءً',
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _showCsvImportDialog,
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('استيراد من CSV'),
            ),
            const SizedBox(height: 14),
            _RemovalRequestsCard(
              restaurantId: widget.restaurantId,
              onRespond: _respondRemovalRequest,
            ),
            const SizedBox(height: 14),
            ...List.generate(_stops.length, (index) {
              return _StopCard(
                index: index,
                stop: _stops[index],
                onRemove: () => _removeStop(index),
                onResolveMap: () => _applyStopMapUrl(index),
              );
            }),
            OutlinedButton.icon(
              onPressed: _addStop,
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة طلبية أخرى'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loadingPreview ? null : _previewDelivery,
              icon: _loadingPreview
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.calculate_outlined),
              label: const Text('معاينة التقسيم والتكلفة'),
            ),
            if (preview != null) ...[
              const SizedBox(height: 14),
              _PreviewCard(
                data: preview,
                payloadStops: _lastPreviewStops.isEmpty
                    ? _payloadStops()
                    : _lastPreviewStops,
                number: _number,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: const Text('إرسال الرحلات للمندوبين'),
              ),
            ],
            if (_lastTrackingLinks.isNotEmpty) ...[
              const SizedBox(height: 14),
              _TrackingLinksCard(links: _lastTrackingLinks),
            ],
          ],
        ),
      ),
    );
  }
}

class _BatchStopForm {
  final name = TextEditingController();
  final phone = TextEditingController();
  final whatsappPhone = TextEditingController();
  final zone = TextEditingController();
  final address = TextEditingController();
  final mapUrl = TextEditingController();
  final description = TextEditingController();
  final codAmount = TextEditingController();

  void dispose() {
    name.dispose();
    phone.dispose();
    whatsappPhone.dispose();
    zone.dispose();
    address.dispose();
    mapUrl.dispose();
    description.dispose();
    codAmount.dispose();
  }
}

class _RemovalRequestsCard extends StatelessWidget {
  final String restaurantId;
  final Future<void> Function({
    required String orderId,
    required int stopIndex,
    required String decision,
  }) onRespond;

  const _RemovalRequestsCard({
    required this.restaurantId,
    required this.onRespond,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('restaurantId', isEqualTo: restaurantId)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        final requests = <_RemovalRequest>[];
        for (final doc in docs) {
          final data = doc.data();
          if (data['orderSource'] != 'store_batch_delivery' ||
              ((data['batchRemovalRequestCount'] as num?)?.toInt() ?? 0) <=
                  0) {
            continue;
          }
          final stops = (data['batchStops'] as List? ?? const [])
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
          for (var index = 0; index < stops.length; index += 1) {
            final stop = stops[index];
            if (stop['status'] == 'removal_requested' &&
                stop['removalRequestStatus'] == 'pending') {
              requests.add(_RemovalRequest(
                orderId: doc.id,
                stopIndex: index,
                batchCode:
                    (data['batchCode'] ?? data['orderNumber'] ?? doc.id)
                        .toString(),
                stop: stop,
              ));
            }
          }
        }

        if (requests.isEmpty) {
          return const SizedBox.shrink();
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'طلبات إزالة بانتظار موافقتك',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                ...requests.map((request) {
                  final stop = request.stop;
                  final stopCode =
                      (stop['stopCode'] ?? stop['publicStopCode'] ?? '-')
                          .toString();
                  return Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${request.batchCode} | $stopCode',
                          style:
                              const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text('العميل: ${stop['clientName'] ?? '-'}'),
                        Text('المنطقة: ${stop['zoneName'] ?? '-'}'),
                        Text('السبب: ${stop['removalReason'] ?? '-'}'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: () => onRespond(
                                orderId: request.orderId,
                                stopIndex: request.stopIndex,
                                decision: 'approve',
                              ),
                              icon: const Icon(Icons.check_rounded),
                              label: const Text('موافقة'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => onRespond(
                                orderId: request.orderId,
                                stopIndex: request.stopIndex,
                                decision: 'reject',
                              ),
                              icon: const Icon(Icons.close_rounded),
                              label: const Text('رفض'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RemovalRequest {
  const _RemovalRequest({
    required this.orderId,
    required this.stopIndex,
    required this.batchCode,
    required this.stop,
  });

  final String orderId;
  final int stopIndex;
  final String batchCode;
  final Map<String, dynamic> stop;
}

class _StopCard extends StatelessWidget {
  final int index;
  final _BatchStopForm stop;
  final VoidCallback onRemove;
  final VoidCallback onResolveMap;

  const _StopCard({
    required this.index,
    required this.stop,
    required this.onRemove,
    required this.onResolveMap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'طلبية ${index + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'حذف الطلبية',
                ),
              ],
            ),
            TextFormField(
              controller: stop.name,
              decoration: const InputDecoration(labelText: 'اسم العميل'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'مطلوب' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: stop.phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'رقم العميل'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'مطلوب' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: stop.whatsappPhone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'رقم واتساب العميل (اختياري)',
                hintText: 'اتركه فارغاً إذا كان نفس رقم العميل',
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: stop.zone,
              decoration: const InputDecoration(
                labelText: 'المنطقة',
                hintText: 'مثال: الرياض، المنشية، بحري، الثورة',
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'مطلوب' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: stop.mapUrl,
              decoration: const InputDecoration(
                labelText: 'رابط Google Maps أو إحداثيات',
                hintText: '15.50,32.56',
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: onResolveMap,
                icon: const Icon(Icons.my_location_outlined),
                label: const Text('فحص الرابط وتثبيت الموقع'),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: stop.address,
              decoration: const InputDecoration(labelText: 'وصف العنوان'),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: stop.description,
              decoration: const InputDecoration(labelText: 'وصف الطلبية'),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: stop.codAmount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'مبلغ التحصيل من العميل (اختياري)',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final List<Map<String, dynamic>> payloadStops;
  final num Function(Map<String, dynamic>, String) number;

  const _PreviewCard({
    required this.data,
    required this.payloadStops,
    required this.number,
  });

  LatLng? _latLngFromStop(Map<String, dynamic> stop) {
    final latValue = stop['clientLat'] ?? stop['lat'];
    final lngValue = stop['clientLng'] ?? stop['lng'];
    final lat = latValue is num ? latValue.toDouble() : double.tryParse('$latValue');
    final lng = lngValue is num ? lngValue.toDouble() : double.tryParse('$lngValue');
    if (lat == null || lng == null || lat.abs() > 90 || lng.abs() > 180) {
      return null;
    }
    return LatLng(lat, lng);
  }

  Widget _buildMapPreview(List<Map<String, dynamic>> trips) {
    final markers = <Marker>{};
    final polylines = <Polyline>{};
    final points = <LatLng>[];
    final tripColors = <Color>[
      Colors.deepOrange,
      Colors.teal,
      Colors.indigo,
      Colors.purple,
      Colors.brown,
    ];

    for (final trip in trips) {
      final tripIndex = (trip['index'] as num?)?.toInt() ?? 0;
      final color = tripColors[tripIndex % tripColors.length];
      final stops = (trip['stops'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      final tripPoints = <LatLng>[];
      for (final stop in stops) {
        final sequence = (stop['sequence'] as num?)?.toInt() ?? 0;
        final payloadIndex = payloadStops.indexWhere((payload) {
          return '${payload['clientPhone']}' == '${stop['clientPhone']}' &&
              '${payload['clientName']}' == '${stop['clientName']}';
        });
        final payloadStop = payloadIndex >= 0 ? payloadStops[payloadIndex] : stop;
        final point = _latLngFromStop(payloadStop);
        if (point == null) continue;
        points.add(point);
        tripPoints.add(point);
        markers.add(
          Marker(
            markerId: MarkerId('batch-preview-$tripIndex-$sequence'),
            position: point,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              tripIndex == 0
                  ? BitmapDescriptor.hueOrange
                  : BitmapDescriptor.hueAzure,
            ),
            infoWindow: InfoWindow(
              title: 'رحلة ${tripIndex + 1} - توقف $sequence',
              snippet: '${stop['clientName'] ?? ''} - ${stop['zoneName'] ?? ''}',
            ),
          ),
        );
      }
      if (tripPoints.length > 1) {
        polylines.add(
          Polyline(
            polylineId: PolylineId('batch-preview-route-$tripIndex'),
            points: tripPoints,
            color: color,
            width: 5,
          ),
        );
      }
    }

    if (points.isEmpty) {
      return const Text(
        'أضف روابط خرائط أو إحداثيات للطلبيات حتى تظهر معاينة الخريطة.',
        style: TextStyle(color: Colors.black54),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 260,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: points.first,
            zoom: points.length == 1 ? 15 : 12,
          ),
          markers: markers,
          polylines: polylines,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trips = (data['trips'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الإجمالي: ${number(data, 'totalDeliveryFee').toStringAsFixed(0)} ج.س',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            Text(
              'عدد الرحلات: ${number(data, 'totalTrips').toStringAsFixed(0)} | عدد الطلبيات: ${number(data, 'totalStops').toStringAsFixed(0)}',
            ),
            Text(
              'رصيد المتجر بعد الخصم: ${number(data, 'walletBalanceAfterDebit').toStringAsFixed(0)} ج.س',
              style: TextStyle(
                color: number(data, 'walletBalanceAfterDebit') < 0
                    ? Colors.red
                    : Colors.green,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Divider(height: 22),
            _buildMapPreview(trips),
            const Divider(height: 22),
            ...trips.map((trip) {
              final zones = (trip['zones'] as List? ?? const []).join('، ');
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'رحلة ${((trip['index'] as num?)?.toInt() ?? 0) + 1}: '
                  '${trip['stopCount']} توقفات - ${trip['deliveryFee']} ج.س - $zones',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _TrackingLinksCard extends StatelessWidget {
  final List<Map<String, dynamic>> links;

  const _TrackingLinksCard({required this.links});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'روابط التتبع للعملاء',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'بعد قبول المندوب سترسل SpeedStar رابط التتبع تلقائياً عبر واتساب. يمكنك نسخ الرابط يدوياً إذا احتجت.',
            ),
            const Divider(height: 22),
            ...links.map((link) {
              final whatsappPhone = (link['clientWhatsappPhone'] ?? '').toString();
              final batchCode = (link['batchCode'] ?? '').toString();
              final stopCode = (link['stopCode'] ?? '').toString();
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SelectableText(
                  '${batchCode.isEmpty ? '' : '$batchCode | '}'
                  '${stopCode.isEmpty ? '' : '$stopCode | '}'
                  '${link['clientName'] ?? ''} - ${link['clientPhone'] ?? ''}'
                  '${whatsappPhone.isEmpty ? '' : ' - واتساب: $whatsappPhone'}\n'
                  '${link['trackingUrl'] ?? ''}',
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
