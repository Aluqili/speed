import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'menu_item.dart';
import 'store_full_menu_controller.dart';

class StoreFullMenuScreen extends StatefulWidget {
  final String restaurantId;

  const StoreFullMenuScreen({Key? key, required this.restaurantId})
      : super(key: key);

  @override
  State<StoreFullMenuScreen> createState() => _StoreFullMenuScreenState();
}

class _StoreFullMenuScreenState extends State<StoreFullMenuScreen> {
  late final StoreFullMenuController controller;
  late final String _controllerTag;

  @override
  void initState() {
    super.initState();
    _controllerTag = 'store_full_menu_${widget.restaurantId}';
    if (Get.isRegistered<StoreFullMenuController>(tag: _controllerTag)) {
      Get.delete<StoreFullMenuController>(tag: _controllerTag, force: true);
    }
    controller = Get.put(
      StoreFullMenuController(restaurantId: widget.restaurantId),
      tag: _controllerTag,
    );
  }

  @override
  void dispose() {
    if (Get.isRegistered<StoreFullMenuController>(tag: _controllerTag)) {
      Get.delete<StoreFullMenuController>(tag: _controllerTag, force: true);
    }
    super.dispose();
  }

  String _sizesSummary(Map<String, double> sizes) {
    if (sizes.isEmpty) return '';
    final small = sizes['small'];
    final medium = sizes['medium'];
    final large = sizes['large'];
    final parts = <String>[];
    if (small != null) parts.add('صغير ${small.toStringAsFixed(2)}');
    if (medium != null) parts.add('وسط ${medium.toStringAsFixed(2)}');
    if (large != null) parts.add('كبير ${large.toStringAsFixed(2)}');
    return parts.join(' | ');
  }

  Future<Map<String, dynamic>?> _showEditDialog(MenuItem item) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        final singlePriceController =
            TextEditingController(text: item.price.toString());
        final smallController = TextEditingController(
            text: item.sizes['small']?.toString() ?? '');
        final mediumController = TextEditingController(
            text: item.sizes['medium']?.toString() ?? '');
        final largeController = TextEditingController(
            text: item.sizes['large']?.toString() ?? '');

        return AlertDialog(
          title: const Text('تعديل السعر/الأحجام'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: singlePriceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'سعر موحد (اختياري)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: smallController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'سعر صغير'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: mediumController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'سعر وسط'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: largeController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'سعر كبير'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                final smallText = smallController.text.trim();
                final mediumText = mediumController.text.trim();
                final largeText = largeController.text.trim();
                final hasAnySize =
                    smallText.isNotEmpty || mediumText.isNotEmpty || largeText.isNotEmpty;

                if (hasAnySize) {
                  final small =
                      double.tryParse(smallText.replaceAll(',', '.'));
                  final medium =
                      double.tryParse(mediumText.replaceAll(',', '.'));
                  final large =
                      double.tryParse(largeText.replaceAll(',', '.'));
                  if (small == null || medium == null || large == null) {
                    return;
                  }
                  if (small <= 0 || medium <= 0 || large <= 0) {
                    return;
                  }
                  Navigator.pop(context, {
                    'mode': 'sizes',
                    'sizes': {
                      'small': small,
                      'medium': medium,
                      'large': large,
                    },
                  });
                  return;
                }

                final single = double.tryParse(
                    singlePriceController.text.trim().replaceAll(',', '.'));
                if (single == null || single <= 0) {
                  return;
                }
                Navigator.pop(context, {
                  'mode': 'single',
                  'price': single,
                });
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('القائمة الكاملة'),
        backgroundColor: Colors.amber[700],
        actions: [
          TextButton.icon(
            onPressed: () async {
              await controller.sendForApproval();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم إرسال القائمة للاعتماد')),
              );
            },
            icon: const Icon(Icons.send, color: Colors.white),
            label: const Text('أرسل للاعتماد',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.menuItems.isEmpty) {
          return const Center(
              child: Text('لا توجد أصناف في القائمة حتى الآن.'));
        }
        return ListView.builder(
          itemCount: controller.menuItems.length,
          itemBuilder: (context, index) {
            final MenuItem item = controller.menuItems[index];
            return Card(
              margin: const EdgeInsets.all(8.0),
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                      ? Image.network(
                          item.imageUrl!,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 50,
                            height: 50,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image),
                          ),
                        )
                      : Container(
                          width: 50,
                          height: 50,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.fastfood, color: Colors.grey),
                        ),
                ),
                title: Text(item.name),
                subtitle: Text(
                  item.hasSizes
                      ? '${_sizesSummary(item.sizes)} - ${item.category ?? 'غير محدد'}'
                      : '${item.price.toStringAsFixed(2)} ر.س - ${item.category ?? 'غير محدد'}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: item.isAvailable,
                      activeColor: Colors.amber[700],
                      onChanged: (v) async {
                        await controller.updateAvailability(item.id, v);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              v ? 'تم تفعيل الصنف' : 'تم تعطيل الصنف',
                            ),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      tooltip: 'تعديل السعر',
                      onPressed: () async {
                        final result = await _showEditDialog(item);
                        if (result == null) return;

                        if (result['mode'] == 'sizes') {
                          final sizes =
                              Map<String, double>.from(result['sizes'] as Map);
                          await controller.updateMenuItemSizes(item.id, sizes);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم تحديث أسعار الأحجام')),
                          );
                        } else if (result['mode'] == 'single') {
                          final newPrice = result['price'] as double;
                          if (newPrice != item.price) {
                            await controller.updateMenuItemPrice(item.id, newPrice);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('تم تحديث السعر إلى $newPrice ج.س')),
                            );
                          }
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        await controller.deleteMenuItem(item.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم حذف الصنف')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
