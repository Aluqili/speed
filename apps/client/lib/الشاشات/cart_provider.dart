import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CartItem {
  final String id;
  final String restaurantId;
  final String menuItemId;
  final String? sizeKey;
  final String? sizeLabel;
  final String name;
  final String description;
  int quantity;
  final double price;
  String? notes;

  CartItem({
    required this.id,
    required this.restaurantId,
    this.menuItemId = '',
    this.sizeKey,
    this.sizeLabel,
    required this.name,
    required this.description,
    required this.quantity,
    required this.price,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'restaurantId': restaurantId,
        'menuItemId': menuItemId,
        'sizeKey': sizeKey,
        'sizeLabel': sizeLabel,
        'name': name,
        'description': description,
        'quantity': quantity,
        'price': price,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
      };

  factory CartItem.fromMap(Map<String, dynamic> m) => CartItem(
        id: m['id'] ?? '',
        restaurantId: m['restaurantId'] ?? '',
        menuItemId: m['menuItemId'] ?? '',
        sizeKey: m['sizeKey']?.toString(),
        sizeLabel: m['sizeLabel']?.toString(),
        name: m['name'] ?? '',
        description: m['description'] ?? '',
        quantity: (m['quantity'] as num?)?.toInt() ?? 1,
        price: (m['price'] as num?)?.toDouble() ?? 0.0,
        notes: m['notes']?.toString(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

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
    if (_cartItems.isEmpty) {
      _currentRestaurantId = item.restaurantId;
    }
    if (item.restaurantId != _currentRestaurantId) return false;
    final idx = _cartItems.indexWhere((i) => i.id == item.id);
    if (idx >= 0) {
      _cartItems[idx].quantity++;
    } else {
      _cartItems.add(item);
    }
    await _saveCart();
    notifyListeners();
    return true;
  }

  Future<void> removeFromCart(CartItem item) async {
    final idx = _cartItems.indexWhere((i) => i.id == item.id);
    if (idx < 0) return;
    if (_cartItems[idx].quantity > 1) {
      _cartItems[idx].quantity--;
    } else {
      _cartItems.removeAt(idx);
      if (_cartItems.isEmpty) {
        _currentRestaurantId = null;
      }
    }
    await _saveCart();
    notifyListeners();
  }

  Future<void> updateQuantity(String id, int qty) async {
    final idx = _cartItems.indexWhere((i) => i.id == id);
    if (idx < 0) return;
    if (qty > 0) {
      _cartItems[idx].quantity = qty;
    } else {
      _cartItems.removeAt(idx);
      if (_cartItems.isEmpty) {
        _currentRestaurantId = null;
      }
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
  Future<void> addToCartSimple(
          String restaurantId, String itemId, String name, double price,
          {String? menuItemId, String? sizeKey, String? sizeLabel, String? notes}) =>
      addToCart(CartItem(
        id: itemId,
        restaurantId: restaurantId,
        menuItemId: (menuItemId ?? '').trim(),
        sizeKey: sizeKey,
        sizeLabel: sizeLabel,
        name: name,
        description: '',
        quantity: 1,
        price: price,
        notes: notes,
      ));

  Future<void> updateNotes(String itemId, String notes) async {
    final idx = _cartItems.indexWhere((i) => i.id == itemId);
    if (idx < 0) return;
    _cartItems[idx].notes = notes.trim().isEmpty ? null : notes.trim();
    await _saveCart();
    notifyListeners();
  }

  Future<void> removeOneItem(String itemId) async {
    final idx = _cartItems.indexWhere((i) => i.id == itemId);
    if (idx < 0) return;
    if (_cartItems[idx].quantity > 1) {
      _cartItems[idx].quantity--;
    } else {
      _cartItems.removeAt(idx);
      if (_cartItems.isEmpty) {
        _currentRestaurantId = null;
      }
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

  int getQuantityByMenuItem(String restaurantId, String menuItemId) {
    if (menuItemId.trim().isEmpty) return 0;
    return _cartItems
        .where((i) =>
            i.restaurantId == restaurantId &&
            (i.menuItemId == menuItemId || i.id.contains('_$menuItemId')))
        .fold<int>(0, (sum, i) => sum + i.quantity);
  }

      List<CartItem> variantsForMenuItem(String restaurantId, String menuItemId) {
      if (menuItemId.trim().isEmpty) return const [];
      return _cartItems
        .where((i) =>
          i.restaurantId == restaurantId &&
          (i.menuItemId == menuItemId || i.id.contains('_$menuItemId')))
        .toList();
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
