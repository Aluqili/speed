import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart'; // إضافة استيراد Provider
import 'store_add_menu_item_screen.dart';
import 'package:speedstar_core/الخدمات/مزود_السلة.dart';

class StoreMenuScreen extends StatelessWidget {
  final String restaurantId;

  const StoreMenuScreen({super.key, required this.restaurantId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GFAppBar(
        title: const Text("قائمة الطعام"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StoreAddMenuItemScreen(restaurantId: restaurantId),
                ),
              );
            },
          )
        ],
      ),
      body: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('restaurants')
            .doc(restaurantId)
            .collection('menu')
            .get(),
        builder: (context, catSnapshot) {
          if (catSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (catSnapshot.hasError) {
            return const Center(child: Text('حدث خطأ أثناء تحميل الفئات'));
          }
          final categories = catSnapshot.data?.docs ?? [];
          if (categories.isEmpty) {
            return const Center(child: Text('لا توجد أصناف حتى الآن'));
          }
          return FutureBuilder<List<QueryDocumentSnapshot>>(
            future: _fetchAllMenuItems(categories),
            builder: (context, itemsSnapshot) {
              if (itemsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (itemsSnapshot.hasError) {
                return const Center(child: Text('حدث خطأ أثناء تحميل الأصناف'));
              }
              final items = itemsSnapshot.data ?? [];
              if (items.isEmpty) {
                return const Center(child: Text('لا توجد أصناف حتى الآن'));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final data = items[index].data() as Map<String, dynamic>;
                  final itemName = data['name'] ?? 'اسم غير متوفر';
                  final price = data['price']?.toString() ?? 'غير محدد';
                  final imageUrl = data['imageUrl'];
                  final description = data['description'] ?? '';
                  return GFCard(
                    boxFit: BoxFit.cover,
                    image: imageUrl != null
                        ? Image.network(imageUrl, height: 200, fit: BoxFit.cover)
                        : Image.asset('assets/images/placeholder_food.png', height: 200, fit: BoxFit.cover),
                    title: GFListTile(
                      titleText: itemName,
                      subTitleText: '$price جنيه',
                      icon: const Icon(Icons.fastfood, color: GFColors.PRIMARY),
                    ),
                    content: description.isNotEmpty
                        ? Text(description, textAlign: TextAlign.right)
                        : const SizedBox.shrink(),
                    buttonBar: GFButtonBar(
                      children: <Widget>[
                        GFButton(
                          onPressed: () {
                            // TODO: تعديل الصنف لاحقًا
                          },
                          text: 'تعديل',
                          color: GFColors.WARNING,
                          icon: const Icon(Icons.edit, size: 16),
                        ),
                        GFButton(
                          onPressed: () {
                            // TODO: حذف الصنف لاحقًا
                          },
                          text: 'حذف',
                          color: GFColors.DANGER,
                          icon: const Icon(Icons.delete, size: 16),
                        ),
                        GFButton(
                          onPressed: () {
                            final cartProvider = Provider.of<CartProvider>(context, listen: false);
                            final itemId = items[index].id;
                            cartProvider.addToCartSimple(
                              itemId,
                              itemName,
                              double.tryParse(price) ?? 0,
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم إضافة الصنف إلى السلة')),
                            );
                          },
                          text: 'إضافة إلى السلة',
                          color: GFColors.SUCCESS,
                          icon: const Icon(Icons.add_shopping_cart, size: 16),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<List<QueryDocumentSnapshot>> _fetchAllMenuItems(List<QueryDocumentSnapshot> categories) async {
    List<QueryDocumentSnapshot> allItems = [];
    for (final cat in categories) {
      final itemsSnap = await cat.reference.collection('items').get();
      allItems.addAll(itemsSnap.docs);
    }
    return allItems;
  }
}
