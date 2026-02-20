import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CartItem {
  final String id;
  final String restaurantId;
  final String name;
  final String description;
  int quantity;
  final double price;

  CartItem({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.description,
    required this.quantity,
    required this.price,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'restaurantId': restaurantId,
        'name': name,
        'description': description,
        'quantity': quantity,
        'price': price,
      };

  factory CartItem.fromMap(Map<String, dynamic> m) => CartItem(
        id: m['id'] ?? '',
        restaurantId: m['restaurantId'] ?? '',
        name: m['name'] ?? '',
        description: m['description'] ?? '',
        quantity: (m['quantity'] as num?)?.toInt() ?? 1,
        price: (m['price'] as num?)?.toDouble() ?? 0.0,
      );

  @override
  bool operator ==(Object o) =>
      identical(this, o) ||
      o is CartItem && runtimeType == o.runtimeType && id == o.id;

  @override
  int get hashCode => id.hashCode;
}

class CartProvider extends ChangeNotifier {
  List<CartItem> _cartItems = [];
  String? _currentRestaurantId;
  bool _isLoading = true;

  List<CartItem> get cartItems => _cartItems;
  bool get isLoading => _isLoading;

  double get totalPrice =>
      _cartItems.fold(0.0, (sum, i) => sum + i.price * i.quantity);

  Future<void> initialize() async {
    await _loadCart();
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> addToCart(CartItem item) async {
    if (_cartItems.isEmpty) _currentRestaurantId = item.restaurantId;
    if (item.restaurantId != _currentRestaurantId) return false;
    final idx = _cartItems.indexWhere((i) => i.id == item.id);
    if (idx >= 0) _cartItems[idx].quantity++;
    else _cartItems.add(item);
    await _saveCart();
    notifyListeners();
    return true;
  }

  Future<void> removeFromCart(CartItem item) async {
    final idx = _cartItems.indexWhere((i) => i.id == item.id);
    if (idx < 0) return;
    if (_cartItems[idx].quantity > 1) _cartItems[idx].quantity--;
    else {
      _cartItems.removeAt(idx);
      if (_cartItems.isEmpty) _currentRestaurantId = null;
    }
    await _saveCart();
    notifyListeners();
  }

  Future<void> updateQuantity(String id, int qty) async {
    final idx = _cartItems.indexWhere((i) => i.id == id);
    if (idx < 0) return;
    if (qty > 0) _cartItems[idx].quantity = qty;
    else {
      _cartItems.removeAt(idx);
      if (_cartItems.isEmpty) _currentRestaurantId = null;
    }
    await _saveCart();
    notifyListeners();
  }

  Future<void> clearCart() async {
    _cartItems.clear();
    _currentRestaurantId = null;
    await _saveCart();
    notifyListeners();
  }

  // دوال مساعدة لاستخدامها في restaurant_detail_screen.dart
  Future<void> addToCartSimple(String itemId, String name, double price) =>
      addToCart(CartItem(
        id: itemId,
        restaurantId: _currentRestaurantId ?? '',
        name: name,
        description: '',
        quantity: 1,
        price: price,
      ));

  Future<void> removeOneItem(String itemId) async {
    final idx = _cartItems.indexWhere((i) => i.id == itemId);
    if (idx < 0) return;
    if (_cartItems[idx].quantity > 1) _cartItems[idx].quantity--;
    else {
      _cartItems.removeAt(idx);
      if (_cartItems.isEmpty) _currentRestaurantId = null;
    }
    await _saveCart();
    notifyListeners();
  }

  int getQuantity(String itemId) {
    final item = _cartItems.firstWhere(
      (i) => i.id == itemId,
      orElse: () => CartItem(
          id: '', restaurantId: '', name: '', description: '', quantity: 0, price: 0.0),
    );
    return item.quantity;
  }

  Future<void> _saveCart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'cart_items', jsonEncode(_cartItems.map((e) => e.toMap()).toList()));
  }

  Future<void> _loadCart() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString('cart_items');
    if (s != null && s.isNotEmpty) {
      final List decoded = jsonDecode(s);
      _cartItems = decoded.map((e) => CartItem.fromMap(e)).toList();
      if (_cartItems.isNotEmpty) {
        _currentRestaurantId = _cartItems.first.restaurantId;
      }
    }
  }
}
