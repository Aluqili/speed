import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../الخدمات/مزود_السلة.dart';

class CartScreenArabic extends StatelessWidget {
  const CartScreenArabic({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final items = cart.cartItems;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('سلة الطلب')),
        body: items.isEmpty
            ? const Center(child: Text('السلة فارغة'))
            : ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 0),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ListTile(
                    title: Text(item.name, textAlign: TextAlign.right),
                    subtitle: Text('${item.price.toStringAsFixed(2)} × ${item.quantity}', textAlign: TextAlign.right),
                    trailing: Text((item.price * item.quantity).toStringAsFixed(2)),
                    leading: IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => cart.removeOneItem(item.id),
                    ),
                  );
                },
              ),
        bottomNavigationBar: items.isEmpty
            ? null
            : Padding(
                padding: const EdgeInsets.all(12),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: Text('تأكيد الطلب — الإجمالي: ${cart.totalPrice.toStringAsFixed(2)}'),
                  onPressed: () {
                    // Placeholder for confirming the order flow.
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم تأكيد الطلب')),
                    );
                    cart.clear();
                    Navigator.pop(context);
                  },
                ),
              ),
      ),
    );
  }
}
