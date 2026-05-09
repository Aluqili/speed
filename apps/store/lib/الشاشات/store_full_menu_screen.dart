import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';
import 'menu_item.dart';
import 'store_add_menu_item_screen.dart';
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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _availableOnly = false;

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
    _searchController.dispose();
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

  Iterable<MenuItem> _filteredItems() {
    return controller.menuItems.where((item) {
      final matchesAvailability = !_availableOnly || item.isAvailable;
      final query = _searchQuery.trim().toLowerCase();
      final matchesQuery = query.isEmpty ||
          item.name.toLowerCase().contains(query) ||
          (item.category ?? '').toLowerCase().contains(query);
      return matchesAvailability && matchesQuery;
    });
  }

  Widget _summaryChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('القائمة الكاملة'),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await controller.sendForApproval();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم إرسال القائمة للاعتماد')),
              );
            },
            icon: const Icon(Icons.send, color: AppThemeArabic.storePrimary),
            label: const Text('أرسل للاعتماد',
                style: TextStyle(
                  color: AppThemeArabic.storePrimary,
                  fontWeight: FontWeight.w800,
                )),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        final filteredItems = _filteredItems().toList();

        if (controller.menuItems.isEmpty) {
          return const Center(
              child: Text('لا توجد أصناف في القائمة حتى الآن.'));
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      _summaryChip(
                        'إجمالي الأصناف',
                        '${controller.menuItems.length}',
                        AppThemeArabic.storePrimary,
                      ),
                      const SizedBox(width: 10),
                      _summaryChip(
                        'المتاحة الآن',
                        '${controller.menuItems.where((e) => e.isAvailable).length}',
                        Colors.green,
                      ),
                      const SizedBox(width: 10),
                      _summaryChip(
                        'المخفية',
                        '${controller.menuItems.where((e) => !e.isAvailable).length}',
                        Colors.orange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'ابحث باسم الصنف أو الفئة',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                              icon: const Icon(Icons.close),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilterChip(
                      selected: _availableOnly,
                      label: const Text('عرض الأصناف المتاحة فقط'),
                      onSelected: (value) => setState(() => _availableOnly = value),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: filteredItems.isEmpty
                  ? const Center(child: Text('لا توجد نتائج مطابقة'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        final MenuItem item = filteredItems[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                                          ? Image.network(
                                              item.imageUrl!,
                                              width: 84,
                                              height: 84,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Container(
                                                width: 84,
                                                height: 84,
                                                color: Colors.grey.shade200,
                                                child: const Icon(Icons.broken_image),
                                              ),
                                            )
                                          : Container(
                                              width: 84,
                                              height: 84,
                                              color: Colors.grey.shade200,
                                              child: const Icon(Icons.fastfood, color: Colors.grey),
                                            ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 17,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              Chip(
                                                label: Text(item.category ?? 'غير محدد'),
                                              ),
                                              Chip(
                                                backgroundColor: item.isAvailable
                                                    ? Colors.green.withValues(alpha: 0.12)
                                                    : Colors.orange.withValues(alpha: 0.12),
                                                label: Text(
                                                  item.isAvailable ? 'متاح' : 'مخفي',
                                                  style: TextStyle(
                                                    color: item.isAvailable ? Colors.green : Colors.orange,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            item.hasSizes
                                                ? _sizesSummary(item.sizes)
                                                : '${item.price.toStringAsFixed(2)} ج.س',
                                            style: TextStyle(
                                              color: AppThemeArabic.storePrimary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => StoreAddMenuItemScreen(
                                                restaurantId: widget.restaurantId,
                                                itemId: item.id,
                                                initialName: item.name,
                                                initialPrice: item.hasSizes ? null : item.price,
                                                initialSizes: item.hasSizes ? item.sizes : null,
                                                initialCategory: item.category,
                                                initialImageUrl: item.imageUrl,
                                                initialAvailable: item.isAvailable,
                                              ),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.edit_outlined),
                                        label: const Text('تعديل شامل'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton.filledTonal(
                                      onPressed: () async {
                                        await controller.updateAvailability(item.id, !item.isAvailable);
                                      },
                                      icon: Icon(item.isAvailable ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton.filledTonal(
                                      onPressed: () async {
                                        await controller.deleteMenuItem(item.id);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('تم حذف الصنف')),
                                          );
                                        }
                                      },
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.red.withValues(alpha: 0.12),
                                      ),
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      }),
    );
  }
}
