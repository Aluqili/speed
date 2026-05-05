// lib/screens/client_cart_screen.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';
import 'package:speedstar_core/src/auth/login_screen_ar.dart';

import '../الخدمات/guest_location_service.dart';
import 'address_selection_screen.dart';
import 'cart_provider.dart';
import 'payment_screen.dart';

class ClientCartScreen extends StatefulWidget {
  const ClientCartScreen({Key? key}) : super(key: key);

  @override
  State<ClientCartScreen> createState() => _ClientCartScreenState();
}

class _ClientCartScreenState extends State<ClientCartScreen> {
  double _deliveryFee = 0.0;
  double _largeOrderFee = 0.0;
  bool _loadingDelivery = true;
  CartProvider? _prevCart;
  Timer? _deliveryFeeDebounce;
  int _deliveryFeeGeneration = 0;
  static const double _defaultMaxAllowedCrossCheckDistanceKm = 120;
  static const double _defaultLargeItemThreshold = 10000;
  static const double _defaultLargeItemFeeBase = 500;
  static const double _defaultLargeItemStepAmount = 5000;
  static const double _defaultLargeItemStepFee = 500;
  static const double _defaultLargeItemFeeCapPerUnit = 2500;
  static const double _defaultClientDeliveryBaseFee = 5000;
  static const double _defaultClientDeliveryBaseDistanceKm = 6;
  static const double _defaultClientDeliveryExtraPerKm = 700;
  static const double _defaultDeliveryPlatformMarginFixed = 700;
  static const double _defaultDeliveryPlatformMinMargin = 300;

  double get _maxAllowedCrossCheckDistanceKm {
    try {
      final value = FirebaseRemoteConfig.instance
          .getDouble('client_state_guard_distance_km');
      return value > 0 ? value : _defaultMaxAllowedCrossCheckDistanceKm;
    } catch (_) {
      return _defaultMaxAllowedCrossCheckDistanceKm;
    }
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
      return raw
          .split(RegExp(r'[,;\n|]'))
          .map(_normalizeStateId)
          .where((value) => value.isNotEmpty)
          .toSet();
    } catch (_) {
      return <String>{};
    }
  }

  bool get _largeOrderFeeEnabled {
    try {
      return FirebaseRemoteConfig.instance
          .getBool('pricing_large_item_fee_enabled');
    } catch (_) {
      return true;
    }
  }

  double get _largeItemThreshold {
    try {
      final value = FirebaseRemoteConfig.instance
          .getDouble('pricing_large_item_threshold');
      return value > 0 ? value : _defaultLargeItemThreshold;
    } catch (_) {
      return _defaultLargeItemThreshold;
    }
  }

  double get _largeItemFeeBase {
    try {
      final value = FirebaseRemoteConfig.instance
          .getDouble('pricing_large_item_fee_base');
      return value >= 0 ? value : _defaultLargeItemFeeBase;
    } catch (_) {
      return _defaultLargeItemFeeBase;
    }
  }

  double get _largeItemStepAmount {
    try {
      final value = FirebaseRemoteConfig.instance
          .getDouble('pricing_large_item_step_amount');
      return value > 0 ? value : _defaultLargeItemStepAmount;
    } catch (_) {
      return _defaultLargeItemStepAmount;
    }
  }

  double get _largeItemStepFee {
    try {
      final value = FirebaseRemoteConfig.instance
          .getDouble('pricing_large_item_step_fee');
      return value >= 0 ? value : _defaultLargeItemStepFee;
    } catch (_) {
      return _defaultLargeItemStepFee;
    }
  }

  double get _largeItemFeeCapPerUnit {
    try {
      final value = FirebaseRemoteConfig.instance
          .getDouble('pricing_large_item_fee_cap_per_unit');
      return value >= 0 ? value : _defaultLargeItemFeeCapPerUnit;
    } catch (_) {
      return _defaultLargeItemFeeCapPerUnit;
    }
  }

  double get _deliveryPlatformMarginFixed {
    try {
      final value = FirebaseRemoteConfig.instance
          .getDouble('pricing_delivery_platform_margin_fixed');
      return value >= 0 ? value : _defaultDeliveryPlatformMarginFixed;
    } catch (_) {
      return _defaultDeliveryPlatformMarginFixed;
    }
  }

  double get _deliveryPlatformMinMargin {
    try {
      final value = FirebaseRemoteConfig.instance
          .getDouble('pricing_delivery_platform_min_margin');
      return value >= 0 ? value : _defaultDeliveryPlatformMinMargin;
    } catch (_) {
      return _defaultDeliveryPlatformMinMargin;
    }
  }

  double get _clientDeliveryBaseFee {
    try {
      final value = FirebaseRemoteConfig.instance
          .getDouble('pricing_client_delivery_base_fee');
      return value >= 0 ? value : _defaultClientDeliveryBaseFee;
    } catch (_) {
      return _defaultClientDeliveryBaseFee;
    }
  }

  double get _clientDeliveryBaseDistanceKm {
    try {
      final value = FirebaseRemoteConfig.instance
          .getDouble('pricing_client_delivery_base_distance_km');
      return value >= 0 ? value : _defaultClientDeliveryBaseDistanceKm;
    } catch (_) {
      return _defaultClientDeliveryBaseDistanceKm;
    }
  }

  double get _clientDeliveryExtraPerKm {
    try {
      final value = FirebaseRemoteConfig.instance
          .getDouble('pricing_client_delivery_extra_per_km');
      return value >= 0 ? value : _defaultClientDeliveryExtraPerKm;
    } catch (_) {
      return _defaultClientDeliveryExtraPerKm;
    }
  }

  double _clientFeeByDistance(double distanceKm) {
    final safeDistance = distanceKm < 0 ? 0.0 : distanceKm;
    final baseDistance = _clientDeliveryBaseDistanceKm;
    final baseFee = _clientDeliveryBaseFee;
    final extraPerKm = _clientDeliveryExtraPerKm;

    if (safeDistance <= baseDistance) {
      return baseFee;
    }

    final extraKm = (safeDistance - baseDistance).ceil();
    return baseFee + (extraKm * extraPerKm);
  }

  double _driverFeeByDistance(double distanceKm) {
    if (distanceKm < 2) {
      return 2000;
    } else if (distanceKm < 5) {
      return 2500;
    } else if (distanceKm < 10) {
      return 3000;
    } else if (distanceKm < 14) {
      return 3500;
    }
    return distanceKm.ceil() * 250;
  }

  double _calculateLargeOrderFee(CartProvider cart) {
    if (!_largeOrderFeeEnabled || cart.cartItems.isEmpty) {
      return 0.0;
    }

    final threshold = _largeItemThreshold;
    final baseFee = _largeItemFeeBase;
    final stepAmount = _largeItemStepAmount;
    final stepFee = _largeItemStepFee;
    final cap = _largeItemFeeCapPerUnit;

    double totalFee = 0.0;
    for (final item in cart.cartItems) {
      final itemPrice = item.price;
      if (itemPrice <= threshold) {
        continue;
      }

      final steps = ((itemPrice - threshold) / stepAmount).floor() + 1;
      double unitFee = baseFee + ((steps - 1) * stepFee);
      if (cap > 0 && unitFee > cap) {
        unitFee = cap;
      }
      totalFee += unitFee * item.quantity;
    }

    return totalFee;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _calculateDeliveryFee());
  }

  @override
  void dispose() {
    _deliveryFeeDebounce?.cancel();
    _prevCart?.removeListener(_handleCartChanged);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final cart = Provider.of<CartProvider?>(context);
    if (cart == null) {
      return;
    }
    if (_prevCart != cart) {
      _prevCart?.removeListener(_handleCartChanged);
      _prevCart = cart;
      cart.addListener(_handleCartChanged);
      _calculateDeliveryFee();
    }
  }

  void _handleCartChanged() {
    if (!mounted) return;
    _deliveryFeeDebounce?.cancel();
    _deliveryFeeDebounce = Timer(const Duration(milliseconds: 600), () {
      if (mounted) _calculateDeliveryFee();
    });
  }

  Future<void> _calculateDeliveryFee() async {
    final generation = ++_deliveryFeeGeneration;
    final cart = Provider.of<CartProvider?>(context, listen: false);
    final estimatedLargeOrderFee =
        cart == null ? 0.0 : _calculateLargeOrderFee(cart);
    final user = FirebaseAuth.instance.currentUser;

    if (!mounted) {
      return;
    }
    setState(() => _loadingDelivery = true);
    try {
      if (cart == null) {
        if (mounted && generation == _deliveryFeeGeneration) {
          setState(() {
            _deliveryFee = 0.0;
            _largeOrderFee = 0.0;
            _loadingDelivery = false;
          });
        }
        return;
      }

      if (cart.cartItems.isEmpty) {
        if (generation == _deliveryFeeGeneration) {
          setState(() {
            _deliveryFee = 0.0;
            _largeOrderFee = 0.0;
            _loadingDelivery = false;
          });
        }
        return;
      }
      if (user == null || user.isAnonymous) {
        if (generation == _deliveryFeeGeneration) {
          setState(() {
            _deliveryFee = 0.0;
            _largeOrderFee = estimatedLargeOrderFee;
            _loadingDelivery = false;
          });
        }
        return;
      }
      final clientDoc = await FirebaseFirestore.instance
          .collection('clients')
          .doc(user.uid)
          .get();
      if (!mounted || generation != _deliveryFeeGeneration) {
        return;
      }
      final addrId = clientDoc.data()?['defaultAddressId'];
      if (addrId == null) {
        setState(() {
          _deliveryFee = 0.0;
          _largeOrderFee = estimatedLargeOrderFee;
          _loadingDelivery = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى اختيار عنوان توصيل أولاً')),
        );
        return;
      }
      final addrDoc = await FirebaseFirestore.instance
          .collection('clients')
          .doc(user.uid)
          .collection('addresses')
          .doc(addrId)
          .get();
      if (!mounted || generation != _deliveryFeeGeneration) {
        return;
      }
      if (!addrDoc.exists) {
        setState(() {
          _deliveryFee = 0.0;
          _largeOrderFee = estimatedLargeOrderFee;
          _loadingDelivery = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('العنوان الافتراضي غير موجود، يرجى اختيار عنوان صحيح')),
        );
        return;
      }
      final addr = addrDoc.data()!;
      final clientLat = (addr['latitude'] as num?)?.toDouble();
      final clientLng = (addr['longitude'] as num?)?.toDouble();
      if (clientLat == null || clientLng == null) {
        throw Exception('إحداثيات عنوان العميل غير مكتملة');
      }

      final restId = cart.cartItems.first.restaurantId;
      final restDoc = await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(restId)
          .get();
      if (!mounted || generation != _deliveryFeeGeneration) {
        return;
      }
      final restData = restDoc.data() ?? <String, dynamic>{};
      final loc = restData['location'];
      double? restLat;
      double? restLng;
      if (loc is GeoPoint) {
        restLat = loc.latitude;
        restLng = loc.longitude;
      } else if (loc is Map<String, dynamic>) {
        restLat = (loc['lat'] as num?)?.toDouble();
        restLng = (loc['lng'] as num?)?.toDouble();
      }

      restLat ??= (restData['latitude'] as num?)?.toDouble() ??
          (restData['lat'] as num?)?.toDouble() ??
          (restData['restaurantLat'] as num?)?.toDouble();
      restLng ??= (restData['longitude'] as num?)?.toDouble() ??
          (restData['lng'] as num?)?.toDouble() ??
          (restData['restaurantLng'] as num?)?.toDouble();

      if (restLat == null || restLng == null) {
        throw Exception('موقع المطعم غير مكتمل، يرجى تحديث عنوان المتجر');
      }

      double toRad(double deg) => deg * pi / 180;
      final dLat = toRad(restLat - clientLat);
      final dLng = toRad(restLng - clientLng);
      final a = pow(sin(dLat / 2), 2) +
          cos(toRad(clientLat)) * cos(toRad(restLat)) * pow(sin(dLng / 2), 2);
      final distance = 2 * asin(sqrt(a)) * 6371;

      final hasNewPricingKeys =
          _clientDeliveryBaseFee > 0 && _clientDeliveryBaseDistanceKm >= 0;
      final fee = hasNewPricingKeys
          ? _clientFeeByDistance(distance)
          : max(
              _driverFeeByDistance(distance) + _deliveryPlatformMinMargin,
              _driverFeeByDistance(distance) + _deliveryPlatformMarginFixed,
            );

      if (mounted && generation == _deliveryFeeGeneration) {
        setState(() {
          _deliveryFee = fee;
          _largeOrderFee = estimatedLargeOrderFee;
          _loadingDelivery = false;
        });
      }
    } on FirebaseException catch (e, stack) {
      debugPrint('Error calculating delivery fee: $e\n$stack');
      if (!mounted || generation != _deliveryFeeGeneration) {
        return;
      }
      setState(() {
        _deliveryFee = 0.0;
        _largeOrderFee = estimatedLargeOrderFee;
        _loadingDelivery = false;
      });
      final message = e.code == 'unavailable'
          ? 'تعذر الاتصال بالخادم حاليًا. تحقق من الإنترنت وحاول مرة أخرى.'
          : 'خطأ في حساب رسوم التوصيل: ${e.message ?? e.code}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e, stack) {
      debugPrint('Error calculating delivery fee: $e\n$stack');
      if (!mounted || generation != _deliveryFeeGeneration) {
        return;
      }
      setState(() {
        _deliveryFee = 0.0;
        _largeOrderFee = estimatedLargeOrderFee;
        _loadingDelivery = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في حساب رسوم التوصيل: $e')),
      );
    }
  }

  Future<User?> _ensureSignedInBeforeCheckout() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && !currentUser.isAnonymous) {
      return currentUser;
    }

    final loggedIn = await Navigator.push(
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

    if (loggedIn != true) {
      return null;
    }

    return FirebaseAuth.instance.currentUser;
  }

  Future<void> _seedAddressFromGuestLocation(String clientId) async {
    final clientDoc = await FirebaseFirestore.instance
        .collection('clients')
        .doc(clientId)
        .get();
    final defaultAddressId = clientDoc.data()?['defaultAddressId'];
    if (defaultAddressId != null) {
      return;
    }

    final savedAddressId = await GuestLocationService.saveAsClientAddress(
      clientId,
    );
    if (!mounted || savedAddressId == null) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم اعتماد موقع التصفح الحالي كعنوان التوصيل الافتراضي.'),
      ),
    );
  }

  Future<void> _onCheckoutPressed(CartProvider cart) async {
    final user = await _ensureSignedInBeforeCheckout();
    if (!mounted || user == null || user.isAnonymous) {
      return;
    }
    await _calculateDeliveryFee();
    if (!mounted) {
      return;
    }
    await _seedAddressFromGuestLocation(user.uid);
    if (!mounted) {
      return;
    }
    // تحقق من وجود عنوان افتراضي مؤكد
    final clientDoc = await FirebaseFirestore.instance
        .collection('clients')
        .doc(user.uid)
        .get();
    if (!mounted) {
      return;
    }
    final addrId = clientDoc.data()?['defaultAddressId'];
    if (addrId == null) {
      // إذا لم يؤكد العميل عنوانه، افتح شاشة اختيار العنوان
      final selected = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddressSelectionScreen(
            userId: user.uid,
            userType: 'client',
            isSelecting: true,
          ),
        ),
      );
      if (!mounted) {
        return;
      }
      if (selected == null) {
        // إذا لم يؤكد العميل العنوان، لا يتم الطلب
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('يجب تأكيد عنوان التوصيل قبل اختيار طريقة الدفع')),
        );
        return;
      }
      // حفظ العنوان المختار كافتراضي
      await FirebaseFirestore.instance
          .collection('clients')
          .doc(user.uid)
          .update({
        'defaultAddressId': selected['addressId'],
      });
      // إعادة حساب رسوم التوصيل بعد اختيار العنوان
      await _calculateDeliveryFee();
      if (!mounted) {
        return;
      }
    }

    if (cart.cartItems.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('السلة فارغة، أضف منتجات أولاً')),
      );
      return;
    }

    // بعد التأكيد، جهّز بيانات الطلب وأرسلها لشاشة الدفع (بدون إنشاء فوري)
    final refreshedClientDoc = await FirebaseFirestore.instance
        .collection('clients')
        .doc(user.uid)
        .get();
    if (!mounted) {
      return;
    }
    final defaultAddressId = refreshedClientDoc.data()?['defaultAddressId'];
    if (defaultAddressId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تحديد عنوان التوصيل أولاً')),
      );
      return;
    }

    final addressDoc = await FirebaseFirestore.instance
        .collection('clients')
        .doc(user.uid)
        .collection('addresses')
        .doc(defaultAddressId)
        .get();
    if (!mounted) {
      return;
    }
    if (!addressDoc.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('تعذر العثور على عنوان التوصيل الافتراضي')),
      );
      return;
    }
    final addressData = addressDoc.data() ?? <String, dynamic>{};
    final clientLat = (addressData['latitude'] as num?)?.toDouble();
    final clientLng = (addressData['longitude'] as num?)?.toDouble();
    final clientStateId = _normalizeStateId(
      addressData['stateId'] ??
          addressData['state'] ??
          addressData['city'] ??
          addressData['administrativeArea'],
    );
    final resolvedClientStateId = _resolveClientStateId(
      rawState: addressData['stateId'] ??
          addressData['state'] ??
          addressData['city'] ??
          addressData['administrativeArea'],
      latitude: clientLat,
      longitude: clientLng,
    );

    if (_isStateRolloutEnabled &&
        !_enabledStatesFromRemote.contains(resolvedClientStateId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_stateRolloutBlockMessage)),
      );
      return;
    }

    if (clientLat == null || clientLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('إحداثيات عنوان العميل غير مكتملة، يرجى تحديث العنوان')),
      );
      return;
    }

    final items = cart.cartItems
        .map((i) => {
              'id': i.id,
              'menuItemId': i.menuItemId,
              'name': i.name,
              if ((i.sizeKey ?? '').isNotEmpty) 'sizeKey': i.sizeKey,
              if ((i.sizeLabel ?? '').isNotEmpty) 'sizeLabel': i.sizeLabel,
              'description': i.description,
              'price': i.price,
              'quantity': i.quantity,
            })
        .toList();
    final restaurantId = cart.cartItems.first.restaurantId;

    final restDoc = await FirebaseFirestore.instance
        .collection('restaurants')
        .doc(restaurantId)
        .get();
    if (!mounted) {
      return;
    }
    final restData = restDoc.data() ?? <String, dynamic>{};
    final loc = restData['location'];
    double? restLat;
    double? restLng;
    if (loc is GeoPoint) {
      restLat = loc.latitude;
      restLng = loc.longitude;
    } else if (loc is Map<String, dynamic>) {
      restLat = (loc['lat'] as num?)?.toDouble() ??
          (loc['latitude'] as num?)?.toDouble();
      restLng = (loc['lng'] as num?)?.toDouble() ??
          (loc['longitude'] as num?)?.toDouble();
    }

    restLat ??= (restData['latitude'] as num?)?.toDouble() ??
        (restData['lat'] as num?)?.toDouble() ??
        (restData['restaurantLat'] as num?)?.toDouble();
    restLng ??= (restData['longitude'] as num?)?.toDouble() ??
        (restData['lng'] as num?)?.toDouble() ??
        (restData['restaurantLng'] as num?)?.toDouble();

    final restaurantName =
        (restData['name'] ?? restData['restaurantName'] ?? '')
            .toString()
            .trim();
    final restaurantStateId = _normalizeStateId(
      restData['stateId'] ??
          restData['state'] ??
          restData['region'] ??
          restData['city'],
    );

    if (clientStateId.isNotEmpty &&
        restaurantStateId.isNotEmpty &&
        clientStateId != restaurantStateId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'لا يمكن الطلب من مطعم خارج ولايتك الحالية. يرجى اختيار مطعم داخل نفس الولاية.'),
        ),
      );
      return;
    }

    if (restLat == null || restLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('موقع المطعم غير مكتمل، لا يمكن متابعة الطلب')),
      );
      return;
    }

    final distanceKm = _haversineKm(clientLat, clientLng, restLat, restLng);

    if (clientStateId.isNotEmpty &&
        restaurantStateId.isEmpty &&
        distanceKm > _maxAllowedCrossCheckDistanceKm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'هذا المطعم خارج نطاق ولايتك (بيانات الولاية غير مكتملة للمطعم).'),
        ),
      );
      return;
    }

    if (distanceKm > _maxAllowedCrossCheckDistanceKm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('المطعم بعيد جدًا عن موقعك الحالي، لا يمكن إكمال الطلب.'),
        ),
      );
      return;
    }

    final clientNameFromDoc = (refreshedClientDoc.data()?['name'] ??
            refreshedClientDoc.data()?['fullName'] ??
            '')
        .toString()
        .trim();
    final clientPhone = (refreshedClientDoc.data()?['phone'] ??
            refreshedClientDoc.data()?['phoneNumber'] ??
            '')
        .toString()
        .trim();

    final generatedOrderCode = 'ORD-${Random().nextInt(1000000)}';
    final currentLargeOrderFee = _largeOrderFee;

    final draftOrderData = {
      'orderId': generatedOrderCode,
      'orderNumber': generatedOrderCode,
      'clientId': user.uid,
      'clientName': clientNameFromDoc.isNotEmpty
          ? clientNameFromDoc
          : (user.displayName ?? 'عميل'),
      'clientPhone': clientPhone,
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'clientStateId': resolvedClientStateId,
      'restaurantStateId': restaurantStateId,
      'stateId': restaurantStateId.isNotEmpty
          ? restaurantStateId
          : resolvedClientStateId,
      'region': restaurantStateId.isNotEmpty
          ? restaurantStateId
          : resolvedClientStateId,
      'clientLat': clientLat,
      'clientLng': clientLng,
      'restaurantLat': restLat,
      'restaurantLng': restLng,
      'distanceKm': distanceKm,
      'clientLocation': GeoPoint(clientLat, clientLng),
      'restaurantLocation': GeoPoint(restLat, restLng),
      'items': items,
      'total': cart.totalPrice,
      'deliveryFee': _deliveryFee,
      'largeOrderFee': currentLargeOrderFee,
      'totalBeforeDiscount':
          cart.totalPrice + _deliveryFee + currentLargeOrderFee,
      'totalWithDelivery':
          cart.totalPrice + _deliveryFee + currentLargeOrderFee,
    };

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          draftOrderData: draftOrderData,
          clearCartOnSubmit: true,
        ),
      ),
    );
  }

  double _haversineKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    double toRad(double deg) => deg * pi / 180;
    final dLat = toRad(lat2 - lat1);
    final dLng = toRad(lng2 - lng1);
    final a = pow(sin(dLat / 2), 2) +
        cos(toRad(lat1)) * cos(toRad(lat2)) * pow(sin(dLng / 2), 2);
    return 2 * asin(sqrt(a)) * 6371;
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

  static const Color primaryColor = AppThemeArabic.clientPrimary;
  static const Color backgroundColor = AppThemeArabic.clientBackground;
  static const Color cardColor = Colors.white;

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider?>(context);
    if (cart == null) {
      return const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Center(
            child: Text('تعذر تحميل السلة، حاول إغلاق الصفحة وفتحها مجددًا.'),
          ),
        ),
      );
    }
    final total = cart.totalPrice;
    final displayLargeOrderFee = _largeOrderFee;
    final withDel = total + _deliveryFee + displayLargeOrderFee;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          centerTitle: true,
          title: const Text('سلة المشتريات',
              style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  fontFamily: 'Tajawal')),
          iconTheme: const IconThemeData(color: primaryColor),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
          ),
          automaticallyImplyLeading: true,
        ),
        body: cart.cartItems.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shopping_basket_outlined,
                        size: 72, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    const Text('سلتك فارغة',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1D26))),
                    const SizedBox(height: 8),
                    Text('أضف وجبات من المطاعم لتبدأ طلبك',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('تصفح المطاعم'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryColor,
                        side: const BorderSide(color: primaryColor),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: cart.cartItems.length,
                itemBuilder: (_, i) => _buildCartItem(cart, cart.cartItems[i]),
              ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // مؤشر السحب
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            _buildRow('قيمة الطلب', '${total.toStringAsFixed(2)} ج.س'),
            const SizedBox(height: 6),
            _buildRow(
              'رسوم التوصيل',
              _loadingDelivery ? null : '${_deliveryFee.toStringAsFixed(2)} ج.س',
              loading: _loadingDelivery,
            ),
            if (displayLargeOrderFee > 0) ...[
              const SizedBox(height: 6),
              _buildRow('رسوم الطلبات الكبيرة',
                  '${displayLargeOrderFee.toStringAsFixed(2)} ج.س'),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1),
            ),
            _buildRow(
              'الإجمالي النهائي',
              '${withDel.toStringAsFixed(2)} ج.س',
              bold: true,
              largeValue: true,
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed:
                    _loadingDelivery ? null : () => _onCheckoutPressed(cart),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                  textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700),
                ),
                child: _loadingDelivery
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('اختيار طريقة الدفع'),
                          const SizedBox(width: 8),
                          Text(
                            '${withDel.toStringAsFixed(2)} ج.س',
                            style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14),
                          ),
                        ],
                      ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _editItemNotes(CartProvider cart, CartItem item) async {
    final controller = TextEditingController(text: item.notes ?? '');
    await showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('ملاحظة: ${item.name}'),
          content: TextField(
            controller: controller,
            textDirection: TextDirection.rtl,
            maxLines: 3,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'مثال: بدون بصل، حار جداً...',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                controller.dispose();
                Navigator.pop(ctx);
              },
              child: const Text('إلغاء'),
            ),
            if (item.notes?.isNotEmpty == true)
              TextButton(
                onPressed: () async {
                  await cart.updateNotes(item.id, '');
                  controller.dispose();
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('حذف الملاحظة',
                    style: TextStyle(color: Colors.red)),
              ),
            ElevatedButton(
              onPressed: () async {
                await cart.updateNotes(item.id, controller.text);
                controller.dispose();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartItem(CartProvider cart, CartItem item) {
    final hasNotes = item.notes?.isNotEmpty == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.055),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // زر حذف
                GestureDetector(
                  onTap: () {
                    cart.removeFromCart(item);
                    _calculateDeliveryFee();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.delete_outline_rounded,
                        size: 18, color: Colors.red.shade400),
                  ),
                ),
                const SizedBox(width: 10),
                // اسم الصنف والسعر
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        item.name,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Color(0xFF1A1D26),
                        ),
                      ),
                      if ((item.sizeLabel ?? '').isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          'الحجم: ${item.sizeLabel}',
                          style: const TextStyle(
                              color: Color(0xFF6B7280), fontSize: 12),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        '${item.price.toStringAsFixed(2)} ج.س',
                        style: const TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // ملاحظات
                Expanded(
                  child: GestureDetector(
                    onTap: () => _editItemNotes(cart, item),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: hasNotes
                            ? const Color(0xFFFFF3EE)
                            : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: hasNotes
                              ? primaryColor.withValues(alpha: 0.25)
                              : Colors.grey.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.sticky_note_2_outlined,
                            size: 13,
                            color: hasNotes ? primaryColor : Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              hasNotes
                                  ? item.notes!
                                  : 'ملاحظة خاصة...',
                              style: TextStyle(
                                fontSize: 12,
                                color: hasNotes
                                    ? const Color(0xFF1A1D26)
                                    : Colors.grey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(Icons.edit_outlined,
                              size: 12, color: Colors.grey[400]),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // عداد الكمية
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _qtyBtn(
                        icon: Icons.add_rounded,
                        onTap: () {
                          cart.addToCart(item);
                          _calculateDeliveryFee();
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '${item.quantity}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Color(0xFF1A1D26),
                          ),
                        ),
                      ),
                      _qtyBtn(
                        icon: Icons.remove_rounded,
                        onTap: item.quantity <= 1
                            ? null
                            : () {
                                cart.removeOneItem(item.id);
                                _calculateDeliveryFee();
                              },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _qtyBtn({required IconData icon, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          icon,
          size: 16,
          color: onTap == null ? Colors.grey[300] : primaryColor,
        ),
      ),
    );
  }

  Widget _buildRow(String label, String? value,
          {bool bold = false, bool loading = false, bool largeValue = false}) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        loading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Text(
                value ?? '',
                style: TextStyle(
                  fontWeight: bold ? FontWeight.w800 : FontWeight.normal,
                  fontSize: largeValue ? 17 : 14,
                  color: bold ? const Color(0xFF1A1D26) : const Color(0xFF6B7280),
                ),
              ),
        Text(
          label,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
            fontSize: largeValue ? 15 : 14,
            color: bold ? const Color(0xFF1A1D26) : const Color(0xFF6B7280),
          ),
        ),
      ]);
}
