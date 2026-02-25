import 'address_selection_screen.dart';
// lib/screens/client_cart_screen.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';

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
  static const double _defaultMaxAllowedCrossCheckDistanceKm = 120;
  static const double _defaultLargeItemThreshold = 10000;
  static const double _defaultLargeItemFeeBase = 500;
  static const double _defaultLargeItemStepAmount = 5000;
  static const double _defaultLargeItemStepFee = 500;
  static const double _defaultLargeItemFeeCapPerUnit = 2500;
  static const double _defaultDeliveryPlatformMarginFixed = 700;
  static const double _defaultDeliveryPlatformMinMargin = 300;

  double get _maxAllowedCrossCheckDistanceKm {
    try {
      final value =
          FirebaseRemoteConfig.instance.getDouble('client_state_guard_distance_km');
      return value > 0 ? value : _defaultMaxAllowedCrossCheckDistanceKm;
    } catch (_) {
      return _defaultMaxAllowedCrossCheckDistanceKm;
    }
  }

  bool get _isStateRolloutEnabled {
    try {
      return FirebaseRemoteConfig.instance.getBool('client_state_rollout_enabled');
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
      return FirebaseRemoteConfig.instance.getBool('pricing_large_item_fee_enabled');
    } catch (_) {
      return true;
    }
  }

  double get _largeItemThreshold {
    try {
      final value = FirebaseRemoteConfig.instance.getDouble('pricing_large_item_threshold');
      return value > 0 ? value : _defaultLargeItemThreshold;
    } catch (_) {
      return _defaultLargeItemThreshold;
    }
  }

  double get _largeItemFeeBase {
    try {
      final value = FirebaseRemoteConfig.instance.getDouble('pricing_large_item_fee_base');
      return value >= 0 ? value : _defaultLargeItemFeeBase;
    } catch (_) {
      return _defaultLargeItemFeeBase;
    }
  }

  double get _largeItemStepAmount {
    try {
      final value = FirebaseRemoteConfig.instance.getDouble('pricing_large_item_step_amount');
      return value > 0 ? value : _defaultLargeItemStepAmount;
    } catch (_) {
      return _defaultLargeItemStepAmount;
    }
  }

  double get _largeItemStepFee {
    try {
      final value = FirebaseRemoteConfig.instance.getDouble('pricing_large_item_step_fee');
      return value >= 0 ? value : _defaultLargeItemStepFee;
    } catch (_) {
      return _defaultLargeItemStepFee;
    }
  }

  double get _largeItemFeeCapPerUnit {
    try {
      final value = FirebaseRemoteConfig.instance.getDouble('pricing_large_item_fee_cap_per_unit');
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
    final capPerUnit = _largeItemFeeCapPerUnit;

    double totalFee = 0;
    for (final item in cart.cartItems) {
      final unitPrice = item.price;
      if (unitPrice <= threshold) continue;

      final steps = ((unitPrice - threshold) / stepAmount).floor() + 1;
      double unitFee = baseFee + ((steps - 1) * stepFee);
      if (capPerUnit > 0 && unitFee > capPerUnit) {
        unitFee = capPerUnit;
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final cart = Provider.of<CartProvider?>(context);
    if (cart == null) {
      return;
    }
    if (_prevCart != cart) {
      _prevCart = cart;
      _calculateDeliveryFee();
    }
  }

  Future<void> _calculateDeliveryFee() async {
    if (!mounted) {
      return;
    }
    setState(() => _loadingDelivery = true);
    try {
      final cart = Provider.of<CartProvider?>(context, listen: false);
      if (cart == null) {
        if (mounted) {
          setState(() {
            _deliveryFee = 0.0;
            _largeOrderFee = 0.0;
            _loadingDelivery = false;
          });
        }
        return;
      }

      final estimatedLargeOrderFee = _calculateLargeOrderFee(cart);

      if (cart.cartItems.isEmpty) {
        setState(() {
          _deliveryFee = 0.0;
          _largeOrderFee = 0.0;
          _loadingDelivery = false;
        });
        return;
      }
      final user = FirebaseAuth.instance.currentUser!;
      final clientDoc = await FirebaseFirestore.instance
          .collection('clients')
          .doc(user.uid)
          .get();
      if (!mounted) {
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
      if (!mounted) {
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

      final restId = cart.cartItems.first.id.split('_').first;
      final restDoc = await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(restId)
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

      final driverFee = _driverFeeByDistance(distance);
      final minimumMargin = _deliveryPlatformMinMargin;
      final targetMargin = _deliveryPlatformMarginFixed;
      final fee = max(
        driverFee + minimumMargin,
        driverFee + targetMargin,
      );

      setState(() {
        _deliveryFee = fee;
        _largeOrderFee = estimatedLargeOrderFee;
        _loadingDelivery = false;
      });
    } on FirebaseException catch (e, stack) {
      debugPrint('Error calculating delivery fee: $e\n$stack');
      if (!mounted) {
        return;
      }
      setState(() {
        _deliveryFee = 0.0;
        _largeOrderFee = 0.0;
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
      if (!mounted) {
        return;
      }
      setState(() {
        _deliveryFee = 0.0;
        _largeOrderFee = 0.0;
        _loadingDelivery = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في حساب رسوم التوصيل: $e')),
      );
    }
  }

  Future<void> _onCheckoutPressed(CartProvider cart) async {
    final user = FirebaseAuth.instance.currentUser!;
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
        const SnackBar(content: Text('تعذر العثور على عنوان التوصيل الافتراضي')),
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

    if (_isStateRolloutEnabled && !_enabledStatesFromRemote.contains(clientStateId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_stateRolloutBlockMessage)),
      );
      return;
    }

    if (clientLat == null || clientLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('إحداثيات عنوان العميل غير مكتملة، يرجى تحديث العنوان')),
      );
      return;
    }

    final items = cart.cartItems
        .map((i) => {
              'name': i.name,
              'description': i.description,
              'price': i.price,
              'quantity': i.quantity,
            })
        .toList();
    final restaurantId = cart.cartItems.first.id.split('_').first;

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

    final restaurantName = (restData['name'] ?? restData['restaurantName'] ?? '')
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
          content: Text('لا يمكن الطلب من مطعم خارج ولايتك الحالية. يرجى اختيار مطعم داخل نفس الولاية.'),
        ),
      );
      return;
    }

    if (restLat == null || restLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('موقع المطعم غير مكتمل، لا يمكن متابعة الطلب')),
      );
      return;
    }

    final distanceKm = _haversineKm(clientLat, clientLng, restLat, restLng);

    if (clientStateId.isNotEmpty &&
        restaurantStateId.isEmpty &&
        distanceKm > _maxAllowedCrossCheckDistanceKm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('هذا المطعم خارج نطاق ولايتك (بيانات الولاية غير مكتملة للمطعم).'),
        ),
      );
      return;
    }

    if (distanceKm > _maxAllowedCrossCheckDistanceKm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('المطعم بعيد جدًا عن موقعك الحالي، لا يمكن إكمال الطلب.'),
        ),
      );
      return;
    }

    final clientNameFromDoc =
        (refreshedClientDoc.data()?['name'] ?? refreshedClientDoc.data()?['fullName'] ?? '')
            .toString()
            .trim();
    final clientPhone =
        (refreshedClientDoc.data()?['phone'] ?? refreshedClientDoc.data()?['phoneNumber'] ?? '')
            .toString()
            .trim();

    final draftOrderData = {
      'orderId': 'ORD-${Random().nextInt(1000000)}',
      'clientId': user.uid,
      'clientName': clientNameFromDoc.isNotEmpty
          ? clientNameFromDoc
          : (user.displayName ?? 'عميل'),
      'clientPhone': clientPhone,
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'clientStateId': clientStateId,
      'restaurantStateId': restaurantStateId,
      'stateId': restaurantStateId.isNotEmpty ? restaurantStateId : clientStateId,
      'region': restaurantStateId.isNotEmpty ? restaurantStateId : clientStateId,
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
      'largeOrderFee': _largeOrderFee,
      'totalWithDelivery': cart.totalPrice + _deliveryFee + _largeOrderFee,
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
    final withDel = total + _deliveryFee + _largeOrderFee;

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
        body: _loadingDelivery
            ? const Center(child: CircularProgressIndicator())
            : cart.cartItems.isEmpty
                ? const Center(
                    child: Text('السلة فارغة',
                        style: TextStyle(fontSize: 18, color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: cart.cartItems.length,
                    itemBuilder: (_, i) =>
                        _buildCartItem(cart, cart.cartItems[i]),
                  ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _buildRow('قيمة الطلب', '${total.toStringAsFixed(2)} ج.س'),
            _buildRow('رسوم التوصيل', '${_deliveryFee.toStringAsFixed(2)} ج.س'),
            if (_largeOrderFee > 0)
              _buildRow('رسوم الطلبات الكبيرة', '${_largeOrderFee.toStringAsFixed(2)} ج.س'),
            const Divider(),
            _buildRow('الإجمالي النهائي', '${withDel.toStringAsFixed(2)} ج.س',
                bold: true),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _loadingDelivery ? null : () => _onCheckoutPressed(cart),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                      fontSize: 18,
                      fontFamily: 'Tajawal',
                      fontWeight: FontWeight.bold),
                ),
                child: const Text('اختيار طريقة الدفع',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildCartItem(CartProvider cart, CartItem item) => Card(
        margin: const EdgeInsets.only(bottom: 16),
        color: cardColor,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF1A1D26),
                          fontFamily: 'Tajawal')),
                  const SizedBox(height: 4),
                  Text('${item.price.toStringAsFixed(2)} ج.س',
                      style: const TextStyle(
                          color: Color(0xFF6B7280), fontSize: 14)),
                ],
              ),
            ),
            IconButton(
                onPressed: () {
                  cart.removeFromCart(item);
                  _calculateDeliveryFee();
                },
                icon: const Icon(Icons.remove_circle_outline),
                color: Colors.red),
            Text('${item.quantity}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            IconButton(
                onPressed: () {
                  cart.addToCart(item);
                  _calculateDeliveryFee();
                },
                icon: const Icon(Icons.add_circle_outline),
                color: Colors.green),
          ]),
        ),
      );

  Widget _buildRow(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ]),
      );
}
