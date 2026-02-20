import 'dart:async';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'menu_item.dart';

class StoreFullMenuController extends GetxController {
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
        .orderBy('createdAt', descending: true)
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
        price: (data['price'] ?? 0).toDouble(),
        imageUrl: data['imageUrl'] as String? ?? '',
        description: data['description'] as String? ?? '',
        category: data['category'] as String? ?? '',
        isAvailable: data['available'] as bool? ?? true,
        createdAt: ts?.toDate(),
      );
    }).toList();

    menuItems.assignAll(newItems);
    isLoading.value = false;
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
