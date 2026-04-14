import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';
import 'package:speedstar_core/src/auth/login_screen_ar.dart';

import '../الخدمات/guest_location_service.dart';
import 'restaurant_detail_screen.dart';
import 'client_notifications_screen.dart';
import 'address_selection_screen.dart';
import 'add_new_address_screen.dart';
import 'chat_screen.dart';

class ClientHomeTab extends StatefulWidget {
  final String clientId;
  final String? initialLocation;

  const ClientHomeTab({
    Key? key,
    required this.clientId,
    this.initialLocation,
  }) : super(key: key);

  @override
  _ClientHomeTabState createState() => _ClientHomeTabState();
}

class _ClientHomeTabState extends State<ClientHomeTab> {
  static const Color primaryColor = AppThemeArabic.clientPrimary;
  static const Color accentColor = AppThemeArabic.clientAccent;
  static const Color backgroundColor = AppThemeArabic.clientBackground;
  static const Color cardColor = Colors.white;
  static const Color textColorPrimary = AppThemeArabic.clientTextPrimary;
  static const Color textColorSecondary = AppThemeArabic.clientTextSecondary;
  static const Color openColor = AppThemeArabic.clientSuccess;
  static const Color closedColor = AppThemeArabic.clientError;

  String _currentDisplayedLocation = "الخرطوم، السودان";
  double? _clientLatitude;
  double? _clientLongitude;
  String? _clientStateId;
  bool _addressStateResolved = false;
  bool _isAddressScreenOpening = false;
  bool _didAttemptInitialLocationSelection = false;
  bool _initialLocationSelectionDismissed = false;
  final List<String> _recentSearches = [];
  String? _selectedMealCategory;
  final PageController _featuredMealsController =
      PageController(viewportFraction: 0.9);
  final ValueNotifier<int> _featuredMealsPageNotifier = ValueNotifier<int>(0);
  Timer? _featuredMealsTimer;
  Future<List<Map<String, dynamic>>>? _cachedMealsFuture;
  String _cachedMealsKey = '';
  int _featuredMealsCount = 0;
  static const double _defaultFallbackVisibleDistanceKm = 120;
  static const List<String> _globalMealCategoryOrder = [
    'الوجبات الرئيسية',
    'الفطور',
    'المشويات',
    'السندويتشات',
    'البيتزا',
    'البرغر',
    'الفراخ',
    'المقبلات',
    'السلطات',
    'الحلويات',
    'المشروبات',
  ];

  bool get _isGuest => widget.clientId.trim().isEmpty;

  double get _fallbackVisibleDistanceKm {
    try {
      final value = FirebaseRemoteConfig.instance
          .getDouble('client_state_guard_distance_km');
      return value > 0 ? value : _defaultFallbackVisibleDistanceKm;
    } catch (_) {
      return _defaultFallbackVisibleDistanceKm;
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null && widget.initialLocation!.isNotEmpty) {
      _currentDisplayedLocation = widget.initialLocation!;
    }
    _refreshDefaultAddress();
  }

  @override
  void dispose() {
    _featuredMealsTimer?.cancel();
    _featuredMealsController.dispose();
    _featuredMealsPageNotifier.dispose();
    super.dispose();
  }

  String _sanitizeCategoryToken(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\u064B-\u0652]'), '')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]+', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _canonicalMealCategory(String rawCategory) {
    final raw = rawCategory.trim();
    if (raw.isEmpty) return 'أصناف متنوعة';

    final token = _sanitizeCategoryToken(raw);
    const aliases = <String, List<String>>{
      'الوجبات الرئيسية': ['وجبات رئيسيه', 'الوجبات', 'وجبات', 'main'],
      'الفطور': ['فطور', 'افطار', 'breakfast'],
      'المشويات': ['مشويات', 'شوايه', 'grill'],
      'السندويتشات': ['سندويتشات', 'ساندوتش', 'ساندويتش', 'sandwich'],
      'البيتزا': ['بيتزا', 'pizza'],
      'البرغر': ['برغر', 'burger'],
      'الفراخ': ['فراخ', 'دجاج', 'chicken'],
      'المقبلات': ['مقبلات', 'appetizer', 'starter'],
      'السلطات': ['سلطات', 'سلطه', 'salad'],
      'الحلويات': ['حلويات', 'تحليه', 'dessert', 'sweet'],
      'المشروبات': ['مشروبات', 'عصائر', 'drinks', 'juice'],
    };

    for (final entry in aliases.entries) {
      for (final value in entry.value) {
        if (token.contains(_sanitizeCategoryToken(value))) {
          return entry.key;
        }
      }
    }

    return raw;
  }

  int _categoryRank(String category) {
    final canonical = _canonicalMealCategory(category);
    final index = _globalMealCategoryOrder.indexOf(canonical);
    return index >= 0 ? index : _globalMealCategoryOrder.length;
  }

  void _syncFeaturedMealsAutoplay(int count) {
    if (_featuredMealsCount == count) {
      return;
    }

    _featuredMealsCount = count;
    _featuredMealsTimer?.cancel();
    _featuredMealsPageNotifier.value = 0;

    if (_featuredMealsController.hasClients) {
      _featuredMealsController.jumpToPage(0);
    }

    if (count <= 1) {
      return;
    }

    _featuredMealsTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_featuredMealsController.hasClients || count <= 1) {
        return;
      }
      final nextPage = (_featuredMealsPageNotifier.value + 1) % count;
      _featuredMealsPageNotifier.value = nextPage;
      _featuredMealsController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _refreshDefaultAddress() async {
    if (_isGuest) {
      await _loadStoredTemporaryLocation();
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('clients')
          .doc(widget.clientId)
          .get();
      final clientData = doc.data() ?? <String, dynamic>{};
      final defaultAddressId = clientData['defaultAddressId'];

      DocumentSnapshot<Map<String, dynamic>>? addressDoc;
      if (defaultAddressId != null && defaultAddressId.toString().isNotEmpty) {
        addressDoc = await FirebaseFirestore.instance
            .collection('clients')
            .doc(widget.clientId)
            .collection('addresses')
            .doc(defaultAddressId.toString())
            .get();
      }

      if (addressDoc == null || !addressDoc.exists) {
        final firstAddress = await FirebaseFirestore.instance
            .collection('clients')
            .doc(widget.clientId)
            .collection('addresses')
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();
        if (firstAddress.docs.isNotEmpty) {
          addressDoc = firstAddress.docs.first;
        }
      }

      if ((addressDoc == null || !addressDoc.exists) && mounted) {
        final importedAddressId =
            await GuestLocationService.saveAsClientAddress(
          widget.clientId,
        );
        if (importedAddressId != null) {
          addressDoc = await FirebaseFirestore.instance
              .collection('clients')
              .doc(widget.clientId)
              .collection('addresses')
              .doc(importedAddressId)
              .get();
        }
      }

      if (!mounted) return;
      if (addressDoc == null || !addressDoc.exists) {
        await _loadStoredTemporaryLocation();
        return;
      }

      final addressData = addressDoc.data() ?? <String, dynamic>{};
      final addressName =
          (addressData['addressName'] ?? 'عنوان بدون اسم').toString();
      final lat = (addressData['latitude'] as num?)?.toDouble();
      final lng = (addressData['longitude'] as num?)?.toDouble();
      final stateId = _resolveClientStateId(
        rawState: addressData['stateId'] ??
            addressData['state'] ??
            addressData['city'] ??
            addressData['administrativeArea'],
        latitude: lat,
        longitude: lng,
      );

      setState(() {
        _currentDisplayedLocation = addressName;
        _clientLatitude = lat;
        _clientLongitude = lng;
        _clientStateId = stateId;
        _addressStateResolved = true;
      });
    } on FirebaseException catch (e) {
      debugPrint('تعذر جلب العنوان الافتراضي: ${e.code} - ${e.message}');
    } catch (e) {
      debugPrint('تعذر جلب العنوان الافتراضي: $e');
    } finally {
      if (mounted && !_addressStateResolved) {
        await _loadStoredTemporaryLocation();
        if (mounted && !_addressStateResolved) {
          setState(() {
            _addressStateResolved = true;
          });
        }
      }
    }
  }

  Future<void> _loadStoredTemporaryLocation() async {
    final guestLocation = await GuestLocationService.load();
    if (!mounted) return;

    if (guestLocation == null) {
      setState(() {
        _addressStateResolved = true;
      });
      return;
    }

    setState(() {
      _currentDisplayedLocation = guestLocation.addressName;
      _clientLatitude = guestLocation.latitude;
      _clientLongitude = guestLocation.longitude;
      _clientStateId = guestLocation.stateId;
      _addressStateResolved = true;
    });
  }

  Future<void> _openInitialMapPickerIfNeeded() async {
    if (!_addressStateResolved) return;
    if (_clientLatitude != null && _clientLongitude != null) return;
    if (_isAddressScreenOpening || _didAttemptInitialLocationSelection) return;
    if (!mounted) return;

    _didAttemptInitialLocationSelection = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _isAddressScreenOpening = true;
      try {
        final selected = await Navigator.push<Map<String, dynamic>>(
          context,
          MaterialPageRoute(
            builder: (_) => AddNewAddressScreen(
              userId: widget.clientId.isEmpty ? 'guest' : widget.clientId,
              userType: 'client',
              existingName: _currentDisplayedLocation,
              existingLatitude: _clientLatitude,
              existingLongitude: _clientLongitude,
              resultOnly: true,
              customTitle: 'حدد موقع التوصيل',
              customSaveLabel: 'حفظ الموقع',
            ),
          ),
        );

        if (selected == null) {
          if (!mounted) return;
          setState(() {
            _initialLocationSelectionDismissed = true;
          });
          return;
        }

        await _saveGuestLocationFromSelection(selected);
        if (!mounted) return;
        setState(() {
          _initialLocationSelectionDismissed = false;
        });
      } finally {
        _isAddressScreenOpening = false;
      }
    });
  }

  bool get _isStateRolloutEnabled {
    try {
      return FirebaseRemoteConfig.instance
          .getBool('client_state_rollout_enabled');
    } catch (_) {
      return false;
    }
  }

  String get _stateRolloutBlockMessage {
    const fallback =
        'لسه ما جيناكم في الولاية يا غالي\nتابعنا على منصات التواصل عشان تعرف حنجيكم متين\nوقريباً حنصلكم.. انتظرونا! ❤️';
    try {
      final value = FirebaseRemoteConfig.instance
          .getString('client_state_rollout_block_message')
          .trim();
      return value.isNotEmpty ? value : fallback;
    } catch (_) {
      return fallback;
    }
  }

  Set<String> get _enabledStatesFromRemote {
    try {
      final raw =
          FirebaseRemoteConfig.instance.getString('client_enabled_states_csv');
      if (raw.trim().isEmpty) {
        return <String>{};
      }
      final parts = raw
          .split(RegExp(r'[,;\n|]'))
          .map(_normalizeStateId)
          .where((value) => value.isNotEmpty)
          .toSet();
      return parts;
    } catch (_) {
      return <String>{};
    }
  }

  bool _isClientStateEnabledForRollout() {
    var clientState = (_clientStateId ?? '').trim();
    if (clientState.isEmpty &&
        _clientLatitude != null &&
        _clientLongitude != null) {
      clientState = _inferKhartoumStateId(
        latitude: _clientLatitude,
        longitude: _clientLongitude,
      );
    }
    if (clientState.isEmpty) {
      return false;
    }
    final enabledStates = _enabledStatesFromRemote;
    return enabledStates.contains(clientState);
  }

  Future<Map<String, String>> _resolveSupportChatData() async {
    var chatId = '${widget.clientId}-support';
    var clientName = 'عميل';

    try {
      final clientDoc = await FirebaseFirestore.instance
          .collection('clients')
          .doc(widget.clientId)
          .get();
      final clientData = clientDoc.data() ?? <String, dynamic>{};
      final savedChatId =
          (clientData['lastSupportConversationId'] ?? '').toString().trim();
      final savedClientName =
          (clientData['name'] ?? clientData['fullName'] ?? '')
              .toString()
              .trim();

      if (savedChatId.isNotEmpty) {
        chatId = savedChatId;
      }
      if (savedClientName.isNotEmpty) {
        clientName = savedClientName;
      }
    } catch (_) {
      // Keep fallbacks.
    }

    return {
      'chatId': chatId,
      'clientName': clientName,
    };
  }

  // دالة لجلب جميع الوجبات من subcollection full_menu لكل مطعم
  Future<List<Map<String, dynamic>>> fetchAllMeals(
      List<Map<String, dynamic>> restaurants) async {
    List<Map<String, dynamic>> allMeals = [];
    for (final r in restaurants) {
      final restaurantId = r['id'];
      if (restaurantId != null) {
        try {
          final mealsSnapshot = await FirebaseFirestore.instance
              .collection('restaurants')
              .doc(restaurantId)
              .collection('full_menu')
              .get();
          for (final doc in mealsSnapshot.docs) {
            final data = doc.data();
            if ((data['name']?.toString() ?? '').isNotEmpty) {
              allMeals.add({
                'type': 'meal',
                'name': data['name'].toString(),
                'restaurant': r,
                'meal': {
                  ...data,
                  'id': doc.id,
                },
              });
            }
          }
        } on FirebaseException {
          continue;
        }
      }
    }
    return allMeals;
  }

  Future<List<Map<String, dynamic>>> _resolveMealsFuture(
    List<Map<String, dynamic>> restaurants,
  ) {
    final ids = restaurants
        .map((restaurant) => (restaurant['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList()
      ..sort();
    final nextKey = ids.join('|');
    if (_cachedMealsFuture == null || _cachedMealsKey != nextKey) {
      _cachedMealsKey = nextKey;
      _cachedMealsFuture = fetchAllMeals(restaurants);
    }
    return _cachedMealsFuture!;
  }

  // مراقبة حذف جميع العناوين أثناء الاستخدام
  Stream<bool> get _hasNoAddressesStream {
    if (_isGuest) {
      return Stream<bool>.value(false);
    }
    return FirebaseFirestore.instance
        .collection('clients')
        .doc(widget.clientId)
        .collection('addresses')
        .snapshots()
        .map((snapshot) => snapshot.docs.isEmpty);
  }

  String _normalizeSearchText(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\u064B-\u0652]'), '')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي');
  }

  int _searchScore(String query, String text) {
    if (query.isEmpty || text.isEmpty) return 0;
    if (text == query) return 1200;
    if (text.startsWith(query)) return 900;
    if (text.contains(' $query')) return 700;
    if (text.contains(query)) return 450;
    final qTokens =
        query.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (qTokens.isEmpty) return 0;
    var tokenHits = 0;
    for (final token in qTokens) {
      if (text.contains(token)) tokenHits += 1;
    }
    if (tokenHits == 0) return 0;
    return 250 + (tokenHits * 60);
  }

  Future<void> _openLoginScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreenArabic(
          allowRegister: true,
          allowGoogleSignIn: false,
          allowPhoneSignIn: false,
          allowGuestSignIn: false,
        ),
      ),
    );

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && !currentUser.isAnonymous) {
      await GuestLocationService.saveAsClientAddress(currentUser.uid);
      await _refreshDefaultAddress();
    }
  }

  Future<void> _pickTemporaryLocation() async {
    try {
      var serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
      }
      if (!serviceEnabled) {
        throw Exception('فعّل خدمة الموقع أولاً');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('تم رفض إذن الموقع');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      var addressName = 'موقعي الحالي';
      String rawState = '';
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        ).timeout(const Duration(seconds: 8));
        if (placemarks.isNotEmpty) {
          final placemark = placemarks.first;
          final locality =
              (placemark.locality ?? placemark.subAdministrativeArea ?? '')
                  .trim();
          rawState =
              (placemark.administrativeArea ?? locality).toString().trim();
          final parts = [
            (placemark.street ?? '').trim(),
            locality,
            (placemark.country ?? '').trim(),
          ].where((part) => part.isNotEmpty).toList();
          if (parts.isNotEmpty) {
            addressName = parts.take(2).join('، ');
          }
        }
      } catch (_) {
        // استخدم الاسم الافتراضي فقط.
      }

      final stateId = _resolveClientStateId(
        rawState: rawState,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      await _persistBrowsingLocation(
        addressName: addressName,
        latitude: position.latitude,
        longitude: position.longitude,
        stateId: stateId,
        city: rawState,
        administrativeArea: rawState,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث موقع التصفح بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحديد الموقع: $e')),
      );
    }
  }

  Future<void> _persistBrowsingLocation({
    required String addressName,
    required double latitude,
    required double longitude,
    required String stateId,
    String? city,
    String? state,
    String? administrativeArea,
  }) async {
    final normalizedAddressName =
        addressName.trim().isEmpty ? 'موقع محدد يدويًا' : addressName.trim();

    if (_isGuest) {
      await GuestLocationService.save(
        GuestLocationData(
          addressName: normalizedAddressName,
          latitude: latitude,
          longitude: longitude,
          stateId: stateId,
        ),
      );
    } else {
      final userDocRef =
          FirebaseFirestore.instance.collection('clients').doc(widget.clientId);
      final addressDocRef =
          userDocRef.collection('addresses').doc('quick_browsing_location');

      await userDocRef.set({
        'uid': widget.clientId,
        'role': 'client',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await addressDocRef.set({
        'addressName': normalizedAddressName,
        'latitude': latitude,
        'longitude': longitude,
        'city': (city ?? '').toString().trim(),
        'state': (state ?? city ?? '').toString().trim(),
        'administrativeArea': (administrativeArea ?? '').toString().trim(),
        'stateId': stateId,
        'isQuickBrowsingLocation': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await userDocRef.set({
        'defaultAddressId': addressDocRef.id,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    if (!mounted) return;
    setState(() {
      _currentDisplayedLocation = normalizedAddressName;
      _clientLatitude = latitude;
      _clientLongitude = longitude;
      _clientStateId = stateId;
      _addressStateResolved = true;
    });
  }

  Future<void> _saveGuestLocationFromSelection(
    Map<String, dynamic> selectedLocation,
  ) async {
    final latitude = (selectedLocation['latitude'] as num?)?.toDouble();
    final longitude = (selectedLocation['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) {
      return;
    }

    final addressName = (selectedLocation['addressName'] ?? 'موقع محدد يدويًا')
        .toString()
        .trim();
    final stateId = _resolveClientStateId(
      rawState: selectedLocation['stateId'] ??
          selectedLocation['state'] ??
          selectedLocation['city'] ??
          selectedLocation['administrativeArea'],
      latitude: latitude,
      longitude: longitude,
    );

    await _persistBrowsingLocation(
      addressName: addressName,
      latitude: latitude,
      longitude: longitude,
      stateId: stateId,
      city: (selectedLocation['city'] ?? '').toString(),
      state: (selectedLocation['state'] ?? '').toString(),
      administrativeArea:
          (selectedLocation['administrativeArea'] ?? '').toString(),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تحديث موقع التصفح من الخريطة')),
    );
  }

  Future<void> _pickTemporaryLocationFromMap() async {
    _didAttemptInitialLocationSelection = true;
    final selected = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => AddNewAddressScreen(
          userId: widget.clientId.isEmpty ? 'guest' : widget.clientId,
          userType: 'client',
          existingName: _currentDisplayedLocation,
          existingLatitude: _clientLatitude,
          existingLongitude: _clientLongitude,
          resultOnly: true,
          customTitle: 'تحديد الموقع على الخريطة',
          customSaveLabel: 'حفظ الموقع',
        ),
      ),
    );

    if (selected == null) {
      if (mounted) {
        setState(() {
          _initialLocationSelectionDismissed = true;
        });
      }
      return;
    }

    await _saveGuestLocationFromSelection(selected);
    if (!mounted) return;
    setState(() {
      _initialLocationSelectionDismissed = false;
    });
  }

  Future<void> _showGuestLocationOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Center(
                    child: Container(
                      width: 56,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'اختيار موقع التصفح',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: textColorPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'اختر أسرع طريقة لتحديد موقع التوصيل الذي ستظهر على أساسه المطاعم.',
                    style: TextStyle(
                      color: textColorSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading:
                        const Icon(Icons.near_me_rounded, color: primaryColor),
                    title: const Text('استخدام موقعي الحالي'),
                    subtitle: const Text('تحديد الموقع تلقائيًا عبر GPS'),
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await _pickTemporaryLocation();
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.map_rounded, color: primaryColor),
                    title: const Text('اختيار يدوي من الخريطة'),
                    subtitle:
                        const Text('حرّك الخريطة وحدد نقطة التوصيل بنفسك'),
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await _pickTemporaryLocationFromMap();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLocationRequiredState() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      backgroundColor: Color(0xFFFFF0E8),
                      child: Icon(
                        Icons.map_rounded,
                        color: primaryColor,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _initialLocationSelectionDismissed
                          ? 'حدد موقعك من الخريطة'
                          : 'جاري فتح الخريطة لتحديد موقعك',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: textColorPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _initialLocationSelectionDismissed
                          ? 'اختر نقطة التوصيل واضغط حفظ، ثم ستظهر لك المطاعم مباشرة.'
                          : 'بعد حفظ الموقع سنعرض المطاعم المناسبة مباشرة.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: textColorSecondary,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (!_initialLocationSelectionDismissed)
                      const CircularProgressIndicator(color: primaryColor),
                    if (_initialLocationSelectionDismissed)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _pickTemporaryLocationFromMap,
                          icon: const Icon(Icons.map_rounded),
                          label: const Text('فتح الخريطة'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _buildSearchEntries(
      List<Map<String, dynamic>> searchItems) {
    final entries = <Map<String, dynamic>>[];
    final labelsSeen = <String>{};

    for (final item in searchItems) {
      final type = (item['type'] ?? '').toString();
      final name = (item['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;

      final restaurant = (item['restaurant'] as Map<String, dynamic>?) ??
          (type == 'restaurant'
              ? item['restaurant'] as Map<String, dynamic>?
              : null) ??
          (type == 'restaurant' ? item : null);
      final restaurantName = (restaurant?['name'] ?? '').toString().trim();
      final offers = (restaurant?['offers'] ?? '').toString().trim();
      final category = _canonicalMealCategory(
        (item['meal']?['category'] ?? item['category'] ?? '').toString().trim(),
      );

      String label = type == 'meal' && restaurantName.isNotEmpty
          ? '$name - $restaurantName'
          : name;
      if (labelsSeen.contains(label)) {
        label = '$label (${entries.length + 1})';
      }
      labelsSeen.add(label);

      final searchBlob = [name, restaurantName, offers, category]
          .where((e) => e.isNotEmpty)
          .join(' ');

      entries.add({
        'id': '${type}_${restaurant?['id'] ?? 'unknown'}_${entries.length}',
        'label': label,
        'type': type,
        'name': name,
        'title': name,
        'restaurant': restaurant,
        'searchText': _normalizeSearchText(searchBlob),
        'subtitle': type == 'meal'
            ? (category.isNotEmpty
                ? '$restaurantName • $category'
                : restaurantName)
            : (offers.isNotEmpty ? offers : 'مطعم'),
        'badge': type == 'meal' ? 'صنف' : 'مطعم',
      });
    }

    return entries;
  }

  void _rememberSearch(String label) {
    _recentSearches.remove(label);
    _recentSearches.insert(0, label);
    if (_recentSearches.length > 6) {
      _recentSearches.removeRange(6, _recentSearches.length);
    }
  }

  String? _restaurantFavoriteDocId(Map<String, dynamic> restaurant) {
    final restaurantId = (restaurant['id'] ?? '').toString().trim();
    if (_isGuest || restaurantId.isEmpty) {
      return null;
    }
    return 'restaurant_${widget.clientId}_$restaurantId';
  }

  String? _mealFavoriteDocId(Map<String, dynamic> entry) {
    final restaurant =
        (entry['restaurant'] as Map<String, dynamic>?) ?? const {};
    final meal = (entry['meal'] as Map<String, dynamic>?) ?? const {};
    final restaurantId = (restaurant['id'] ?? '').toString().trim();
    final mealId = (meal['id'] ?? meal['name'] ?? '').toString().trim();
    if (_isGuest || restaurantId.isEmpty || mealId.isEmpty) {
      return null;
    }
    return 'meal_${widget.clientId}_${restaurantId}_$mealId';
  }

  Future<void> _toggleFavorite({
    required String docId,
    required Map<String, dynamic> payload,
    required String addMessage,
    required String removeMessage,
  }) async {
    if (_isGuest) {
      await _openLoginScreen();
      return;
    }

    final ref = FirebaseFirestore.instance.collection('favorites').doc(docId);
    final snapshot = await ref.get();

    if (snapshot.exists) {
      await ref.delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(removeMessage)),
      );
      return;
    }

    await ref.set({
      ...payload,
      'clientId': widget.clientId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(addMessage)),
    );
  }

  Widget _buildFavoriteIconButton({
    required bool isFavorite,
    required VoidCallback onTap,
    Color backgroundColor = Colors.white,
    Color activeColor = const Color(0xFFE11D48),
  }) {
    return Material(
      color: backgroundColor,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(
            isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: isFavorite ? activeColor : textColorPrimary,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildRestaurantFavoriteButton(Map<String, dynamic> restaurant) {
    final docId = _restaurantFavoriteDocId(restaurant);
    final restaurantId = (restaurant['id'] ?? '').toString().trim();

    if (docId == null || restaurantId.isEmpty) {
      return _buildFavoriteIconButton(
        isFavorite: false,
        onTap: _openLoginScreen,
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('favorites')
          .doc(docId)
          .snapshots(),
      builder: (context, snapshot) {
        final isFavorite = snapshot.data?.exists == true;
        return _buildFavoriteIconButton(
          isFavorite: isFavorite,
          onTap: () {
            _toggleFavorite(
              docId: docId,
              addMessage: 'تمت إضافة المطعم إلى المفضلة',
              removeMessage: 'تمت إزالة المطعم من المفضلة',
              payload: {
                'type': 'restaurant',
                'restaurantId': restaurantId,
                'restaurantName': (restaurant['name'] ?? '').toString(),
                'restaurantImage': (restaurant['image'] ?? '').toString(),
                'offers': (restaurant['offers'] ?? '').toString(),
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMealFavoriteButton(Map<String, dynamic> entry) {
    final docId = _mealFavoriteDocId(entry);
    final restaurant =
        (entry['restaurant'] as Map<String, dynamic>?) ?? const {};
    final meal = (entry['meal'] as Map<String, dynamic>?) ?? const {};
    final restaurantId = (restaurant['id'] ?? '').toString().trim();
    final mealId = (meal['id'] ?? meal['name'] ?? '').toString().trim();

    if (docId == null || restaurantId.isEmpty || mealId.isEmpty) {
      return _buildFavoriteIconButton(
        isFavorite: false,
        onTap: _openLoginScreen,
        backgroundColor: Colors.white.withOpacity(0.92),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('favorites')
          .doc(docId)
          .snapshots(),
      builder: (context, snapshot) {
        final isFavorite = snapshot.data?.exists == true;
        return _buildFavoriteIconButton(
          isFavorite: isFavorite,
          backgroundColor: Colors.white.withOpacity(0.92),
          onTap: () {
            _toggleFavorite(
              docId: docId,
              addMessage: 'تمت إضافة الصنف إلى المفضلة',
              removeMessage: 'تمت إزالة الصنف من المفضلة',
              payload: {
                'type': 'meal',
                'restaurantId': restaurantId,
                'restaurantName': (restaurant['name'] ?? '').toString(),
                'restaurantImage': (restaurant['image'] ?? '').toString(),
                'mealId': mealId,
                'mealName': (meal['name'] ?? '').toString(),
                'mealImage': (meal['imageUrl'] ??
                        meal['image'] ??
                        meal['photoUrl'] ??
                        '')
                    .toString(),
                'mealPrice': meal['price'],
                'category': (meal['category'] ?? '').toString(),
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;

    return StreamBuilder<bool>(
      stream: _hasNoAddressesStream,
      builder: (context, snapshot) {
        if (_isStateRolloutEnabled && !_addressStateResolved) {
          return const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (_clientLatitude == null || _clientLongitude == null) {
          _openInitialMapPickerIfNeeded();
          return _buildLocationRequiredState();
        }

        if (_isStateRolloutEnabled && !_isClientStateEnabledForRollout()) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              backgroundColor: backgroundColor,
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_off_rounded,
                        size: 64,
                        color: primaryColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _stateRolloutBlockMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          height: 1.7,
                          fontWeight: FontWeight.w700,
                          color: textColorPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        // الكود الأصلي كما هو:
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: backgroundColor,
            body: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('restaurants')
                  .where('approvalStatus', isEqualTo: 'approved')
                  .where('menuEverApproved', isEqualTo: true)
                  .snapshots(),
              builder: (ctx, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'تعذر تحميل المطاعم حالياً. تحقق من الاتصال ثم حاول مرة أخرى.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: textColorSecondary,
                        ),
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'لا توجد مطاعم متاحة حالياً',
                      style: TextStyle(
                        fontSize: 16,
                        color: textColorSecondary,
                      ),
                    ),
                  );
                }

                final restaurants = snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final distanceKm = _distanceKmToRestaurant(data);
                  final restaurantStateId = _restaurantStateId(data);
                  return {
                    'id': doc.id,
                    ...data,
                    'distanceKm': distanceKm,
                    'stateId': restaurantStateId,
                    'image': data['logoImageUrl'] ??
                        '', // تمرير شعار المطعم للحقل image
                  };
                }).where((restaurant) {
                  return restaurant['menuApproved'] != false;
                }).where((restaurant) {
                  return _shouldShowRestaurantForClient(restaurant);
                }).toList();

                restaurants.sort((a, b) {
                  final da = (a['distanceKm'] as double?);
                  final db = (b['distanceKm'] as double?);
                  if (da == null && db == null) return 0;
                  if (da == null) return 1;
                  if (db == null) return -1;
                  return da.compareTo(db);
                });

                final featuredRestaurants = restaurants.where((restaurant) {
                  final offerText =
                      (restaurant['offers'] ?? '').toString().trim();
                  final hasOfferText =
                      offerText.isNotEmpty && offerText != 'null';
                  return restaurant['hasOffers'] == true || hasOfferText;
                }).toList();

                final mealsFuture = _resolveMealsFuture(restaurants);

                return SafeArea(
                  child: CustomScrollView(
                    physics: BouncingScrollPhysics(),
                    slivers: [
                      SliverAppBar(
                        expandedHeight: 180,
                        floating: true,
                        pinned: false,
                        backgroundColor: backgroundColor,
                        elevation: 0,
                        flexibleSpace: LayoutBuilder(
                          builder: (BuildContext context,
                              BoxConstraints constraints) {
                            return SingleChildScrollView(
                              physics: NeverScrollableScrollPhysics(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(height: topPadding),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0),
                                    child: _buildTopBar(context),
                                  ),
                                  const SizedBox(height: 4),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0),
                                    child: FutureBuilder<
                                        List<Map<String, dynamic>>>(
                                      future: mealsFuture,
                                      builder: (context, mealSnapshot) {
                                        if (mealSnapshot.connectionState ==
                                            ConnectionState.waiting) {
                                          return Center(
                                              child: CircularProgressIndicator(
                                                  color: primaryColor));
                                        }
                                        final allMeals =
                                            mealSnapshot.data ?? [];
                                        // دمج المطاعم والوجبات في قائمة البحث
                                        final List<Map<String, dynamic>>
                                            searchItems = [
                                          ...restaurants.map((r) => {
                                                'type': 'restaurant',
                                                'name': r['name'].toString(),
                                                'restaurant': r,
                                              }),
                                          ...allMeals
                                        ];
                                        return _buildSearchBar(
                                            context, searchItems);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      if (featuredRestaurants.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 4),
                            child: _buildOfferSectionHeader(),
                          ),
                        ),
                      if (featuredRestaurants.isNotEmpty)
                        SliverPadding(
                          padding: const EdgeInsets.only(
                              left: 16, right: 16, bottom: 20),
                          sliver: SliverToBoxAdapter(
                            child: SizedBox(
                              height: 236,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: featuredRestaurants.length,
                                reverse: true,
                                physics: BouncingScrollPhysics(),
                                itemBuilder: (ctx, idx) {
                                  final r = featuredRestaurants[idx];
                                  final imageProvider =
                                      (r['image']?.toString().isNotEmpty ??
                                              false)
                                          ? NetworkImage(r['image'].toString())
                                          : null;
                                  return _buildRestaurantCard(
                                      context, r, imageProvider);
                                },
                              ),
                            ),
                          ),
                        ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 4),
                          child: FutureBuilder<List<Map<String, dynamic>>>(
                            future: mealsFuture,
                            builder: (context, mealsSnapshot) {
                              if (mealsSnapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const SizedBox.shrink();
                              }
                              final allMeals = mealsSnapshot.data ?? const [];
                              return _buildCategoriesSection(context, allMeals);
                            },
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverToBoxAdapter(
                          child: _buildRestaurantSectionHeader(),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, idx) {
                              final r = restaurants[idx];
                              final imageProvider =
                                  (r['image']?.toString().isNotEmpty ?? false)
                                      ? NetworkImage(r['image'].toString())
                                      : null;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 15),
                                child: _buildRestaurantListTile(
                                  context,
                                  r,
                                  imageProvider,
                                ),
                              );
                            },
                            childCount: restaurants.length,
                          ),
                        ),
                      ),
                    ], // تأكد من إغلاق قائمة slivers هنا
                  ), // إغلاق CustomScrollView
                ); // إغلاق SafeArea
              }, // إغلاق builder الخاص بـ StreamBuilder<QuerySnapshot>
            ), // إغلاق body: StreamBuilder
          ), // إغلاق Scaffold
        ); // إغلاق Directionality
      }, // إغلاق builder الخاص بـ StreamBuilder<bool>
    ); // إغلاق StreamBuilder<bool>
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // زر الدعم في الأعلى
        IconButton(
          icon: const Icon(Icons.support_agent, color: primaryColor, size: 28),
          tooltip: 'تواصل مع الدعم',
          onPressed: () async {
            if (_isGuest) {
              await _openLoginScreen();
              return;
            }
            final supportChat = await _resolveSupportChatData();
            if (!context.mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  currentUserId: widget.clientId,
                  otherUserId: 'support',
                  currentUserRole: 'client',
                  chatId: supportChat['chatId'] ?? '${widget.clientId}-support',
                  currentUserName: supportChat['clientName'] ?? 'عميل',
                ),
              ),
            );
          },
        ),
        GestureDetector(
          onTap: () async {
            if (_isGuest) {
              await _showGuestLocationOptions();
              return;
            }
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddressSelectionScreen(
                  userId: widget.clientId,
                  userType: 'client',
                  isSelecting: true,
                ),
              ),
            );
            // بعد العودة من شاشة العناوين، جلب العنوان الافتراضي من قاعدة البيانات
            await _refreshDefaultAddress();
          },
          child: Row(
            children: [
              Text(
                _currentDisplayedLocation,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: textColorSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.location_on_outlined, color: primaryColor, size: 20),
            ],
          ),
        ),
        if (_isGuest)
          IconButton(
            icon: Icon(Icons.notifications_none,
                size: 28, color: textColorPrimary),
            onPressed: _openLoginScreen,
          )
        else
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('clients')
                .doc(widget.clientId)
                .collection('notifications')
                .orderBy('timestamp', descending: true)
                .limit(50)
                .snapshots(),
            builder: (context, snapshot) {
              final hasUnread = (snapshot.data?.docs ?? const [])
                  .any((doc) => doc.data()['isRead'] != true);

              return IconButton(
                icon: Stack(
                  children: [
                    Icon(Icons.notifications_none,
                        size: 28, color: textColorPrimary),
                    if (hasUnread)
                      Positioned(
                        top: 2,
                        left: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                  ],
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClientNotificationsScreen(
                        clientId: widget.clientId,
                      ),
                    ),
                  );
                },
              );
            },
          ),
      ],
    );
  }

  // تحسين البحث ليشمل المطاعم والوجبات
  Widget _buildSearchBar(
    BuildContext context,
    List<Map<String, dynamic>> searchItems,
  ) {
    final entries = _buildSearchEntries(searchItems);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.white, Color(0xFFF8FAFC)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: primaryColor.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: const Color(0x140F172A),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _openSearchSheet(context, entries),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _recentSearches.isEmpty
                      ? 'ابحث عن مطعم أو صنف'
                      : _recentSearches.first,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColorPrimary.withOpacity(0.95),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.search_rounded,
                  color: primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openSearchSheet(
    BuildContext context,
    List<Map<String, dynamic>> entries,
  ) async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _ClientHomeSearchSheet(
          entries: entries,
          recentSearches: List<String>.from(_recentSearches),
          normalizeSearchText: _normalizeSearchText,
          searchScore: _searchScore,
        );
      },
    );

    if (!mounted || selected == null) {
      return;
    }

    _rememberSearch((selected['label'] ?? '').toString());
    final restaurant = selected['restaurant'] as Map<String, dynamic>?;
    final restaurantId = (restaurant?['id'] ?? '').toString().trim();
    if (restaurant != null && restaurantId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            builder: (_) => RestaurantDetailScreen(
              restaurantId: restaurantId,
              name: restaurant['name']?.toString() ?? '',
              image: restaurant['image']?.toString() ?? '',
              offers: restaurant['offers']?.toString() ?? '',
              clientId: widget.clientId,
            ),
          ),
        );
      });
    }
  }

  Widget _buildSectionHeader(IconData icon, String title, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: TextDirection.rtl,
      children: [
        Icon(icon, color: primaryColor, size: 24),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.right,
        ),
      ],
    );
  }

  Widget _buildOfferSectionHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF7ED), Color(0xFFFFFBF5)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        border: Border.all(color: accentColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildSectionHeader(Icons.local_fire_department_rounded,
                      'عروضنا لك', textColorPrimary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantSectionHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildSectionHeader(
                    Icons.storefront_rounded,
                    'المطاعم',
                    textColorPrimary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPill({
    required IconData icon,
    required String text,
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    final resolvedBackground = backgroundColor ?? const Color(0xFFF8FAFC);
    final resolvedForeground = foregroundColor ?? textColorSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: resolvedBackground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: TextStyle(
              color: resolvedForeground,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Icon(icon, size: 14, color: resolvedForeground),
        ],
      ),
    );
  }

  Widget _buildRestaurantHeroImage(ImageProvider? imageProvider) {
    return imageProvider != null
        ? Image(
            image: imageProvider,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.grey[200],
              child: Icon(Icons.broken_image, color: Colors.grey[400]),
            ),
          )
        : Container(
            color: const Color(0xFFE2E8F0),
            child: Icon(Icons.storefront_rounded,
                color: Colors.grey[500], size: 36),
          );
  }

  List<String> _extractMealCategories(List<Map<String, dynamic>> allMeals) {
    final categories = <String>{};
    for (final entry in allMeals) {
      final meal = (entry['meal'] as Map<String, dynamic>?) ?? const {};
      final category = _canonicalMealCategory(
        (meal['category'] ?? entry['category'] ?? '').toString().trim(),
      );
      if (category.isNotEmpty) {
        categories.add(category);
      }
    }
    final list = categories.toList()
      ..sort((a, b) {
        final rankCompare = _categoryRank(a).compareTo(_categoryRank(b));
        if (rankCompare != 0) return rankCompare;
        return a.compareTo(b);
      });
    return list;
  }

  List<Map<String, dynamic>> _mealsForCategory(
    List<Map<String, dynamic>> allMeals,
    String category,
  ) {
    final meals = allMeals.where((entry) {
      final meal = (entry['meal'] as Map<String, dynamic>?) ?? const {};
      final itemCategory = _canonicalMealCategory(
        (meal['category'] ?? entry['category'] ?? '').toString().trim(),
      );
      return itemCategory == category;
    }).toList();

    meals.sort((a, b) {
      final mealA = (a['meal'] as Map<String, dynamic>?) ?? const {};
      final mealB = (b['meal'] as Map<String, dynamic>?) ?? const {};
      final hasImageA =
          ((mealA['imageUrl'] ?? mealA['image'] ?? mealA['photoUrl'] ?? '')
                  .toString()
                  .trim()
                  .isNotEmpty)
              ? 0
              : 1;
      final hasImageB =
          ((mealB['imageUrl'] ?? mealB['image'] ?? mealB['photoUrl'] ?? '')
                  .toString()
                  .trim()
                  .isNotEmpty)
              ? 0
              : 1;
      final imageCompare = hasImageA.compareTo(hasImageB);
      if (imageCompare != 0) return imageCompare;

      final nameA = (mealA['name'] ?? '').toString();
      final nameB = (mealB['name'] ?? '').toString();
      return nameA.compareTo(nameB);
    });

    return meals;
  }

  Widget _buildCategoriesSection(
    BuildContext context,
    List<Map<String, dynamic>> allMeals,
  ) {
    final categories = _extractMealCategories(allMeals);
    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    final selected = (_selectedMealCategory != null &&
            categories.contains(_selectedMealCategory))
        ? _selectedMealCategory!
        : categories.first;
    final selectedMeals = _mealsForCategory(allMeals, selected);
    final featuredMeals = selectedMeals.take(5).toList();

    _syncFeaturedMealsAutoplay(featuredMeals.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: primaryColor.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: const Color(0x120F172A),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildSectionHeader(Icons.grid_view_rounded,
                              'تصفح الأصناف', textColorPrimary),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: () {
                      _showBrowseCategoriesSheet(context, allMeals, selected);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    icon: const Icon(Icons.open_in_full_rounded, size: 18),
                    label: const Text('تصفح الأصناف'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: primaryColor.withOpacity(0.08)),
                  ),
                  child: Text(
                    'الصنف الحالي: $selected',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: textColorPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              if (featuredMeals.isNotEmpty) ...[
                const SizedBox(height: 18),
                SizedBox(
                  height: 210,
                  child: PageView.builder(
                    controller: _featuredMealsController,
                    reverse: true,
                    itemCount: featuredMeals.length,
                    onPageChanged: (page) {
                      _featuredMealsPageNotifier.value = page;
                    },
                    itemBuilder: (context, index) {
                      return _buildFeaturedMealCard(
                          context, featuredMeals[index]);
                    },
                  ),
                ),
                if (featuredMeals.length > 1) ...[
                  const SizedBox(height: 12),
                  ValueListenableBuilder<int>(
                    valueListenable: _featuredMealsPageNotifier,
                    builder: (context, featuredMealsPage, _) => Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(featuredMeals.length, (index) {
                        final isActive = index == featuredMealsPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          width: isActive ? 22 : 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: isActive
                                ? primaryColor
                                : primaryColor.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showBrowseCategoriesSheet(
    BuildContext context,
    List<Map<String, dynamic>> allMeals,
    String initialCategory,
  ) async {
    final categories = _extractMealCategories(allMeals);
    if (categories.isEmpty) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        String selectedCategory = categories.contains(initialCategory)
            ? initialCategory
            : categories.first;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final selectedMeals = _mealsForCategory(allMeals, selectedCategory);

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Container(
                height: MediaQuery.of(sheetContext).size.height * 0.86,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 56,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  _buildSectionHeader(
                                    Icons.grid_view_rounded,
                                    'تصفح الأصناف',
                                    textColorPrimary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 54,
                      child: ListView.separated(
                        reverse: true,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: categories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          final isSelected = category == selectedCategory;
                          return GestureDetector(
                            onTap: () {
                              setSheetState(() {
                                selectedCategory = category;
                              });
                              setState(() {
                                _selectedMealCategory = category;
                              });
                              _featuredMealsPageNotifier.value = 0;
                              if (_featuredMealsController.hasClients) {
                                _featuredMealsController.jumpToPage(0);
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? primaryColor
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? primaryColor
                                      : Colors.grey.withOpacity(0.18),
                                ),
                              ),
                              child: Text(
                                category,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : textColorPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: selectedMeals.isEmpty
                          ? Center(
                              child: Text(
                                'لا توجد عناصر ضمن هذا الصنف حالياً',
                                style: TextStyle(color: textColorSecondary),
                              ),
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                              itemCount: selectedMeals.length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.96,
                              ),
                              itemBuilder: (context, index) {
                                return _buildCompactMealCard(
                                  sheetContext,
                                  selectedMeals[index],
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFeaturedMealCard(
    BuildContext context,
    Map<String, dynamic> entry,
  ) {
    final meal = (entry['meal'] as Map<String, dynamic>?) ?? const {};
    final restaurant =
        (entry['restaurant'] as Map<String, dynamic>?) ?? const {};
    final mealName = (meal['name'] ?? 'وجبة').toString();
    final restaurantName = (restaurant['name'] ?? 'مطعم').toString();
    final price = (meal['price'] ?? '').toString();
    final category =
        _canonicalMealCategory((meal['category'] ?? '').toString());
    final imageUrl =
        (meal['imageUrl'] ?? meal['image'] ?? meal['photoUrl'] ?? '')
            .toString();
    final imageProvider = imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null;

    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          if (restaurant.isNotEmpty) {
            _openRestaurantDetail(context, restaurant);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0x220F172A),
                blurRadius: 26,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: 14,
                left: 14,
                child: _buildMealFavoriteButton(entry),
              ),
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: imageProvider != null
                      ? Image(
                          image: imageProvider,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.white.withOpacity(0.06),
                          ),
                        )
                      : Container(color: Colors.white.withOpacity(0.04)),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.12),
                        Colors.black.withOpacity(0.58),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          category,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      mealName,
                      textAlign: TextAlign.right,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      restaurantName,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.88),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.arrow_back_ios_new_rounded,
                                  size: 14, color: primaryColor),
                              SizedBox(width: 6),
                              Text(
                                'الدخول إلى المطعم',
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (price.isNotEmpty)
                          Text(
                            '$price ج.س',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactMealCard(
    BuildContext context,
    Map<String, dynamic> entry,
  ) {
    final meal = (entry['meal'] as Map<String, dynamic>?) ?? const {};
    final restaurant =
        (entry['restaurant'] as Map<String, dynamic>?) ?? const {};
    final mealName = (meal['name'] ?? 'وجبة').toString();
    final restaurantName = (restaurant['name'] ?? 'مطعم').toString();
    final price = (meal['price'] ?? '').toString();
    final imageUrl =
        (meal['imageUrl'] ?? meal['image'] ?? meal['photoUrl'] ?? '')
            .toString();
    final imageProvider = imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        if (restaurant.isNotEmpty) {
          _openRestaurantDetail(context, restaurant);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: primaryColor.withOpacity(0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(18)),
                      child: imageProvider != null
                          ? Image(
                              image: imageProvider,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey.shade200,
                                child: Icon(
                                  Icons.fastfood_rounded,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            )
                          : Container(
                              color: Colors.grey.shade200,
                              child: Icon(
                                Icons.fastfood_rounded,
                                color: Colors.grey.shade500,
                              ),
                            ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: _buildMealFavoriteButton(entry),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    mealName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    restaurantName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: textColorSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'الدخول',
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (price.isNotEmpty)
                        Text(
                          '$price ج.س',
                          style: const TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantCard(
    BuildContext context,
    Map<String, dynamic> r,
    ImageProvider? imageProvider,
  ) {
    final status = getRestaurantStatus(r);
    final hoursSummary = getRestaurantHoursSummary(r);
    final isOpen = status.contains('مفتوح');
    final offerText = (r['offers'] ?? '').toString().trim();
    final hasOfferText = offerText.isNotEmpty && offerText != 'null';

    return GestureDetector(
      onTap: () => _openRestaurantDetail(context, r),
      child: Container(
        width: 272,
        margin: const EdgeInsets.only(left: 15),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: const Color(0x180F172A),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(26)),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _buildRestaurantHeroImage(imageProvider),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withOpacity(0.08),
                              Colors.black.withOpacity(0.58),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 14,
                      right: 14,
                      child: _buildInfoPill(
                        icon: isOpen
                            ? Icons.check_circle_rounded
                            : Icons.pause_circle_rounded,
                        text: isOpen ? 'مفتوح الآن' : 'مغلق الآن',
                        backgroundColor: isOpen
                            ? openColor.withOpacity(0.18)
                            : closedColor.withOpacity(0.18),
                        foregroundColor: isOpen ? openColor : closedColor,
                      ),
                    ),
                    if (r['hasOffers'] == true || hasOfferText)
                      Positioned(
                        top: 14,
                        left: 14,
                        child: _buildInfoPill(
                          icon: Icons.local_offer_rounded,
                          text: 'عرض مميز',
                          backgroundColor: accentColor.withOpacity(0.92),
                          foregroundColor: textColorPrimary,
                        ),
                      ),
                    Positioned(
                      top: hasOfferText || r['hasOffers'] == true ? 58 : 14,
                      left: 14,
                      child: _buildRestaurantFavoriteButton(r),
                    ),
                    Positioned(
                      right: 16,
                      left: 16,
                      bottom: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            r['name']?.toString() ?? 'اسم غير متاح',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                              height: 1.15,
                            ),
                          ),
                          if (hasOfferText) ...[
                            const SizedBox(height: 6),
                            Text(
                              offerText,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            status,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: isOpen
                                  ? Colors.white.withOpacity(0.94)
                                  : const Color(0xFFFFE2E2),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (hoursSummary.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              hoursSummary,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.84),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildInfoPill(
                        icon: Icons.access_time_rounded,
                        text: status,
                        backgroundColor: isOpen
                            ? openColor.withOpacity(0.12)
                            : closedColor.withOpacity(0.12),
                        foregroundColor: isOpen ? openColor : closedColor,
                      ),
                      _buildInfoPill(
                        icon: Icons.near_me_rounded,
                        text: _distanceText(r['distanceKm'] as double?),
                      ),
                      _buildInfoPill(
                        icon: Icons.star_rounded,
                        text: _restaurantRatingLabel(r),
                        backgroundColor: accentColor.withOpacity(0.18),
                        foregroundColor: textColorPrimary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.arrow_back_ios_new_rounded,
                            size: 16, color: primaryColor),
                        const SizedBox(width: 8),
                        const Text(
                          'الدخول إلى المطعم',
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                      ],
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

  Widget _buildRestaurantListTile(
    BuildContext context,
    Map<String, dynamic> r,
    ImageProvider? imageProvider,
  ) {
    final status = getRestaurantStatus(r);
    final hoursSummary = getRestaurantHoursSummary(r);
    final isOpen = status.contains('مفتوح');
    final offerText = (r['offers'] ?? '').toString().trim();
    final hasOfferText = offerText.isNotEmpty && offerText != 'null';

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => _openRestaurantDetail(context, r),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: cardColor,
          border: Border.all(color: primaryColor.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
              color: const Color(0x140F172A),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      _buildRestaurantFavoriteButton(r),
                      const SizedBox(width: 8),
                      _buildInfoPill(
                        icon: isOpen
                            ? Icons.check_circle_rounded
                            : Icons.pause_circle_rounded,
                        text: isOpen ? 'مفتوح الآن' : 'مغلق الآن',
                        backgroundColor: isOpen
                            ? openColor.withOpacity(0.14)
                            : closedColor.withOpacity(0.14),
                        foregroundColor: isOpen ? openColor : closedColor,
                      ),
                      const Spacer(),
                      if (r['hasOffers'] == true || hasOfferText)
                        _buildInfoPill(
                          icon: Icons.local_offer_rounded,
                          text: 'عرض',
                          backgroundColor: accentColor.withOpacity(0.24),
                          foregroundColor: textColorPrimary,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    r['name']?.toString() ?? 'اسم غير متاح',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: textColorPrimary,
                      height: 1.15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    hasOfferText
                        ? offerText
                        : (hoursSummary.isNotEmpty ? hoursSummary : status),
                    style: TextStyle(
                      color: textColorSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildInfoPill(
                        icon: Icons.access_time_rounded,
                        text: status,
                        backgroundColor: isOpen
                            ? openColor.withOpacity(0.12)
                            : closedColor.withOpacity(0.12),
                        foregroundColor: isOpen ? openColor : closedColor,
                      ),
                      _buildInfoPill(
                        icon: Icons.near_me_rounded,
                        text: _distanceText(r['distanceKm'] as double?),
                      ),
                      _buildInfoPill(
                        icon: Icons.star_rounded,
                        text: _restaurantRatingLabel(r),
                        backgroundColor: accentColor.withOpacity(0.18),
                        foregroundColor: textColorPrimary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.arrow_back_ios_new_rounded,
                            size: 16, color: primaryColor),
                        const SizedBox(width: 8),
                        const Text(
                          'تصفح القائمة',
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                width: 108,
                height: 132,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _buildRestaurantHeroImage(imageProvider),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withOpacity(0.04),
                              Colors.black.withOpacity(0.28),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double? _distanceKmToRestaurant(Map<String, dynamic> restaurantData) {
    final clientLat = _clientLatitude;
    final clientLng = _clientLongitude;
    if (clientLat == null || clientLng == null) return null;

    double? restLat;
    double? restLng;

    final geo = restaurantData['location'];
    if (geo is GeoPoint) {
      restLat = geo.latitude;
      restLng = geo.longitude;
    }

    restLat ??= (restaurantData['restaurantLat'] as num?)?.toDouble();
    restLng ??= (restaurantData['restaurantLng'] as num?)?.toDouble();
    restLat ??= (restaurantData['latitude'] as num?)?.toDouble();
    restLng ??= (restaurantData['longitude'] as num?)?.toDouble();
    restLat ??= (restaurantData['lat'] as num?)?.toDouble();
    restLng ??= (restaurantData['lng'] as num?)?.toDouble();

    if (restLat == null || restLng == null) return null;

    final meters = Geolocator.distanceBetween(
      clientLat,
      clientLng,
      restLat,
      restLng,
    );
    return meters / 1000;
  }

  String _distanceText(double? distanceKm) {
    if (distanceKm == null) return 'المسافة غير متاحة';
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()} م';
    }
    return '${distanceKm.toStringAsFixed(1)} كم';
  }

  bool _shouldShowRestaurantForClient(Map<String, dynamic> restaurant) {
    final clientState = (_clientStateId ?? '').trim();
    final restaurantState = (restaurant['stateId'] as String?)?.trim() ?? '';
    final distanceKm = restaurant['distanceKm'] as double?;

    if (clientState.isEmpty) {
      return true;
    }

    if (restaurantState.isNotEmpty && restaurantState == clientState) {
      return true;
    }

    if (distanceKm != null && distanceKm <= _fallbackVisibleDistanceKm) {
      return true;
    }

    return false;
  }

  double? _restaurantRatingValue(Map<String, dynamic> restaurantData) {
    final rawAverage = (restaurantData['ratingAverage'] ??
        restaurantData['averageRating']) as num?;
    final value = rawAverage?.toDouble();
    if (value == null || value <= 0) {
      return null;
    }
    return value;
  }

  int _restaurantRatingCount(Map<String, dynamic> restaurantData) {
    final rawCount = (restaurantData['ratingCount'] ??
        restaurantData['reviewCount']) as num?;
    return rawCount?.toInt() ?? 0;
  }

  String _formatRatingValue(double value) {
    final normalized = value.toStringAsFixed(1);
    return normalized.endsWith('.0')
        ? normalized.substring(0, normalized.length - 2)
        : normalized;
  }

  String _restaurantRatingLabel(Map<String, dynamic> restaurantData) {
    final ratingValue = _restaurantRatingValue(restaurantData);
    if (ratingValue == null) {
      return 'جديد';
    }
    final ratingCount = _restaurantRatingCount(restaurantData);
    if (ratingCount > 0) {
      return '${_formatRatingValue(ratingValue)} · $ratingCount';
    }
    return _formatRatingValue(ratingValue);
  }

  String _restaurantStateId(Map<String, dynamic> restaurantData) {
    return _normalizeStateId(
      restaurantData['stateId'] ??
          restaurantData['state'] ??
          restaurantData['region'] ??
          restaurantData['city'],
    );
  }

  String _normalizeStateId(dynamic raw) {
    final value = (raw ?? '').toString().trim();
    if (value.isEmpty) return '';
    final normalized = value
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .toLowerCase();

    final compact = normalized
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]+', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final khartoumTokens = [
      'الخرطوم',
      'خرطوم',
      'khartoum',
      'khartum',
      'بحري',
      'bahri',
      'khartoum north',
      'ام درمان',
      'امدرمان',
      'ام درمان الكبرى',
      'omdurman',
      'omdorman',
      'oum durman',
    ];

    for (final token in khartoumTokens) {
      if (compact == token || compact.contains(token)) {
        return 'khartoum';
      }
    }

    final riverNileTokens = [
      'عطبره',
      'عطبرة',
      'atbara',
      'atbarah',
      'نهر النيل',
      'ولايه نهر النيل',
      'ولاية نهر النيل',
      'river nile',
      'nile river',
      'nahr al nil',
      'nahr el nil',
    ];

    for (final token in riverNileTokens) {
      if (compact == token || compact.contains(token)) {
        return 'river_nile';
      }
    }

    const khartoumAliases = {
      'الخرطوم',
      'خرطوم',
      'khartoum',
      'khartum',
      'بحري',
      'bahri',
      'khartoum north',
      'ام درمان',
      'امدرمان',
      'ام درمان الكبرى',
      'omdurman',
      'omdorman',
      'oum durman',
    };
    if (khartoumAliases.contains(normalized)) {
      return 'khartoum';
    }

    const riverNileAliases = {
      'عطبره',
      'عطبرة',
      'atbara',
      'atbarah',
      'نهر النيل',
      'ولاية نهر النيل',
      'ولايه نهر النيل',
      'river nile',
      'nile river',
      'nahr al nil',
      'nahr el nil',
    };
    if (riverNileAliases.contains(normalized)) {
      return 'river_nile';
    }

    return normalized;
  }

  String _inferKhartoumStateId({double? latitude, double? longitude}) {
    if (latitude == null || longitude == null) return '';

    const minLat = 15.15;
    const maxLat = 16.10;
    const minLng = 32.20;
    const maxLng = 33.10;

    final insideGreaterKhartoum = latitude >= minLat &&
        latitude <= maxLat &&
        longitude >= minLng &&
        longitude <= maxLng;

    return insideGreaterKhartoum ? 'khartoum' : '';
  }

  String _resolveClientStateId({
    required dynamic rawState,
    required double? latitude,
    required double? longitude,
  }) {
    final normalized = _normalizeStateId(rawState);
    final enabledStates = _enabledStatesFromRemote;

    if (normalized.isNotEmpty && enabledStates.contains(normalized)) {
      return normalized;
    }

    final inferred =
        _inferKhartoumStateId(latitude: latitude, longitude: longitude);
    if (inferred.isNotEmpty && enabledStates.contains(inferred)) {
      return inferred;
    }

    return normalized;
  }

  void _openRestaurantDetail(BuildContext context, Map<String, dynamic> r) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RestaurantDetailScreen(
          restaurantId: r['id'],
          name: r['name']?.toString() ?? '',
          image: r['image']?.toString() ?? '',
          offers: r['offers']?.toString() ?? '',
          clientId: widget.clientId,
        ),
      ),
    );
  }

  String getRestaurantStatus(Map<String, dynamic> data) {
    final temporarilyClosed = data['temporarilyClosed'] == true;
    final workingHours = data['workingHours'] as Map<String, dynamic>?;

    if (temporarilyClosed) return 'مغلق مؤقتًا';

    final todayKey = _getDayKey(DateTime.now().weekday);
    final todayHours = workingHours?[todayKey] as Map<String, dynamic>?;

    if (todayHours == null) return 'مغلق اليوم';

    final status = (todayHours['status'] ?? '').toString().trim();
    if (status == 'مغلق') return 'مغلق اليوم';

    final ranges = _extractWorkingTimeRanges(todayHours, status);
    if (ranges.isEmpty) return 'مغلق - وقت غير معروف';

    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    for (final range in ranges) {
      final open = range['open'] as TimeOfDay;
      final close = range['close'] as TimeOfDay;
      if (_isWithinRestaurantTimeRange(nowMinutes, open, close)) {
        return 'مفتوح الآن';
      }
    }

    final nextOpening = _findNextRestaurantOpening(nowMinutes, ranges);
    if (nextOpening != null) {
      return 'مغلق الآن - يفتح الساعة ${nextOpening['label']}';
    }

    return 'مغلق الآن';
  }

  String getRestaurantHoursSummary(Map<String, dynamic> data) {
    final workingHours = data['workingHours'] as Map<String, dynamic>?;
    final todayKey = _getDayKey(DateTime.now().weekday);
    final todayHours = workingHours?[todayKey] as Map<String, dynamic>?;
    if (todayHours == null) return '';

    final status = (todayHours['status'] ?? '').toString().trim();
    if (status == 'مغلق') return 'مغلق اليوم';

    final ranges = _extractWorkingTimeRanges(todayHours, status);
    if (ranges.isEmpty) return '';

    final labels = ranges
        .map((range) {
          final openLabel = (range['label'] ?? '').toString().trim();
          final close = range['close'] as TimeOfDay;
          final closeLabel = _formatTimeOfDay(close);
          if (openLabel.isEmpty) {
            return closeLabel.isEmpty ? '' : 'حتى $closeLabel';
          }
          return '$openLabel - $closeLabel';
        })
        .where((label) => label.isNotEmpty)
        .toList();

    if (labels.isEmpty) return '';
    return labels.length == 1
        ? 'ساعات العمل اليوم: ${labels.first}'
        : 'ساعات العمل اليوم: ${labels.join(' • ')}';
  }

  String _formatTimeOfDay(TimeOfDay value) {
    final period = value.hour >= 12 ? 'م' : 'ص';
    final hour = value.hourOfPeriod == 0 ? 12 : value.hourOfPeriod;
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  List<Map<String, dynamic>> _extractWorkingTimeRanges(
    Map<String, dynamic> dayData,
    String status,
  ) {
    final ranges = <Map<String, dynamic>>[];

    void addRange(dynamic openValue, dynamic closeValue) {
      final openText = openValue?.toString().trim() ?? '';
      final closeText = closeValue?.toString().trim() ?? '';
      final open = _parseArabicTime(openText);
      final close = _parseArabicTime(closeText);
      if (open == null || close == null) return;
      ranges.add({
        'label': openText,
        'open': open,
        'close': close,
      });
    }

    if (status == 'صباحي ومسائي' ||
        (dayData['morning'] is Map && dayData['evening'] is Map)) {
      final morning = dayData['morning'] as Map<String, dynamic>?;
      final evening = dayData['evening'] as Map<String, dynamic>?;
      addRange(morning?['open'], morning?['close']);
      addRange(evening?['open'], evening?['close']);
      return ranges;
    }

    addRange(dayData['open'], dayData['close']);
    return ranges;
  }

  bool _isWithinRestaurantTimeRange(
    int nowMinutes,
    TimeOfDay open,
    TimeOfDay close,
  ) {
    final openMinutes = open.hour * 60 + open.minute;
    final closeMinutes = close.hour * 60 + close.minute;
    if (closeMinutes >= openMinutes) {
      return nowMinutes >= openMinutes && nowMinutes <= closeMinutes;
    }
    return nowMinutes >= openMinutes || nowMinutes <= closeMinutes;
  }

  Map<String, dynamic>? _findNextRestaurantOpening(
    int nowMinutes,
    List<Map<String, dynamic>> ranges,
  ) {
    Map<String, dynamic>? nearest;
    var bestDelta = 1 << 30;
    for (final range in ranges) {
      final open = range['open'] as TimeOfDay;
      final openMinutes = open.hour * 60 + open.minute;
      final delta = openMinutes >= nowMinutes
          ? openMinutes - nowMinutes
          : (24 * 60 - nowMinutes) + openMinutes;
      if (delta < bestDelta) {
        bestDelta = delta;
        nearest = range;
      }
    }
    return nearest;
  }

  TimeOfDay? _parseArabicTime(String time) {
    try {
      String cleanedTime =
          time.replaceAll('ص', 'AM').replaceAll('م', 'PM').trim();
      final parts = cleanedTime.split(':');
      if (parts.length != 2) return null;

      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1].substring(0, 2));

      bool isPM = cleanedTime.contains('PM');
      bool isAM = cleanedTime.contains('AM');

      if (isPM && hour < 12) {
        hour += 12;
      } else if (isAM && hour == 12) {
        hour = 0;
      }

      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return null;
    }
  }

  String _getDayKey(int weekday) {
    switch (weekday) {
      case DateTime.saturday:
        return 'saturday';
      case DateTime.sunday:
        return 'sunday';
      case DateTime.monday:
        return 'monday';
      case DateTime.tuesday:
        return 'tuesday';
      case DateTime.wednesday:
        return 'wednesday';
      case DateTime.thursday:
        return 'thursday';
      case DateTime.friday:
        return 'friday';
      default:
        return '';
    }
  }
}

class _ClientHomeSearchSheet extends StatefulWidget {
  final List<Map<String, dynamic>> entries;
  final List<String> recentSearches;
  final String Function(String value) normalizeSearchText;
  final int Function(String query, String text) searchScore;

  const _ClientHomeSearchSheet({
    required this.entries,
    required this.recentSearches,
    required this.normalizeSearchText,
    required this.searchScore,
  });

  @override
  State<_ClientHomeSearchSheet> createState() => _ClientHomeSearchSheetState();
}

class _ClientHomeSearchSheetState extends State<_ClientHomeSearchSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(_handleQueryChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleQueryChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleQueryChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  List<Map<String, dynamic>> _filteredEntries() {
    final query = widget.normalizeSearchText(_controller.text);
    if (query.isEmpty) {
      final recentLabels = widget.recentSearches.toSet();
      final recentMatches = widget.entries
          .where((entry) => recentLabels.contains(entry['label']))
          .toList();
      if (recentMatches.isNotEmpty) {
        return recentMatches;
      }
      return widget.entries.take(12).toList();
    }

    final scored = <MapEntry<Map<String, dynamic>, int>>[];
    for (final entry in widget.entries) {
      final score = widget.searchScore(
        query,
        (entry['searchText'] ?? '').toString(),
      );
      if (score > 0) {
        scored.add(MapEntry(entry, score));
      }
    }

    scored.sort((a, b) {
      final scoreCompare = b.value.compareTo(a.value);
      if (scoreCompare != 0) {
        return scoreCompare;
      }
      return (a.key['title'] ?? '').toString().compareTo(
            (b.key['title'] ?? '').toString(),
          );
    });

    return scored.take(30).map((entry) => entry.key).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final results = _filteredEntries();
    final hasQuery = _controller.text.trim().isNotEmpty;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.88,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 56,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                        const Spacer(),
                        const Text(
                          'البحث',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: ClientHomeTabStateConstants.textColorPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: ClientHomeTabStateConstants.primaryColor
                              .withOpacity(0.12),
                        ),
                      ),
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          hintText: 'ابحث عن مطعم أو صنف أو عرض',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          prefixIcon: hasQuery
                              ? IconButton(
                                  onPressed: () => _controller.clear(),
                                  icon: const Icon(Icons.close_rounded),
                                )
                              : const Icon(
                                  Icons.search_rounded,
                                  color:
                                      ClientHomeTabStateConstants.primaryColor,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      hasQuery
                          ? 'النتائج المطابقة'
                          : (widget.recentSearches.isEmpty
                              ? 'اقتراحات سريعة'
                              : 'آخر ما بحثت عنه'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: ClientHomeTabStateConstants.textColorSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: results.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.search_off_rounded,
                                size: 42,
                                color: ClientHomeTabStateConstants
                                    .textColorSecondary,
                              ),
                              SizedBox(height: 10),
                              Text(
                                'لم نجد نتيجة مطابقة. جرب اسم المطعم أو اسم الصنف مباشرة.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: ClientHomeTabStateConstants
                                      .textColorSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final entry = results[index];
                          final title = (entry['title'] ?? '').toString();
                          final subtitle = (entry['subtitle'] ?? '').toString();
                          final badge = (entry['badge'] ?? '').toString();
                          final isMeal = (entry['type'] ?? '') == 'meal';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () => Navigator.pop(context, entry),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: ClientHomeTabStateConstants
                                        .primaryColor
                                        .withOpacity(0.08),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: isMeal
                                            ? ClientHomeTabStateConstants
                                                .primaryColor
                                                .withOpacity(0.12)
                                            : ClientHomeTabStateConstants
                                                .accentColor
                                                .withOpacity(0.22),
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: Icon(
                                        isMeal
                                            ? Icons.fastfood_rounded
                                            : Icons.storefront_rounded,
                                        color: ClientHomeTabStateConstants
                                            .textColorPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      ClientHomeTabStateConstants
                                                          .primaryColor
                                                          .withOpacity(0.08),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          999),
                                                ),
                                                child: Text(
                                                  badge,
                                                  style: const TextStyle(
                                                    color:
                                                        ClientHomeTabStateConstants
                                                            .primaryColor,
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ),
                                              const Spacer(),
                                              Expanded(
                                                child: Text(
                                                  title,
                                                  textAlign: TextAlign.right,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w800,
                                                    color:
                                                        ClientHomeTabStateConstants
                                                            .textColorPrimary,
                                                    height: 1.25,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (subtitle.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              subtitle,
                                              textAlign: TextAlign.right,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color:
                                                    ClientHomeTabStateConstants
                                                        .textColorSecondary,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                                height: 1.35,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

abstract final class ClientHomeTabStateConstants {
  static const Color primaryColor = AppThemeArabic.clientPrimary;
  static const Color accentColor = AppThemeArabic.clientAccent;
  static const Color textColorPrimary = AppThemeArabic.clientTextPrimary;
  static const Color textColorSecondary = AppThemeArabic.clientTextSecondary;
}
