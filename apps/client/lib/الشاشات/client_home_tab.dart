import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../الثيم/client_theme.dart';
import 'package:speedstar_core/speedstar_core.dart' show LoginScreenArabic;

import '../الخدمات/guest_location_service.dart';
import '../الخدمات/route_estimate_service.dart';
import 'restaurant_detail_screen.dart';
import 'client_notifications_screen.dart';
import 'client_support_screen.dart';
import 'address_selection_screen.dart';
import 'add_new_address_screen.dart';

class ClientHomeTab extends StatefulWidget {
  final String clientId;
  final String? initialLocation;

  const ClientHomeTab({
    super.key,
    required this.clientId,
    this.initialLocation,
  });

  @override
  State<ClientHomeTab> createState() => _ClientHomeTabState();
}

class _ClientHomeTabState extends State<ClientHomeTab> {
  static const Color primaryColor = ClientColors.primary;
  static const Color accentColor = ClientColors.accent;
  static const Color openColor = ClientColors.success;
  static const Color closedColor = ClientColors.error;
  // ثوابت مُستخدَمة في const TextStyle — تبقى كما هي للتوافقية
  static const Color textColorPrimary = Colors.white;

  // ألوان تتكيف مع الثيم — تُستخدم في الأقسام المحدَّثة
  Color get _textColorPrimary =>
      _isDark ? Colors.white : ClientColors.lightTextPrimary;
  Color get _textColorSecondary =>
      _isDark ? ClientColors.textSecondary : ClientColors.lightTextSecondary;
  Color get _cardBg => _isDark ? const Color(0x1AFFFFFF) : Colors.white;
  // ignore: unused_element
  Color get _cardBorder =>
      _isDark ? const Color(0x33FF6B00) : const Color(0x1AFF6B00);
  Color get _scaffoldBg =>
      _isDark ? ClientColors.background : ClientColors.lightBackground;

  bool _isDark = false;
  String? _clientName;

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

  bool get _showHomeOffersSection {
    try {
      return FirebaseRemoteConfig.instance
          .getBool('client_home_show_offers_section');
    } catch (_) {
      return true;
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null && widget.initialLocation!.isNotEmpty) {
      _currentDisplayedLocation = widget.initialLocation!;
    }
    _refreshDefaultAddress();
    _loadClientName();
    // Failsafe: unblock spinner if address resolution hangs
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted && !_addressStateResolved) {
        setState(() => _addressStateResolved = true);
      }
    });
  }

  Future<void> _loadClientName() async {
    if (_isGuest || widget.clientId.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('clients')
          .doc(widget.clientId)
          .get();
      final name = (doc.data()?['name'] ?? doc.data()?['displayName'] ?? '')
          .toString()
          .trim();
      if (mounted && name.isNotEmpty) {
        setState(() => _clientName = name.split(' ').first);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _featuredMealsTimer?.cancel();
    _featuredMealsController.dispose();
    _featuredMealsPageNotifier.dispose();
    super.dispose();
  }

  String _categoryKey(String input) => _sanitizeCategoryToken(
        _canonicalMealCategory(input),
      );

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
        .replaceAllMapped(
          RegExp(r'(^|\s)ال(?=\p{L})', unicode: true),
          (match) => match.group(1) ?? '',
        )
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

  // دالة لجلب جميع الوجبات من subcollection full_menu لكل مطعم
  Future<List<Map<String, dynamic>>> fetchAllMeals(
      List<Map<String, dynamic>> restaurants) async {
    final perRestaurant = await Future.wait(restaurants.map((r) async {
      final allMeals = <Map<String, dynamic>>[];
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
          return allMeals;
        }
      }
      return allMeals;
    }));
    return perRestaurant.expand((items) => items).toList();
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

  bool _categoryMatches(String source, String selected) {
    final selectedKey = _categoryKey(selected);
    if (selectedKey.isEmpty || selectedKey == _categoryKey('الكل')) {
      return true;
    }
    final sourceKey = _categoryKey(source);
    return sourceKey == selectedKey ||
        sourceKey.contains(selectedKey) ||
        selectedKey.contains(sourceKey);
  }

  void _openCategoryResults({
    required String category,
    required List<Map<String, dynamic>> restaurants,
    required List<Map<String, dynamic>> allMeals,
    required Map<String, Set<String>> mealCategoriesByRestaurant,
  }) {
    final showAll = _categoryKey(category) == _categoryKey('الكل');
    final meals = allMeals.where((entry) {
      if (showAll) return true;
      final meal = (entry['meal'] as Map<String, dynamic>?) ?? const {};
      final mealCategory =
          (meal['category'] ?? entry['category'] ?? '').toString().trim();
      return _categoryMatches(mealCategory, category);
    }).toList();

    final matchedRestaurants = restaurants.where((restaurant) {
      if (showAll) return true;
      return _restaurantMatchesFilter(
        restaurant,
        category,
        mealCategoriesByRestaurant: mealCategoriesByRestaurant,
      );
    }).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _CategoryResultsScreen(
          title: showAll ? 'كل الأصناف' : category,
          clientId: widget.clientId,
          meals: meals,
          restaurants: matchedRestaurants,
        ),
      ),
    );
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
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
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
      if (!mounted) return;
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

    if (!mounted) return;
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
                        color: const Color(0x33FFFFFF),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'اختيار موقع التصفح',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: _textColorPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'اختر أسرع طريقة لتحديد موقع التوصيل الذي ستظهر على أساسه المطاعم.',
                    style: TextStyle(
                      color: _textColorSecondary,
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
        backgroundColor: _scaffoldBg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0x1AFFFFFF),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0x4DFF6B00)),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.15),
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
                      backgroundColor: Color(0x33FF6B00),
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
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _textColorPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _initialLocationSelectionDismissed
                          ? 'اختر نقطة التوصيل واضغط حفظ، ثم ستظهر لك المطاعم مباشرة.'
                          : 'بعد حفظ الموقع سنعرض المطاعم المناسبة مباشرة.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _textColorSecondary,
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
        backgroundColor: Colors.white.withValues(alpha: 0.92),
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
          backgroundColor: Colors.white.withValues(alpha: 0.92),
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
    _isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<bool>(
      stream: _hasNoAddressesStream,
      builder: (context, snapshot) {
        if (_isStateRolloutEnabled && !_addressStateResolved) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              backgroundColor: _scaffoldBg,
              body: _buildShimmerSkeleton(),
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
              backgroundColor: _scaffoldBg,
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
                        style: TextStyle(
                          fontSize: 20,
                          height: 1.7,
                          fontWeight: FontWeight.w700,
                          color: _textColorPrimary,
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
            backgroundColor: _scaffoldBg,
            body: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('restaurants')
                  .where('approvalStatus', isEqualTo: 'approved')
                  .where('menuEverApproved', isEqualTo: true)
                  .snapshots(),
              builder: (ctx, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildShimmerSkeleton();
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
                          color: _textColorSecondary,
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
                        color: _textColorSecondary,
                      ),
                    ),
                  );
                }

                final allApprovedRestaurants = snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final distanceKm = _distanceKmToRestaurant(data);
                  final restaurantStateId = _restaurantStateId(data);
                  return {
                    ...data,
                    'id': doc.id, // يجب أن يأتي بعد data لضمان أولوية doc.id
                    'distanceKm': distanceKm,
                    'stateId': restaurantStateId,
                    'image': data['logoImageUrl'] ?? '',
                  };
                }).where((restaurant) {
                  return restaurant['menuApproved'] != false;
                }).toList();

                final restaurants = allApprovedRestaurants.where((restaurant) {
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

                final mealsFuture = _resolveMealsFuture(restaurants);

                return FutureBuilder<List<Map<String, dynamic>>>(
                  future: mealsFuture,
                  builder: (context, mealSnapshot) {
                    final allMeals = mealSnapshot.data ?? [];
                    final mealCategoriesByRestaurant =
                        _buildMealCategoriesByRestaurant(allMeals);
                    final categoryItems = _extractCategoriesFromRestaurants(
                      restaurants,
                      mealCategoriesByRestaurant: mealCategoriesByRestaurant,
                    );

                    final featuredRestaurants =
                        allApprovedRestaurants.where((restaurant) {
                      // أعلام تحكم خاصة بقسم العروض لها الأولوية
                      final offerControl = _readBoolField(
                        restaurant,
                        const [
                          'showInOffersCarousel',
                          'showInHomeOffers',
                          'showInClientOffers',
                        ],
                      );
                      if (offerControl != null) return offerControl;

                      // hasOffers يُعيّن من Cloud Function عند وجود عروض نشطة
                      if (_restaurantHasOffer(restaurant)) return true;

                      // أعلام "مميز" العامة كاحتياطي فقط
                      return _readBoolField(
                            restaurant,
                            const ['featuredOnHome', 'featured'],
                          ) ??
                          false;
                    }).toList();

                    final List<Map<String, dynamic>> searchItems = [
                      ...restaurants.map((r) => {
                            'type': 'restaurant',
                            'name': r['name'].toString(),
                            'restaurant': r,
                          }),
                      ...allMeals,
                    ];

                    return SafeArea(
                      bottom: false,
                      child: CustomScrollView(
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                          SliverAppBar(
                            floating: true,
                            snap: true,
                            pinned: false,
                            backgroundColor: _scaffoldBg,
                            elevation: 0,
                            automaticallyImplyLeading: false,
                            expandedHeight: 112,
                            toolbarHeight: 0,
                            flexibleSpace: FlexibleSpaceBar(
                              collapseMode: CollapseMode.none,
                              background: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 4, 16, 8),
                                child: _buildTopBar(context),
                              ),
                            ),
                          ),
                          SliverPersistentHeader(
                            pinned: true,
                            delegate: _SimplePinnedDelegate(
                              height: 76,
                              child: Container(
                                color: _scaffoldBg,
                                padding:
                                    const EdgeInsets.fromLTRB(16, 4, 16, 4),
                                child: _buildSearchBar(context, searchItems),
                              ),
                            ),
                          ),
                          _buildCategoryIconsCarousel(
                            categoryItems,
                            restaurants: restaurants,
                            allMeals: allMeals,
                            mealCategoriesByRestaurant:
                                mealCategoriesByRestaurant,
                            isLoading: !mealSnapshot.hasData,
                          ),
                          if (_showHomeOffersSection ||
                              featuredRestaurants.isNotEmpty)
                            _buildOffersCarouselSection(featuredRestaurants),
                          SliverPadding(
                            padding: EdgeInsets.zero,
                            sliver: SliverMainAxisGroup(
                              slivers: [
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.fromLTRB(16, 8, 16, 4),
                                    child: _buildRestaurantSectionHeader(),
                                  ),
                                ),
                                SliverPadding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 4, 16, 16),
                                  sliver: SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (ctx, idx) {
                                        final r = restaurants[idx];
                                        final imageProvider = (r['image']
                                                    ?.toString()
                                                    .isNotEmpty ??
                                                false)
                                            ? CachedNetworkImageProvider(
                                                r['image'].toString())
                                            : null;
                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 12),
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
                              ],
                            ),
                          ),
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 120),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }, // إغلاق builder الخاص بـ StreamBuilder<QuerySnapshot>
            ), // إغلاق body: StreamBuilder
          ), // إغلاق Scaffold
        ); // إغلاق Directionality
      }, // إغلاق builder الخاص بـ StreamBuilder<bool>
    ); // إغلاق StreamBuilder<bool>
  }

  Widget _buildShimmerSkeleton() {
    final base = _isDark ? const Color(0xFF2A2A2A) : const Color(0xFFFFE4D6);
    final highlight =
        _isDark ? const Color(0xFF3A3A3A) : const Color(0xFFFFF8F3);
    Widget box({double w = double.infinity, double h = 16, double r = 12}) =>
        Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
              color: base, borderRadius: BorderRadius.circular(r)),
        );

    return SafeArea(
      bottom: false,
      child: Shimmer.fromColors(
        baseColor: base,
        highlightColor: highlight,
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // top bar
              Container(
                height: 100,
                decoration: BoxDecoration(
                    color: base, borderRadius: BorderRadius.circular(20)),
              ),
              const SizedBox(height: 12),
              // search bar
              box(h: 54, r: 18),
              const SizedBox(height: 16),
              // categories title
              Align(
                  alignment: Alignment.centerRight, child: box(w: 120, h: 18)),
              const SizedBox(height: 12),
              // categories row
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: List.generate(
                    5,
                    (i) => Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: Column(children: [
                            box(w: 56, h: 56, r: 16),
                            const SizedBox(height: 4),
                            box(w: 40, h: 10),
                          ]),
                        )),
              ),
              const SizedBox(height: 20),
              // offers title
              Align(
                  alignment: Alignment.centerRight, child: box(w: 100, h: 18)),
              const SizedBox(height: 12),
              // offers row
              Row(
                children: [
                  box(w: 220, h: 168, r: 16),
                  const SizedBox(width: 12),
                  box(w: 220, h: 168, r: 16),
                ],
              ),
              const SizedBox(height: 20),
              // filter bar
              box(h: 44, r: 22),
              const SizedBox(height: 16),
              // restaurant title
              Align(
                  alignment: Alignment.centerRight, child: box(w: 140, h: 18)),
              const SizedBox(height: 12),
              // restaurant cards
              ...List.generate(
                  3,
                  (_) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          height: 92 + 32,
                          decoration: BoxDecoration(
                              color: base,
                              borderRadius: BorderRadius.circular(20)),
                          child: Row(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      box(w: 140, h: 16),
                                      const SizedBox(height: 8),
                                      box(w: 90, h: 12),
                                      const SizedBox(height: 10),
                                      box(w: 180, h: 12),
                                      const SizedBox(height: 8),
                                      Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            box(w: 64, h: 22, r: 11),
                                            const SizedBox(width: 6),
                                            box(w: 48, h: 22, r: 11),
                                          ]),
                                    ],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(
                                    left: 14, top: 14, bottom: 14),
                                child: box(w: 92, h: 92, r: 16),
                              ),
                            ],
                          ),
                        ),
                      )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final hour = DateTime.now().hour;
    final timeGreeting = hour < 12
        ? 'صباح الخير'
        : hour < 17
            ? 'مساء الخير'
            : 'مساء النور';
    final welcomeTitle =
        _isGuest ? timeGreeting : 'أهلاً، ${_clientName ?? ''}';
    final welcomeSubtitle =
        _isGuest ? 'اطلب بسرعة وسهولة' : 'جاهز لطلبك القادم؟';

    final btnBg = _isDark ? const Color(0x1AFFFFFF) : Colors.white;
    final btnBorder =
        _isDark ? const Color(0x33FF6B00) : const Color(0x1AFF6B00);
    final btnShadow = _isDark ? Colors.transparent : const Color(0x0A000000);

    Future<void> handleLocationTap() async {
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
      await _refreshDefaultAddress();
    }

    Widget iconBtn({
      required IconData icon,
      required VoidCallback? onTap,
      Widget? badge,
    }) {
      return InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: btnBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: btnBorder),
            boxShadow: [BoxShadow(color: btnShadow, blurRadius: 6)],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(child: Icon(icon, size: 20, color: primaryColor)),
              if (badge != null) badge,
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: _isDark ? const Color(0x14FFFFFF) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isDark ? const Color(0x1AFF6B00) : const Color(0x14FF6B00),
        ),
        boxShadow: _isDark
            ? const []
            : [
                const BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 12,
                    offset: Offset(0, 4))
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              // التحية (يمين الشاشة في RTL)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    welcomeTitle,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: _textColorPrimary,
                    ),
                  ),
                  Text(
                    welcomeSubtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: _textColorSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // زر الإشعارات
              if (_isGuest)
                iconBtn(
                  icon: Icons.notifications_none_rounded,
                  onTap: _openLoginScreen,
                )
              else
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('notifications')
                      .where('userId', isEqualTo: widget.clientId)
                      .limit(50)
                      .snapshots(),
                  builder: (context, publicSnapshot) {
                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('notifications')
                          .where('clientId', isEqualTo: widget.clientId)
                          .limit(50)
                          .snapshots(),
                      builder: (context, clientIdSnapshot) {
                        return StreamBuilder<
                            QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('clients')
                              .doc(widget.clientId)
                              .collection('notifications')
                              .limit(50)
                              .snapshots(),
                          builder: (context, privateSnapshot) {
                            final publicDocs = publicSnapshot.data?.docs ??
                                const <QueryDocumentSnapshot<
                                    Map<String, dynamic>>>[];
                            final clientIdDocs = clientIdSnapshot.data?.docs ??
                                const <QueryDocumentSnapshot<
                                    Map<String, dynamic>>>[];
                            final privateDocs = privateSnapshot.data?.docs ??
                                const <QueryDocumentSnapshot<
                                    Map<String, dynamic>>>[];
                            final docsByPath = <String,
                                QueryDocumentSnapshot<Map<String, dynamic>>>{};
                            for (final doc in [
                              ...publicDocs,
                              ...clientIdDocs,
                              ...privateDocs,
                            ]) {
                              docsByPath[doc.reference.path] = doc;
                            }
                            final hasUnread = docsByPath.values
                                .any((doc) => doc.data()['isRead'] != true);
                            return iconBtn(
                              icon: Icons.notifications_none_rounded,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ClientNotificationsScreen(
                                      clientId: widget.clientId),
                                ),
                              ),
                              badge: hasUnread
                                  ? Positioned(
                                      top: 8,
                                      left: 8,
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: primaryColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    )
                                  : null,
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              const SizedBox(width: 8),
              // زر الدعم الفني
              iconBtn(
                icon: Icons.headset_mic_rounded,
                onTap: () {
                  if (_isGuest) {
                    _openLoginScreen();
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClientSupportScreen(
                        userId: widget.clientId,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          // اختيار الموقع
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: handleLocationTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color:
                    _isDark ? const Color(0x1AFFFFFF) : const Color(0xFFFFF8F3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x33FF6B00)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _currentDisplayedLocation,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: _textColorPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: ClientColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildHeroBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      height: 168,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A0800), Color(0xFF3D1A00), Color(0xFFFF6B00)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x4DFF6B00)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x40FF6B00), blurRadius: 28, offset: Offset(0, 14))
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -35,
            left: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            right: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Row(
              children: [
                const Text('🍕', style: TextStyle(fontSize: 56)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'عرض الأسبوع',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'خصومات قوية اليوم\nمن مطاعم قريبة منك',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          height: 1.18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              // التمرير لأسفل نحو قائمة المطاعم
                              Scrollable.ensureVisible(context,
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.easeOut);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'ابدأ الطلب',
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(Icons.arrow_forward_ios_rounded,
                                      size: 10, color: primaryColor),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                          const Row(
                            children: [
                              Icon(Icons.bolt_rounded,
                                  size: 14, color: Color(0xFFFFD4A8)),
                              SizedBox(width: 2),
                              Text(
                                'توصيل سريع',
                                style: TextStyle(
                                  color: Color(0xFFFFD4A8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildQuickCategoryBar(List<Map<String, dynamic>> allMeals) {
    final rawCats = _extractMealCategories(allMeals);
    if (rawCats.isEmpty) return const SizedBox.shrink();
    const allLabel = 'الكل';
    final categories = [allLabel, ...rawCats];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final cat = categories[i];
          final isSelected = cat == allLabel
              ? _selectedMealCategory == null
              : _selectedMealCategory == cat;

          return GestureDetector(
            onTap: () => setState(
                () => _selectedMealCategory = cat == allLabel ? null : cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [Color(0xFFFF6B00), Color(0xFFFF9500)],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      )
                    : null,
                color: isSelected
                    ? null
                    : (_isDark
                        ? const Color(0x1AFFFFFF)
                        : const Color(0xFFFFF8F3)),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : (_isDark
                          ? const Color(0x33FF6B00)
                          : const Color(0x33FF6B00)),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? const Color(0x40FF6B00)
                        : Colors.black.withValues(alpha: 0.04),
                    blurRadius: isSelected ? 10 : 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  cat,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : (_isDark ? Colors.white70 : const Color(0xFF444444)),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // تحسين البحث ليشمل المطاعم والوجبات
  Widget _buildSearchBar(
    BuildContext context,
    List<Map<String, dynamic>> searchItems,
  ) {
    final entries = _buildSearchEntries(searchItems);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isDark ? const Color(0x33FF6B00) : const Color(0xFFE8E8E8),
        ),
        boxShadow: [
          BoxShadow(
            color: _isDark ? const Color(0x26FF6B00) : const Color(0x0A000000),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openSearchSheet(context, entries),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _isDark
                      ? const Color(0x1AFF6B00)
                      : const Color(0xFFFFF0E6),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.search_rounded,
                  color: primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _recentSearches.isEmpty
                      ? 'ابحث عن مطعم أو صنف أو عرض'
                      : _recentSearches.first,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _textColorPrimary.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  gradient: ClientColors.primaryGradient,
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: ClientColors.primary.withValues(alpha: 0.32),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'بحث',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
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
        Icon(icon, color: primaryColor, size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
          ),
          textAlign: TextAlign.right,
        ),
      ],
    );
  }

  // ignore: unused_element
  Widget _buildOfferSectionHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            'عروض اليوم',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _textColorPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_fire_department_rounded,
                    color: primaryColor, size: 14),
                SizedBox(width: 4),
                Text(
                  'أفضل الأسعار',
                  style: TextStyle(
                    fontSize: 11,
                    color: primaryColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantSectionHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            'المطاعم القريبة منك',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: _textColorPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.storefront_rounded, color: primaryColor, size: 19),
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
    final resolvedBackground = backgroundColor ?? const Color(0x33FFFFFF);
    final resolvedForeground = foregroundColor ?? Colors.white70;

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
    final placeholderBg =
        _isDark ? const Color(0x1AFFFFFF) : const Color(0xFFFFF8F3);
    final placeholderIcon = ClientColors.primary.withValues(alpha: 0.45);
    return imageProvider != null
        ? Image(
            image: imageProvider,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: placeholderBg,
              child: Icon(Icons.broken_image, color: placeholderIcon),
            ),
          )
        : Container(
            color: placeholderBg,
            child: Icon(Icons.storefront_rounded,
                color: placeholderIcon, size: 36),
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

  // ignore: unused_element
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
            border: Border.all(color: primaryColor.withValues(alpha: 0.08)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120F172A),
                blurRadius: 22,
                offset: Offset(0, 10),
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
                              'تصفح الأصناف', _textColorPrimary),
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
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                    border:
                        Border.all(color: primaryColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'الصنف الحالي: $selected',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: _isDark ? Colors.white : primaryColor,
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
                                : primaryColor.withValues(alpha: 0.18),
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
                        color: const Color(0xFFDDDDDD),
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
                                    _textColorPrimary,
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
                                    : const Color(0xFFFFF8F3),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? primaryColor
                                      : const Color(0x33FF6B00),
                                ),
                              ),
                              child: Text(
                                category,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF555555),
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
                                style: TextStyle(color: _textColorSecondary),
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
    final imageProvider =
        imageUrl.isNotEmpty ? CachedNetworkImageProvider(imageUrl) : null;

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
              colors: [Color(0xFF1A0800), Color(0xFF2D1400)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            border: Border.all(color: const Color(0x33FF6B00)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33FF6B00),
                blurRadius: 26,
                offset: Offset(0, 14),
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
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        )
                      : Container(color: Colors.white.withValues(alpha: 0.04)),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.12),
                        Colors.black.withValues(alpha: 0.58),
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
                          color: Colors.white.withValues(alpha: 0.16),
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
                        color: Colors.white.withValues(alpha: 0.88),
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
                            color: primaryColor,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                  color: primaryColor.withValues(alpha: 0.4),
                                  blurRadius: 8),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.arrow_back_ios_new_rounded,
                                  size: 14, color: Colors.white),
                              SizedBox(width: 6),
                              Text(
                                'الدخول إلى المطعم',
                                style: TextStyle(
                                  color: Colors.white,
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
    final imageProvider =
        imageUrl.isNotEmpty ? CachedNetworkImageProvider(imageUrl) : null;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        if (restaurant.isNotEmpty) {
          _openRestaurantDetail(context, restaurant);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _isDark ? const Color(0x33FF6B00) : const Color(0x0F000000),
          ),
          boxShadow: [
            BoxShadow(
              color:
                  _isDark ? const Color(0x1AFF6B00) : const Color(0x0A000000),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
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
                                color: _isDark
                                    ? const Color(0x33FF6B00)
                                    : const Color(0xFFFFF0E6),
                                child: const Icon(
                                  Icons.fastfood_rounded,
                                  color: primaryColor,
                                ),
                              ),
                            )
                          : Container(
                              color: const Color(0x33FF6B00),
                              child: const Icon(
                                Icons.fastfood_rounded,
                                color: primaryColor,
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
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      height: 1.25,
                      color: _textColorPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    restaurantName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: _textColorSecondary,
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
                          color: primaryColor.withValues(alpha: 0.1),
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

  // ignore: unused_element
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
        width: 256,
        margin: const EdgeInsetsDirectional.only(start: 15),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isDark ? const Color(0x33FF6B00) : const Color(0x0F000000),
          ),
          boxShadow: [
            BoxShadow(
              color:
                  _isDark ? const Color(0x26FF6B00) : const Color(0x0E000000),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
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
                              Colors.black.withValues(alpha: 0.08),
                              Colors.black.withValues(alpha: 0.58),
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
                            ? openColor.withValues(alpha: 0.18)
                            : closedColor.withValues(alpha: 0.18),
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
                          backgroundColor: accentColor.withValues(alpha: 0.92),
                          foregroundColor: textColorPrimary,
                        ),
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
                                color: Colors.white.withValues(alpha: 0.9),
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
                                  ? Colors.white.withValues(alpha: 0.94)
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
                                color: Colors.white.withValues(alpha: 0.84),
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
                            ? openColor.withValues(alpha: 0.12)
                            : closedColor.withValues(alpha: 0.12),
                        foregroundColor: isOpen ? openColor : closedColor,
                      ),
                      _buildInfoPill(
                        icon: Icons.near_me_rounded,
                        text: _distanceText(r['distanceKm'] as double?),
                      ),
                      _buildInfoPill(
                        icon: Icons.star_rounded,
                        text: _restaurantRatingLabel(r),
                        backgroundColor: accentColor.withValues(alpha: 0.18),
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
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B00), Color(0xFFFF9500)],
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: primaryColor.withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4)),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.arrow_back_ios_new_rounded,
                            size: 16, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'الدخول إلى المطعم',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Spacer(),
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
    final hasOffer = _restaurantHasOffer(r);
    final ratingLabel = _restaurantRatingLabel(r);
    final distanceText = _distanceText(r['distanceKm'] as double?);
    final deliveryTime = _deliveryTimeText(r);
    final isFreeDelivery =
        r['deliveryFee'] != null && (r['deliveryFee'] as num) == 0;
    final categories = _categoriesFromRestaurantData(r);
    final category = categories.isNotEmpty ? categories.first : '';
    final dividerColor = _isDark ? Colors.white12 : Colors.black12;
    const deliveryAvailableColor = Color(0xFF66BB6A);

    return GestureDetector(
      onTap: () => _openRestaurantDetail(context, r),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // المحتوى — يمين في RTL
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // اسم المطعم
                    Text(
                      r['name']?.toString() ?? '',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: _textColorPrimary,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                    if (category.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        category,
                        style: TextStyle(
                          fontSize: 12,
                          color: _textColorSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        textAlign: TextAlign.right,
                      ),
                    ],
                    if (hoursSummary.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        hoursSummary,
                        style: TextStyle(
                          fontSize: 11,
                          color: _textColorSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                      ),
                    ],
                    const SizedBox(height: 8),
                    FutureBuilder<RouteEstimate?>(
                      future: _roadRouteToRestaurant(r),
                      builder: (context, routeSnapshot) {
                        final route = routeSnapshot.data;
                        final displayDistance = route == null
                            ? distanceText
                            : _distanceText(route.distanceKm);
                        final displayTime = route == null
                            ? deliveryTime
                            : '${route.durationMinutes} دقيقة';
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const Icon(Icons.star_rounded,
                                size: 14, color: Color(0xFFFFC107)),
                            const SizedBox(width: 3),
                            Text(
                              ratingLabel,
                              style: TextStyle(
                                fontSize: 12,
                                color: _textColorPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 10,
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              color: dividerColor,
                            ),
                            const Icon(Icons.schedule_rounded,
                                size: 13, color: ClientColors.primary),
                            const SizedBox(width: 3),
                            Text(
                              displayTime,
                              style: const TextStyle(
                                fontSize: 12,
                                color: ClientColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (displayDistance.isNotEmpty) ...[
                              Container(
                                width: 1,
                                height: 10,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                color: dividerColor,
                              ),
                              Icon(Icons.near_me_rounded,
                                  size: 12, color: _textColorSecondary),
                              const SizedBox(width: 3),
                              Text(
                                displayDistance,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _textColorSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    // الشارات: توصيل + عرض + حالة
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isOpen)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: isFreeDelivery
                                  ? openColor.withValues(alpha: 0.12)
                                  : deliveryAvailableColor.withValues(
                                      alpha: 0.16),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.directions_bike_rounded,
                                    size: 12,
                                    color: isFreeDelivery
                                        ? openColor
                                        : deliveryAvailableColor),
                                const SizedBox(width: 4),
                                Text(
                                  isFreeDelivery ? 'توصيل مجاني' : 'توصيل متاح',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isFreeDelivery
                                        ? openColor
                                        : deliveryAvailableColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: closedColor.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'مغلق حالياً',
                              style: TextStyle(
                                fontSize: 11,
                                color: closedColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        if (hasOffer) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.local_offer_rounded,
                                    size: 11, color: accentColor),
                                SizedBox(width: 4),
                                Text(
                                  'عرض',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: accentColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // الصورة — يسار في RTL
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 92,
                  height: 92,
                  child: _buildRestaurantHeroImage(imageProvider),
                ),
              ),
            ],
          ),
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

  LatLng? _restaurantLatLng(Map<String, dynamic> restaurantData) {
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
    return LatLng(restLat, restLng);
  }

  Future<RouteEstimate?> _roadRouteToRestaurant(
    Map<String, dynamic> restaurantData,
  ) async {
    final clientLat = _clientLatitude;
    final clientLng = _clientLongitude;
    final restaurant = _restaurantLatLng(restaurantData);
    if (clientLat == null || clientLng == null || restaurant == null) {
      return null;
    }
    return RouteEstimateService.estimate(
      origin: restaurant,
      destination: LatLng(clientLat, clientLng),
      timeout: const Duration(seconds: 4),
    );
  }

  String _distanceText(double? distanceKm) {
    if (distanceKm == null) return 'المسافة غير متاحة';
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()} م';
    }
    return '${distanceKm.toStringAsFixed(1)} كم';
  }

  String _deliveryTimeText(Map<String, dynamic> restaurant) {
    final custom = (restaurant['deliveryTime'] ??
            restaurant['estimatedDeliveryTime'] ??
            '')
        .toString()
        .trim();
    if (custom.isNotEmpty) return custom;
    final distanceKm = (restaurant['distanceKm'] as num?)?.toDouble();
    if (distanceKm == null) return '—';
    if (distanceKm < 2) return '15-20 دقيقة';
    if (distanceKm < 5) return '20-30 دقيقة';
    if (distanceKm < 10) return '30-45 دقيقة';
    return '45+ دقيقة';
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

  String _formatRatingValue(double value) {
    final normalized = value.toStringAsFixed(1);
    return normalized.endsWith('.0')
        ? normalized.substring(0, normalized.length - 2)
        : normalized;
  }

  String _restaurantRatingLabel(Map<String, dynamic> restaurantData) {
    final ratingValue = _restaurantRatingValue(restaurantData);
    if (ratingValue == null) return 'جديد';
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
    final restaurantId =
        (r['id'] ?? r['restaurantId'] ?? r['storeId'] ?? '').toString().trim();
    if (restaurantId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح تفاصيل المطعم حالياً')),
      );
      return;
    }
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => RestaurantDetailScreen(
          restaurantId: restaurantId,
          name: r['name']?.toString() ?? '',
          image: _restaurantDisplayImage(r),
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

  // ── كاروسيل الفئات ──────────────────────────────────────────────────────

  static const Map<String, String> _categoryEmojiMap = {
    'بيتزا': '🍕',
    'برغر': '🍔',
    'مشويات': '🥩',
    'سوشي': '🍣',
    'صحي': '🥗',
    'مشروبات': '☕',
    'حلويات': '🍰',
    'شرقي': '🍜',
    'دجاج': '🍗',
    'فراخ': '🍗',
    'سندويتشات': '🥪',
    'مأكولات بحرية': '🦐',
    'وجبات رئيسية': '🍽️',
    'فطور': '🥞',
    'مقبلات': '🥙',
    'سلطات': '🥗',
    'عصائر': '🥤',
    'قهوة': '☕',
    'آيس كريم': '🍦',
    'كيك': '🎂',
    'مكرونة': '🍝',
    'نودلز': '🍜',
    'رايس': '🍚',
    'أرز': '🍚',
    'وجبات سريعة': '🌮',
    'شاورما': '🌯',
    'كباب': '🍢',
  };

  String _emojiForCategory(String cat) =>
      _categoryEmojiMap[cat] ??
      _categoryEmojiMap.entries
          .firstWhere(
            (e) => cat.contains(e.key) || e.key.contains(cat),
            orElse: () => const MapEntry('', '🍽️'),
          )
          .value;

  bool? _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }
    return null;
  }

  bool? _readBoolField(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      if (!source.containsKey(key)) continue;
      final parsed = _parseBool(source[key]);
      if (parsed != null) return parsed;
    }
    return null;
  }

  String _restaurantOfferText(Map<String, dynamic> restaurant) {
    final candidates = [
      restaurant['offers'],
      restaurant['offerText'],
      restaurant['activeOfferText'],
      restaurant['discountLabel'],
      restaurant['promoText'],
    ];

    for (final value in candidates) {
      final text = (value ?? '').toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }
    return '';
  }

  List<Map<String, dynamic>> _restaurantOfferHighlights(
      Map<String, dynamic> restaurant) {
    final raw = restaurant['offerHighlights'];
    final list = raw is Iterable ? raw : const [];
    return list
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }

  Map<String, dynamic>? _firstRestaurantOffer(Map<String, dynamic> restaurant) {
    final highlights = _restaurantOfferHighlights(restaurant);
    return highlights.isEmpty ? null : highlights.first;
  }

  List<_OfferCarouselEntry> _offerCarouselEntries(
    List<Map<String, dynamic>> restaurants,
  ) {
    final entries = <_OfferCarouselEntry>[];

    for (final restaurant in restaurants) {
      final offers = _restaurantOfferHighlights(restaurant);
      if (offers.isEmpty) {
        if (_restaurantHasOffer(restaurant)) {
          entries.add(
            _OfferCarouselEntry(restaurant: restaurant, offer: null),
          );
        }
        continue;
      }

      for (final offer in offers) {
        entries.add(
          _OfferCarouselEntry(restaurant: restaurant, offer: offer),
        );
      }
    }

    return entries;
  }

  String _restaurantOfferImage(Map<String, dynamic> restaurant) {
    final offer = _firstRestaurantOffer(restaurant);
    return (offer?['imageUrl'] ?? '').toString().trim();
  }

  String _restaurantDisplayImage(Map<String, dynamic> restaurant) {
    final offerImage = _restaurantOfferImage(restaurant);
    if (offerImage.isNotEmpty) return offerImage;
    return (restaurant['coverImage'] ??
            restaurant['imageUrl'] ??
            restaurant['image'] ??
            '')
        .toString()
        .trim();
  }

  bool _restaurantHasOffer(Map<String, dynamic> restaurant) {
    final hasOfferFlag = _readBoolField(
      restaurant,
      const ['hasOffers', 'hasOffer', 'offerEnabled', 'hasActiveOffer'],
    );
    final activeOfferCount =
        (restaurant['activeOfferCount'] as num?)?.toInt() ?? 0;
    return (hasOfferFlag ?? false) ||
        activeOfferCount > 0 ||
        _restaurantOfferHighlights(restaurant).isNotEmpty ||
        _restaurantOfferText(restaurant).isNotEmpty;
  }

  List<String> _categoriesFromRestaurantData(Map<String, dynamic> restaurant) {
    final seen = <String>{};
    final categories = <String>[];

    void addCategory(dynamic raw) {
      final text = (raw ?? '').toString().trim();
      if (text.isEmpty) return;
      final normalized = _canonicalMealCategory(text);
      final key = _sanitizeCategoryToken(normalized);
      if (key.isEmpty) return;
      if (seen.add(key)) {
        categories.add(normalized);
      }
    }

    final rawCats = restaurant['categories'];
    if (rawCats is List) {
      for (final c in rawCats) {
        addCategory(c);
      }
    } else if (rawCats is String) {
      final parts = rawCats.split(RegExp(r'[,،/|]'));
      for (final p in parts) {
        addCategory(p);
      }
    }

    addCategory(restaurant['category']);
    addCategory(restaurant['mainCategory']);
    addCategory(restaurant['type']);

    final tags = restaurant['tags'];
    if (tags is List) {
      for (final tag in tags) {
        addCategory(tag);
      }
    }

    return categories;
  }

  Map<String, Set<String>> _buildMealCategoriesByRestaurant(
    List<Map<String, dynamic>> allMeals,
  ) {
    final map = <String, Set<String>>{};
    for (final mealEntry in allMeals) {
      final restaurant = mealEntry['restaurant'] as Map<String, dynamic>?;
      final restaurantId = (restaurant?['id'] ?? '').toString().trim();
      if (restaurantId.isEmpty) continue;

      final category = _canonicalMealCategory(
        (mealEntry['meal']?['category'] ?? mealEntry['category'] ?? '')
            .toString()
            .trim(),
      );
      if (category.isEmpty) continue;

      map.putIfAbsent(restaurantId, () => <String>{}).add(category);
    }
    return map;
  }

  List<String> _restaurantCategories(
    Map<String, dynamic> restaurant, {
    Map<String, Set<String>>? mealCategoriesByRestaurant,
  }) {
    final merged = <String>[];
    final seen = <String>{};

    void addMany(Iterable<String> items) {
      for (final item in items) {
        final key = _sanitizeCategoryToken(item);
        if (key.isEmpty) continue;
        if (seen.add(key)) {
          merged.add(item);
        }
      }
    }

    addMany(_categoriesFromRestaurantData(restaurant));
    final restaurantId = (restaurant['id'] ?? '').toString().trim();
    if (restaurantId.isNotEmpty) {
      addMany(mealCategoriesByRestaurant?[restaurantId] ?? const <String>{});
    }

    return merged;
  }

  bool _restaurantMatchesFilter(
    Map<String, dynamic> restaurant,
    String selectedFilter, {
    Map<String, Set<String>>? mealCategoriesByRestaurant,
  }) {
    final filterKey = _categoryKey(selectedFilter);
    if (filterKey.isEmpty || filterKey == _categoryKey('الكل')) {
      return true;
    }

    final categories = _restaurantCategories(
      restaurant,
      mealCategoriesByRestaurant: mealCategoriesByRestaurant,
    );

    for (final category in categories) {
      if (_categoryMatches(category, selectedFilter)) {
        return true;
      }
    }
    return false;
  }

  List<String> _extractCategoriesFromRestaurants(
      List<Map<String, dynamic>> restaurants,
      {Map<String, Set<String>>? mealCategoriesByRestaurant}) {
    final seen = <String>{};
    final result = <String>[];

    for (final r in restaurants) {
      final categories = _restaurantCategories(
        r,
        mealCategoriesByRestaurant: mealCategoriesByRestaurant,
      );
      for (final c in categories) {
        final key = _sanitizeCategoryToken(c);
        if (key.isNotEmpty && seen.add(key)) {
          result.add(c);
        }
      }
    }

    result.sort((a, b) {
      final rankCompare = _categoryRank(a).compareTo(_categoryRank(b));
      if (rankCompare != 0) return rankCompare;
      return a.compareTo(b);
    });

    return result;
  }

  Widget _buildCategoryIconsCarousel(
    List<String> categories, {
    required List<Map<String, dynamic>> restaurants,
    required List<Map<String, dynamic>> allMeals,
    required Map<String, Set<String>> mealCategoriesByRestaurant,
    bool isLoading = false,
  }) {
    if (isLoading) {
      final base = _isDark ? const Color(0xFF2A2A2A) : const Color(0xFFFFE4D6);
      final highlight =
          _isDark ? const Color(0xFF3A3A3A) : const Color(0xFFFFF8F3);
      return SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Container(
                width: 90,
                height: 16,
                decoration: BoxDecoration(
                  color: base,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            SizedBox(
              height: 82,
              child: Shimmer.fromColors(
                baseColor: base,
                highlightColor: highlight,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: 6,
                  itemBuilder: (_, __) => Padding(
                    padding: const EdgeInsetsDirectional.only(end: 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: base,
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 36,
                          height: 10,
                          decoration: BoxDecoration(
                            color: base,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // دائماً أضف "الكل" في البداية (يمين)
    final items = <(String, String)>[
      ('🏠', 'الكل'),
      ...categories.map((c) => (_emojiForCategory(c), c)),
    ];

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  'نفسك في شنو؟',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 82,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: items.length,
              itemBuilder: (ctx, i) {
                final (emoji, label) = items[i];
                return Padding(
                  padding: const EdgeInsetsDirectional.only(end: 10),
                  child: GestureDetector(
                    onTap: () => _openCategoryResults(
                      category: label,
                      restaurants: restaurants,
                      allMeals: allMeals,
                      mealCategoriesByRestaurant: mealCategoriesByRestaurant,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color:
                                  ClientColors.primary.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Center(
                            child: Text(emoji,
                                style: const TextStyle(fontSize: 24)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── كاروسيل العروض ──────────────────────────────────────────────────────

  Widget _buildOffersCarouselSection(
      List<Map<String, dynamic>> featuredRestaurants) {
    final withOffers = featuredRestaurants
        .where((r) => getRestaurantStatus(r).contains('مفتوح'))
        .toList();

    final sourceRestaurants =
        withOffers.isNotEmpty ? withOffers : featuredRestaurants;
    final displayItems = _offerCarouselEntries(sourceRestaurants);

    return SliverToBoxAdapter(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    'عروض اليوم',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: ClientColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'أفضل الأسعار',
                      style: TextStyle(
                        fontSize: 11,
                        color: ClientColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 210.0,
              child: displayItems.isEmpty
                  ? Padding(
                      padding:
                          const EdgeInsetsDirectional.only(start: 16, end: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _isDark
                              ? ClientColors.surface
                              : const Color(0xFFFFF8F3),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color(0x33FF6B00),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'لا توجد عروض متاحة الآن',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding:
                          const EdgeInsetsDirectional.only(start: 16, end: 8),
                      itemCount: displayItems.length,
                      itemBuilder: (ctx, i) {
                        final screenWidth = MediaQuery.of(ctx).size.width;
                        final cardWidth = (screenWidth * 0.42)
                            .clamp(150.0, 170.0)
                            .toDouble();
                        final item = displayItems[i];
                        final r = item.restaurant;
                        final offer = item.offer;
                        final offerImage =
                            (offer?['imageUrl'] ?? '').toString().trim();
                        final imgUrl = offerImage.isNotEmpty
                            ? offerImage
                            : _restaurantDisplayImage(r);
                        final restaurantName =
                            (r['name'] ?? '').toString().trim();
                        final offerTitle =
                            (offer?['title'] ?? '').toString().trim();
                        final offerDescription = (offer?['description'] ??
                                offer?['summaryText'] ??
                                _restaurantOfferText(r))
                            .toString()
                            .trim();
                        final badgeText =
                            (offer?['badgeText'] ?? '').toString().trim();
                        final discountType =
                            (offer?['discountType'] ?? '').toString().trim();
                        final rawValue = offer?['discountValue'];
                        final discountNum = rawValue != null
                            ? (double.tryParse(rawValue.toString()) ?? 0.0)
                            : 0.0;
                        final discountPercent =
                            (discountType == 'percent' && discountNum > 0)
                                ? '${discountNum % 1 == 0 ? discountNum.toInt() : discountNum}%'
                                : '';
                        final cardBg =
                            _isDark ? ClientColors.surface : Colors.white;
                        final mutedColor = _isDark
                            ? const Color(0xFF9E9E9E)
                            : const Color(0xFF757575);
                        return Padding(
                          padding:
                              const EdgeInsetsDirectional.only(end: 12),
                          child: GestureDetector(
                            onTap: () => _openRestaurantDetail(context, {
                              ...r,
                              if (offer != null) ...{
                                'restaurantId': offer['restaurantId'] ??
                                    r['restaurantId'],
                                'offers': offerTitle.isNotEmpty
                                    ? offerTitle
                                    : r['offers'],
                              },
                            }),
                            child: SizedBox(
                              width: cardWidth,
                              child: Material(
                                color: cardBg,
                                elevation: 3,
                                shadowColor:
                                    Colors.black.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(18),
                                clipBehavior: Clip.hardEdge,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    SizedBox(
                                      height: 118,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          imgUrl.isNotEmpty
                                              ? CachedNetworkImage(
                                                  imageUrl: imgUrl,
                                                  fit: BoxFit.cover,
                                                  errorWidget:
                                                      (_, __, ___) =>
                                                          Container(
                                                    color: _isDark
                                                        ? const Color(
                                                            0xFF24140A)
                                                        : const Color(
                                                            0xFFFFF0E6),
                                                    child: const Icon(
                                                      Icons
                                                          .local_offer_rounded,
                                                      size: 42,
                                                      color:
                                                          ClientColors.primary,
                                                    ),
                                                  ),
                                                )
                                              : Container(
                                                  color: _isDark
                                                      ? const Color(0xFF24140A)
                                                      : const Color(0xFFFFF0E6),
                                                  child: const Icon(
                                                    Icons.local_offer_rounded,
                                                    size: 44,
                                                    color: ClientColors.primary,
                                                  ),
                                                ),
                                          if (discountPercent.isNotEmpty)
                                            Positioned(
                                              bottom: 8,
                                              right: 8,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: ClientColors.primary,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          999),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withValues(
                                                              alpha: 0.30),
                                                      blurRadius: 6,
                                                      offset:
                                                          const Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: Text(
                                                  'خصم $discountPercent',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    height: 1.1,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            10, 8, 10, 8),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            if (restaurantName.isNotEmpty)
                                              Text(
                                                restaurantName,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                textAlign: TextAlign.right,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w800,
                                                  color: Theme.of(ctx)
                                                      .colorScheme
                                                      .onSurface,
                                                  height: 1.2,
                                                ),
                                              ),
                                            if (offerTitle.isNotEmpty) ...[
                                              const SizedBox(height: 3),
                                              Text(
                                                offerTitle,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                textAlign: TextAlign.right,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: ClientColors.primary,
                                                  fontWeight: FontWeight.w700,
                                                  height: 1.2,
                                                ),
                                              ),
                                            ],
                                            if (offerDescription.isNotEmpty &&
                                                offerDescription !=
                                                    offerTitle) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                offerDescription,
                                                maxLines: 2,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                textAlign: TextAlign.right,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: mutedColor,
                                                  fontWeight: FontWeight.w500,
                                                  height: 1.3,
                                                ),
                                              ),
                                            ],
                                            if (badgeText.isNotEmpty) ...[
                                              const SizedBox(height: 5),
                                              Align(
                                                alignment:
                                                    AlignmentDirectional
                                                        .centerEnd,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: ClientColors.primary
                                                        .withValues(alpha: 0.10),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            999),
                                                  ),
                                                  child: Text(
                                                    badgeText,
                                                    style: const TextStyle(
                                                      fontSize: 9,
                                                      color: ClientColors.primary,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _OfferCarouselEntry {
  const _OfferCarouselEntry({
    required this.restaurant,
    required this.offer,
  });

  final Map<String, dynamic> restaurant;
  final Map<String, dynamic>? offer;
}

class _CategoryResultsScreen extends StatelessWidget {
  const _CategoryResultsScreen({
    required this.title,
    required this.clientId,
    required this.meals,
    required this.restaurants,
  });

  final String title;
  final String clientId;
  final List<Map<String, dynamic>> meals;
  final List<Map<String, dynamic>> restaurants;

  @override
  Widget build(BuildContext context) {
    final textSecondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final totalCount = meals.length + restaurants.length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(title),
          centerTitle: true,
          foregroundColor: ClientColors.primary,
        ),
        body: totalCount == 0
            ? Center(
                child: Text(
                  'لا توجد نتائج في هذه الفئة حالياً',
                  style: TextStyle(color: textSecondary),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  if (meals.isNotEmpty) ...[
                    _CategorySectionTitle(
                      title: 'الأصناف',
                      count: meals.length,
                    ),
                    const SizedBox(height: 8),
                    ...meals.map((entry) => _CategoryMealTile(
                          entry: entry,
                          clientId: clientId,
                        )),
                    const SizedBox(height: 18),
                  ],
                  if (restaurants.isNotEmpty) ...[
                    _CategorySectionTitle(
                      title: 'مطاعم تقدم هذه الفئة',
                      count: restaurants.length,
                    ),
                    const SizedBox(height: 8),
                    ...restaurants.map((restaurant) => _CategoryRestaurantTile(
                          restaurant: restaurant,
                          clientId: clientId,
                        )),
                  ],
                ],
              ),
      ),
    );
  }
}

class _CategorySectionTitle extends StatelessWidget {
  const _CategorySectionTitle({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$count',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _CategoryMealTile extends StatelessWidget {
  const _CategoryMealTile({required this.entry, required this.clientId});

  final Map<String, dynamic> entry;
  final String clientId;

  @override
  Widget build(BuildContext context) {
    final meal = (entry['meal'] as Map<String, dynamic>?) ?? const {};
    final restaurant =
        (entry['restaurant'] as Map<String, dynamic>?) ?? const {};
    final image = (meal['imageUrl'] ?? meal['image'] ?? meal['photoUrl'] ?? '')
        .toString()
        .trim();
    final name = (meal['name'] ?? entry['name'] ?? 'صنف').toString();
    final restaurantName = (restaurant['name'] ?? '').toString();
    final price = (meal['price'] as num?)?.toStringAsFixed(0);

    return _CategoryResultShell(
      onTap: () => _openRestaurant(context, restaurant, clientId),
      imageUrl: image,
      icon: Icons.fastfood_rounded,
      title: name,
      subtitle: restaurantName,
      trailing: price == null ? null : '$price ج.س',
    );
  }
}

class _CategoryRestaurantTile extends StatelessWidget {
  const _CategoryRestaurantTile({
    required this.restaurant,
    required this.clientId,
  });

  final Map<String, dynamic> restaurant;
  final String clientId;

  @override
  Widget build(BuildContext context) {
    return _CategoryResultShell(
      onTap: () => _openRestaurant(context, restaurant, clientId),
      imageUrl: (restaurant['image'] ?? '').toString(),
      icon: Icons.storefront_rounded,
      title: (restaurant['name'] ?? 'مطعم').toString(),
      subtitle: (restaurant['offers'] ?? '').toString().trim().isEmpty
          ? 'اضغط لعرض المنيو'
          : (restaurant['offers'] ?? '').toString(),
    );
  }
}

class _CategoryResultShell extends StatelessWidget {
  const _CategoryResultShell({
    required this.onTap,
    required this.imageUrl,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final VoidCallback onTap;
  final String imageUrl;
  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0x1AFFFFFF) : Colors.white;
    final border = isDark ? const Color(0x22FF6B00) : const Color(0x12000000);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: imageUrl.isEmpty
                    ? Container(
                        width: 54,
                        height: 54,
                        color: ClientColors.primary.withValues(alpha: 0.10),
                        child: Icon(icon, color: ClientColors.primary),
                      )
                    : CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: 54,
                        height: 54,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: 54,
                          height: 54,
                          color: ClientColors.primary.withValues(alpha: 0.10),
                          child: Icon(icon, color: ClientColors.primary),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                Text(
                  trailing!,
                  style: const TextStyle(
                    color: ClientColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

void _openRestaurant(
  BuildContext context,
  Map<String, dynamic> restaurant,
  String clientId,
) {
  final restaurantId = (restaurant['id'] ?? '').toString().trim();
  if (restaurantId.isEmpty) return;
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => RestaurantDetailScreen(
        restaurantId: restaurantId,
        name: (restaurant['name'] ?? '').toString(),
        image: (restaurant['image'] ?? '').toString(),
        offers: (restaurant['offers'] ?? '').toString(),
        clientId: clientId,
      ),
    ),
  );
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final textSecondary =
        isDark ? ClientColors.textSecondary : const Color(0xFF6B6B6B);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.88,
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 56,
                height: 5,
                decoration: BoxDecoration(
                  color: textSecondary.withValues(alpha: 0.3),
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
                          icon: Icon(Icons.close_rounded, color: textSecondary),
                        ),
                        const Spacer(),
                        Text(
                          'البحث',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0x1AFFFFFF)
                            : const Color(0xFFFFF8F3),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0x4DFF6B00),
                        ),
                      ),
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          hintText: 'ابحث عن مطعم أو صنف أو عرض',
                          hintStyle: TextStyle(
                            color: textSecondary,
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
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textSecondary,
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
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 42,
                                color: textSecondary,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'لم نجد نتيجة مطابقة. جرب اسم المطعم أو اسم الصنف مباشرة.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: textSecondary,
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
                                  color: const Color(0x1AFFFFFF),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: const Color(0x33FF6B00),
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
                                                .withValues(alpha: 0.12)
                                            : ClientHomeTabStateConstants
                                                .accentColor
                                                .withValues(alpha: 0.22),
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: Icon(
                                        isMeal
                                            ? Icons.fastfood_rounded
                                            : Icons.storefront_rounded,
                                        color: textPrimary,
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
                                                          .withValues(
                                                              alpha: 0.08),
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
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w800,
                                                    color: textPrimary,
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
                                              style: TextStyle(
                                                color: textSecondary,
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
  static const Color primaryColor = ClientColors.primary;
  static const Color accentColor = ClientColors.accent;
  static const Color textColorPrimary = Colors.white;
  static const Color textColorSecondary = ClientColors.textSecondary;
}

// ── Pinned header delegate (for search bar) ──────────────────────────────────
class _SimplePinnedDelegate extends SliverPersistentHeaderDelegate {
  const _SimplePinnedDelegate({required this.child, required this.height});
  final Widget child;
  final double height;

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext ctx, double shrinkOffset, bool overlapsContent) =>
      child;

  @override
  bool shouldRebuild(_SimplePinnedDelegate old) =>
      old.height != height || old.child != child;
}
