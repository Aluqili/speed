import 'address_selection_screen.dart';
// lib/screens/client_cart_screen.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'cart_provider.dart';
import 'payment_screen.dart';

class ClientCartScreen extends StatefulWidget {
  const ClientCartScreen({Key? key}) : super(key: key);

  @override
  State<ClientCartScreen> createState() => _ClientCartScreenState();
}

class _ClientCartScreenState extends State<ClientCartScreen> {
  double _deliveryFee = 0.0;
  bool _loadingDelivery = true;
  CartProvider? _prevCart;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _calculateDeliveryFee());
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
    setState(() => _loadingDelivery = true);
    try {
      final cart = Provider.of<CartProvider?>(context, listen: false);
      if (cart == null) {
        if (mounted) {
          setState(() {
            _deliveryFee = 0.0;
            _loadingDelivery = false;
          });
        }
        return;
      }
      if (cart.cartItems.isEmpty) {
        setState(() {
          _deliveryFee = 0.0;
          _loadingDelivery = false;
        });
        return;
      }
      final user = FirebaseAuth.instance.currentUser!;
      final clientDoc = await FirebaseFirestore.instance
          .collection('clients').doc(user.uid).get();
      final addrId = clientDoc.data()?['defaultAddressId'];
      if (addrId == null) {
        setState(() {
          _deliveryFee = 0.0;
          _loadingDelivery = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى اختيار عنوان توصيل أولاً')),
        );
        return;
      }
      final addrDoc = await FirebaseFirestore.instance
          .collection('clients').doc(user.uid)
          .collection('addresses').doc(addrId).get();
      if (!addrDoc.exists) {
        setState(() {
          _deliveryFee = 0.0;
          _loadingDelivery = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('العنوان الافتراضي غير موجود، يرجى اختيار عنوان صحيح')),
        );
        return;
      }
      final addr = addrDoc.data()!;
      final clientLat = (addr['latitude'] as num).toDouble();
      final clientLng = (addr['longitude'] as num).toDouble();

      final restId = cart.cartItems.first.id.split('_').first;
      final restDoc = await FirebaseFirestore.instance
          .collection('restaurants').doc(restId).get();
      final loc = restDoc.data()?['location'];
      double? restLat;
      double? restLng;
      if (loc != null) {
        if (loc is GeoPoint) {
          restLat = loc.latitude;
          restLng = loc.longitude;
        } else if (loc is Map<String, dynamic>) {
          restLat = (loc['lat'] as num?)?.toDouble();
          restLng = (loc['lng'] as num?)?.toDouble();
        }
      }
      if (restLat == null || restLng == null) {
        throw Exception('إحداثيات المطعم غير موجودة أو غير صحيحة: loc=$loc');
      }

      double toRad(double deg) => deg * pi/180;
      final dLat = toRad(restLat - clientLat);
      final dLng = toRad(restLng - clientLng);
      final a = pow(sin(dLat/2),2)
        + cos(toRad(clientLat))*cos(toRad(restLat))*pow(sin(dLng/2),2);
      final distance = 2*asin(sqrt(a))*6371;

      double fee;
      if (distance < 2) fee=3000;
      else if (distance<7) fee=3500;
      else if (distance<14) fee=4000;
      else fee=distance.ceil()*100;

      final discount = (restDoc.data()?['deliveryDiscountPercentage'] as num?)?.toDouble();
      if (discount!=null && discount>0) fee=fee*(1-discount/100);

      setState(() {
        _deliveryFee=fee;
        _loadingDelivery=false;
      });
    } catch (e, stack) {
      print('Error calculating delivery fee: $e\n$stack');
      setState(() {
        _deliveryFee=0.0;
        _loadingDelivery=false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في حساب رسوم التوصيل: $e\n$stack')),
      );
    }
  }

  Future<void> _onCheckoutPressed(CartProvider cart) async {
    final user = FirebaseAuth.instance.currentUser!;
    // تحقق من وجود عنوان افتراضي مؤكد
    final clientDoc = await FirebaseFirestore.instance.collection('clients').doc(user.uid).get();
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
      if (selected == null) {
        // إذا لم يؤكد العميل العنوان، لا يتم الطلب
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يجب تأكيد عنوان التوصيل قبل اختيار طريقة الدفع')),
        );
        return;
      }
      // حفظ العنوان المختار كافتراضي
      await FirebaseFirestore.instance.collection('clients').doc(user.uid).update({
        'defaultAddressId': selected['addressId'],
      });
      // إعادة حساب رسوم التوصيل بعد اختيار العنوان
      await _calculateDeliveryFee();
    }
    // بعد التأكيد، أنشئ الطلب
    final items = cart.cartItems.map((i) => {
      'name': i.name,
      'description': i.description,
      'price': i.price,
      'quantity': i.quantity,
    }).toList();
    final docRef = await FirebaseFirestore.instance.collection('orders').add({
      'orderId': 'ORD-${Random().nextInt(1000000)}',
      'clientId': user.uid,
      'clientName': user.displayName ?? 'عميل',
      'items': items,
      'total': cart.totalPrice,
      'deliveryFee': _deliveryFee,
      'totalWithDelivery': cart.totalPrice + _deliveryFee,
      'status': 'pending_payment',
      'paymentStatus': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    cart.clearCart();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScreen(orderId: docRef.id),
      ),
    );
  }

  static const Color primaryColor = Color(0xFFFE724C);
  static const Color backgroundColor = Color(0xFFF5F5F5);
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
    final withDel = total + _deliveryFee;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          centerTitle: true,
          title: const Text('سلة المشتريات', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 20, fontFamily: 'Tajawal')),
          iconTheme: const IconThemeData(color: primaryColor),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
          ),
          automaticallyImplyLeading: true,
        ),
        body: _loadingDelivery
            ? const Center(child: CircularProgressIndicator())
            : cart.cartItems.isEmpty
                ? const Center(child: Text('السلة فارغة', style: TextStyle(fontSize: 18, color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: cart.cartItems.length,
                    itemBuilder: (_, i) => _buildCartItem(cart, cart.cartItems[i]),
                  ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _buildRow('قيمة الطلب', '${total.toStringAsFixed(2)} ج.س'),
            _buildRow('رسوم التوصيل', '${_deliveryFee.toStringAsFixed(2)} ج.س'),
            const Divider(),
            _buildRow('الإجمالي النهائي', '${withDel.toStringAsFixed(2)} ج.س', bold: true),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loadingDelivery ? null : () => _onCheckoutPressed(cart),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18, fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
                ),
                child: const Text('اختيار طريقة الدفع', style: TextStyle(color: Colors.white)),
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
              Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A1D26), fontFamily: 'Tajawal')),
              const SizedBox(height: 4),
              Text('${item.price.toStringAsFixed(2)} ج.س', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
            ],
          ),
        ),
        IconButton(
          onPressed: () {
            cart.removeFromCart(item);
            _calculateDeliveryFee();
          },
          icon: const Icon(Icons.remove_circle_outline), color: Colors.red),
        Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        IconButton(
          onPressed: () {
            cart.addToCart(item);
            _calculateDeliveryFee();
          },
          icon: const Icon(Icons.add_circle_outline), color: Colors.green),
      ]),
    ),
  );

  Widget _buildRow(String label, String value, {bool bold=false})=> Padding(
    padding: const EdgeInsets.symmetric(vertical:4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[
      Text(label, style: TextStyle(fontWeight: bold?FontWeight.bold:FontWeight.normal)),
      Text(value, style: TextStyle(fontWeight: bold?FontWeight.bold:FontWeight.normal)),
    ]),
  );
}
