import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'client_home_tab.dart'; // تأكد من استيراد الشاشة الرئيسية للعميل

class AddNewAddressScreen extends StatefulWidget {
  final String userId;
  final String userType; // 'client', 'restaurant', or 'driver'
  final String? editAddressId;
  final String? existingName;
  final double? existingLatitude;
  final double? existingLongitude;

  const AddNewAddressScreen({
    Key? key,
    required this.userId,
    required this.userType,
    this.editAddressId,
    this.existingName,
    this.existingLatitude,
    this.existingLongitude,
  }) : super(key: key);

  @override
  State<AddNewAddressScreen> createState() => _AddNewAddressScreenState();
}

class _AddNewAddressScreenState extends State<AddNewAddressScreen> {
  LatLng? selectedLocation;
  final TextEditingController _addressNameController = TextEditingController();
  GoogleMapController? mapController;
  bool _isSaving = false;
  bool _canSave = false;
  bool _firstSaveAttempt = true;
  bool _locationSelected = false;
  String? _saveWarning;
  final Color primaryColor = const Color(0xFFFE724C);

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
    if (widget.editAddressId != null) {
      _addressNameController.text = widget.existingName ?? '';
      selectedLocation = LatLng(
        widget.existingLatitude ?? 15.5007,
        widget.existingLongitude ?? 32.5599,
      );
      _locationSelected = true;
    }
    // منع الحفظ إلا بعد 10 ثوانٍ
    Future.delayed(const Duration(seconds: 10), () {
      if (!mounted) return;
      setState(() {
        _canSave = true;
      });
    });
  }

  Future<void> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) await Geolocator.openLocationSettings();

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
  }

  void _onMapTapped(LatLng position) {
    if (!mounted) return;
    setState(() {
      selectedLocation = position;
      _locationSelected = true;
      _saveWarning = null;
    });
  }

  Future<String> _getCityFromLatLng(LatLng latLng) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        latLng.latitude,
        latLng.longitude,
      ).timeout(const Duration(seconds: 8));
      return placemarks.first.locality ?? placemarks.first.administrativeArea ?? 'غير معروف';
    } catch (_) {
      return 'غير معروف';
    }
  }

  Future<void> _saveAddress() async {
    if (!_canSave) return;
    if (_firstSaveAttempt) {
      if (!mounted) return;
      setState(() {
        _saveWarning = 'تأكد من صحة العنوان واضغط مرة أخرى للحفظ';
        _firstSaveAttempt = false;
      });
      return;
    }
    if (selectedLocation == null || _addressNameController.text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار الموقع وكتابة اسم العنوان')),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _isSaving = true;
    });
    try {
      // استخراج اسم المدينة من الإحداثيات
      final city = await _getCityFromLatLng(selectedLocation!);
      final addressData = {
        'addressName': _addressNameController.text,
        'latitude': selectedLocation!.latitude,
        'longitude': selectedLocation!.longitude,
        'city': city,
        'createdAt': FieldValue.serverTimestamp(),
      };
      final collectionPath = '${widget.userType}s';
      String? newAddressId;
      if (widget.editAddressId == null) {
        final userDocRef = FirebaseFirestore.instance
            .collection(collectionPath)
            .doc(widget.userId);

        // تأكد من وجود وثيقة المستخدم الأساسية قبل أي update
        await userDocRef.set({
          'uid': widget.userId,
          'role': widget.userType,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).timeout(const Duration(seconds: 12));

        final docRef = await FirebaseFirestore.instance
            .collection(collectionPath)
            .doc(widget.userId)
            .collection('addresses')
            .add(addressData)
            .timeout(const Duration(seconds: 12));
        newAddressId = docRef.id;
        // اجعل العنوان الافتراضي مباشرة بعد الإضافة
        if (widget.userType == 'client') {
          await userDocRef
              .set({'defaultAddressId': newAddressId}, SetOptions(merge: true))
              .timeout(const Duration(seconds: 12));
        }
      } else {
        await FirebaseFirestore.instance
            .collection(collectionPath)
            .doc(widget.userId)
            .collection('addresses')
            .doc(widget.editAddressId)
            .update(addressData)
            .timeout(const Duration(seconds: 12));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ العنوان بنجاح ✅')),
      );
      // بعد الحفظ، انتقل مباشرة إلى شاشة العميل الرئيسية
      if (widget.userType == 'client') {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => ClientHomeTab(clientId: widget.userId),
          ),
          (route) => false,
        );
      } else {
        Navigator.pop(context);
      }
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('انتهت مهلة الحفظ. تحقق من الإنترنت ثم أعد المحاولة.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ أثناء حفظ العنوان: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _firstSaveAttempt = true;
          _saveWarning = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final LatLng initialPosition = selectedLocation ?? const LatLng(15.5007, 32.5599);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(widget.editAddressId != null ? 'تعديل العنوان' : 'إضافة عنوان',
              style: const TextStyle(color: Colors.black87)),
          iconTheme: const IconThemeData(color: Colors.black87),
          centerTitle: true,
        ),
        body: Column(
          children: [
            Expanded(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(target: initialPosition, zoom: 14),
                onTap: _onMapTapped,
                markers: selectedLocation == null
                    ? {}
                    : {
                        Marker(
                          markerId: const MarkerId('selectedLocation'),
                          position: selectedLocation!,
                        )
                      },
                onMapCreated: (controller) => mapController = controller,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  if (!_locationSelected)
                    Row(
                      children: const [
                        Icon(Icons.info, color: Colors.orange),
                        SizedBox(width: 8),
                        Expanded(child: Text('يرجى الضغط على زر تحديد الموقع على الخريطة قبل الحفظ', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))),
                      ],
                    ),
                  if (_saveWarning != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(_saveWarning!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ),
                  TextField(
                    controller: _addressNameController,
                    decoration: InputDecoration(
                      labelText: 'اسم العنوان (مثلاً منزل، مكتب...)',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (!_canSave || _isSaving) ? null : _saveAddress,
                      icon: const Icon(Icons.save),
                      label: _isSaving ? const Text('جارٍ الحفظ...') : const Text('حفظ العنوان'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
