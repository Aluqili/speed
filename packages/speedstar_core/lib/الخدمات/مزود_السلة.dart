import 'package:flutter/foundation.dart';

class CartItem {
  final String id;
  final String name;
  final double price;
  int quantity;

  CartItem({required this.id, required this.name, required this.price, this.quantity = 1});
}

class CartProvider extends ChangeNotifier {
  final Map<String, CartItem> _items = {};

  Map<String, CartItem> get items => _items;

  List<CartItem> get cartItems => _items.values.toList();

  int getQuantity(String id) => _items[id]?.quantity ?? 0;

  double get totalPrice => _items.values.fold(0.0, (sum, item) => sum + item.price * item.quantity);

  void addToCartSimple(String id, String name, double price) {
    final existing = _items[id];
    if (existing != null) {
      existing.quantity += 1;
    } else {
      _items[id] = CartItem(id: id, name: name, price: price, quantity: 1);
    }
    notifyListeners();
  }

  void removeOneItem(String id) {
    final existing = _items[id];
    if (existing == null) return;
    if (existing.quantity > 1) {
      existing.quantity -= 1;
    } else {
      _items.remove(id);
    }
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
