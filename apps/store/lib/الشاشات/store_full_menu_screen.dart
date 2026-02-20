import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'menu_item.dart';
import 'store_full_menu_controller.dart';

class StoreFullMenuScreen extends StatelessWidget {
  final String restaurantId;

  const StoreFullMenuScreen({Key? key, required this.restaurantId})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      StoreFullMenuController(restaurantId: restaurantId),
    );

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
                  '${item.price.toStringAsFixed(2)} ر.س - ${item.category ?? 'غير محدد'}',
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
                        final newPrice = await showDialog<double>(
                          context: context,
                          builder: (context) {
                            final controllerPrice = TextEditingController(text: item.price.toString());
                            return AlertDialog(
                              title: const Text('تعديل سعر الصنف'),
                              content: TextField(
                                controller: controllerPrice,
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(labelText: 'السعر الجديد'),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('إلغاء'),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    final value = double.tryParse(controllerPrice.text);
                                    if (value != null) {
                                      Navigator.pop(context, value);
                                    }
                                  },
                                  child: const Text('حفظ'),
                                ),
                              ],
                            );
                          },
                        );
                        if (newPrice != null && newPrice != item.price) {
                          await controller.updateMenuItemPrice(item.id, newPrice);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('تم تحديث السعر إلى $newPrice ج.س')),
                          );
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
