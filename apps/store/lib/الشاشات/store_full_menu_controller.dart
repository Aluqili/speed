import 'dart:async';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'menu_item.dart';

class StoreFullMenuController extends GetxController {
  String _normalizeImageUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('http://')) {
      return 'https://${trimmed.substring(7)}';
    }
    return trimmed;
  }

  String _extractImageUrl(Map<String, dynamic> data) {
    final dynamic raw =
        data['imageUrl'] ?? data['image'] ?? data['photoUrl'] ?? data['photo'];

    if (raw is String) {
      return _normalizeImageUrl(raw);
    }

    if (raw is Map<String, dynamic>) {
      final dynamic nested =
          raw['secure_url'] ?? raw['url'] ?? raw['imageUrl'] ?? raw['image'];
      if (nested is String) {
        return _normalizeImageUrl(nested);
      }
    }

    return '';
  }

  String _extractCategory(Map<String, dynamic> data) {
    final dynamic raw = data['category'] ?? data['section'] ?? data['group'];
    return (raw ?? '').toString().trim();
  }

  Future<void> _backfillMissingImages(List<MenuItem> items) async {
    final missing = items.where((i) => (i.imageUrl ?? '').trim().isEmpty).toList();
    if (missing.isEmpty) return;

    for (final item in missing) {
      final category = (item.category ?? '').trim();
      if (category.isEmpty) continue;

      try {
        final legacyDoc = await FirebaseFirestore.instance
            .collection('restaurants')
            .doc(restaurantId)
            .collection('menu')
            .doc(category)
            .collection('items')
            .doc(item.id)
            .get();

        if (!legacyDoc.exists) continue;
        final legacyData = legacyDoc.data() ?? <String, dynamic>{};
        final recoveredImage = _extractImageUrl(legacyData);
        if (recoveredImage.isEmpty) continue;

        await FirebaseFirestore.instance
            .collection('restaurants')
            .doc(restaurantId)
            .collection('full_menu')
            .doc(item.id)
            .set({
          'imageUrl': recoveredImage,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {
      }
    }
  }
  /// تحديث سعر صنف في القائمة الكاملة والقائمة المصنفة
  Future<void> updateMenuItemPrice(String itemId, double newPrice) async {
    try {
      // تحديث في full_menu
      await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(restaurantId)
          .collection('full_menu')
          .doc(itemId)
          .update({'price': newPrice});

      // تحديث في القسم المصنف إن وُجد
      final index = menuItems.indexWhere((i) => i.id == itemId);
      if (index != -1) {
        final old = menuItems[index];
        if ((old.category ?? '').isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('restaurants')
              .doc(restaurantId)
              .collection('menu')
              .doc(old.category)
              .collection('items')
              .doc(itemId)
              .update({'price': newPrice});
        }
        // تحديث العنصر محلياً
        menuItems[index] = MenuItem(
          id: old.id,
          name: old.name,
          price: newPrice,
          imageUrl: old.imageUrl,
          description: old.description,
          category: old.category,
          isAvailable: old.isAvailable,
          createdAt: old.createdAt,
        );
        menuItems.refresh();
      }
      Get.snackbar('نجاح', 'تم تحديث سعر الصنف');
    } catch (e) {
      Get.snackbar('خطأ', 'فشل في تحديث سعر الصنف');
    }
  }
  final String restaurantId;
  final RxList<MenuItem> menuItems = <MenuItem>[].obs;
  final RxBool isLoading = true.obs;
  final List<StreamSubscription> _subscriptions = [];

  StoreFullMenuController({required this.restaurantId});

  @override
  void onInit() {
    super.onInit();
    _setupRealTimeSync();
  }

  void _setupRealTimeSync() {
    isLoading.value = true;
    menuItems.clear();

    // الاستماع لتحديثات القائمة الكاملة
    final fullMenuSubscription = FirebaseFirestore.instance
        .collection('restaurants')
        .doc(restaurantId)
        .collection('full_menu')
        .snapshots()
        .listen((snapshot) {
      _processFullMenuSnapshot(snapshot);
    }, onError: (error) {
      Get.snackbar('خطأ', 'فشل تحميل القائمة: $error');
      isLoading.value = false;
    });
    _subscriptions.add(fullMenuSubscription);

    // مراقبة تغييرات التصنيفات (اختياري)
    final categoriesSubscription = FirebaseFirestore.instance
        .collection('restaurants')
        .doc(restaurantId)
        .collection('menu')
        .snapshots()
        .listen((_) {}, onError: (error) {
      Get.snackbar('خطأ', 'فشل مراقبة التصنيفات: $error');
    });
    _subscriptions.add(categoriesSubscription);
  }

  void _processFullMenuSnapshot(QuerySnapshot snapshot) {
    final newItems = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final ts = data['createdAt'] as Timestamp?;
      return MenuItem(
        id: doc.id,
        name: data['name'] as String? ?? '',
        price: (data['price'] is num)
            ? (data['price'] as num).toDouble()
            : double.tryParse('${data['price']}') ?? 0,
        imageUrl: _extractImageUrl(data),
        description: data['description'] as String? ?? '',
        category: _extractCategory(data),
        isAvailable: data['available'] as bool? ?? true,
        createdAt: ts?.toDate(),
      );
    }).toList()
      ..sort((a, b) {
        final at = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bt = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return bt.compareTo(at);
      });

    menuItems.assignAll(newItems);
    isLoading.value = false;
    _backfillMissingImages(newItems);
  }

  /// يحدِّث حالة توافر الصنف (تفعيل/تعطيل)
  Future<void> updateAvailability(String itemId, bool available) async {
    try {
      // تحديث في full_menu
      await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(restaurantId)
          .collection('full_menu')
          .doc(itemId)
          .update({'available': available});

      // تحديث في القسم المصنف إن وُجد
      final index = menuItems.indexWhere((i) => i.id == itemId);
      if (index != -1) {
        final old = menuItems[index];
        if ((old.category ?? '').isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('restaurants')
              .doc(restaurantId)
              .collection('menu')
              .doc(old.category)
              .collection('items')
              .doc(itemId)
              .update({'available': available});
        }
        // استبدال العنصر المحلي بكائن جديد
        menuItems[index] = MenuItem(
          id: old.id,
          name: old.name,
          price: old.price,
          imageUrl: old.imageUrl,
          description: old.description,
          category: old.category,
          isAvailable: available,
          createdAt: old.createdAt,
        );
        menuItems.refresh();
      }

      Get.snackbar(
        'نجاح',
        available ? 'تم تفعيل الصنف' : 'تم تعطيل الصنف',
      );
    } catch (e) {
      Get.snackbar('خطأ', 'فشل في تحديث حالة الصنف');
    }
  }

  /// يرسل القائمة للاعتماد من الأدمن
  Future<void> sendForApproval() async {
    try {
      await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(restaurantId)
          .update({
        'menuApproved': false,
        'pendingApproval': true,
        'approvalRequestedAt': FieldValue.serverTimestamp(),
      });
      Get.snackbar('نجاح', 'تم إرسال القائمة للاعتماد');
    } catch (e) {
      Get.snackbar('خطأ', 'فشل في إرسال الطلب للاعتماد');
    }
  }

  /// يحذف صنفاً من كامل القائمة والقائمة المصنفة إن وجدت
  Future<void> deleteMenuItem(String itemId) async {
    try {
      // حذف من full_menu
      await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(restaurantId)
          .collection('full_menu')
          .doc(itemId)
          .delete();

      // حذف من التصنيف إن وُجد
      final index = menuItems.indexWhere((i) => i.id == itemId);
      if (index != -1) {
        final old = menuItems[index];
        if ((old.category ?? '').isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('restaurants')
              .doc(restaurantId)
              .collection('menu')
              .doc(old.category)
              .collection('items')
              .doc(itemId)
              .delete();
        }
        menuItems.removeAt(index);
        menuItems.refresh();
      }

      Get.snackbar('نجاح', 'تم حذف الصنف');
    } catch (e) {
      Get.snackbar('خطأ', 'فشل في حذف الصنف');
    }
  }

  @override
  void onClose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    super.onClose();
  }
}
