import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart'; // إضافة استيراد Provider
import 'store_add_menu_item_screen.dart';
import 'package:speedstar_core/الخدمات/مزود_السلة.dart';

class StoreMenuScreen extends StatelessWidget {
  final String restaurantId;

  const StoreMenuScreen({super.key, required this.restaurantId});

  Map<String, double> _extractSizes(Map<String, dynamic> data) {
    final raw = data['sizes'];
    if (raw is! Map) return const {};

    final result = <String, double>{};
    for (final entry in raw.entries) {
      final parsed = entry.value is num
          ? (entry.value as num).toDouble()
          : double.tryParse(entry.value.toString().trim().replaceAll(',', '.'));
      if (parsed != null && parsed > 0) {
        result[entry.key.toString()] = parsed;
      }
    }
    return result;
  }

  Future<void> _deleteItem(
    BuildContext context,
    QueryDocumentSnapshot itemDoc,
    Map<String, dynamic> data,
  ) async {
    final category = (data['category'] ?? '').toString().trim();
    if (category.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حذف الصنف لأن فئته غير معروفة')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('حذف الصنف'),
            content: Text('هل تريد حذف الصنف ${(data['name'] ?? '').toString()}؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('إلغاء'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('حذف'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    final restaurantRef = FirebaseFirestore.instance
        .collection('restaurants')
        .doc(restaurantId);
    await restaurantRef.collection('full_menu').doc(itemDoc.id).delete();
    await restaurantRef
        .collection('menu')
        .doc(category.replaceAll('/', '-'))
        .collection('items')
        .doc(itemDoc.id)
        .delete();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف الصنف')),
      );
    }
  }

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
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StoreAddMenuItemScreen(
                                  restaurantId: restaurantId,
                                  itemId: items[index].id,
                                  initialName: itemName.toString(),
                                  initialPrice: (data['price'] as num?)?.toDouble(),
                                  initialSizes: _extractSizes(data),
                                  initialCategory:
                                      (data['category'] ?? '').toString(),
                                  initialImageUrl:
                                      (imageUrl ?? '').toString(),
                                  initialAvailable: data['available'] != false,
                                ),
                              ),
                            );
                          },
                          text: 'تعديل',
                          color: GFColors.WARNING,
                          icon: const Icon(Icons.edit, size: 16),
                        ),
                        GFButton(
                          onPressed: () async {
                            await _deleteItem(context, items[index], data);
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
