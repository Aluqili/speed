import 'package:flutter/material.dart';

class SpeedstarBusinessTypeConfig {
  const SpeedstarBusinessTypeConfig({
    required this.type,
    required this.label,
    required this.placeLabel,
    required this.itemLabel,
    required this.itemsLabel,
    required this.menuLabel,
    required this.searchHint,
    required this.notesHint,
    required this.closedLabel,
    required this.newPlaceLabel,
    required this.icon,
    required this.categories,
  });

  final String type;
  final String label;
  final String placeLabel;
  final String itemLabel;
  final String itemsLabel;
  final String menuLabel;
  final String searchHint;
  final String notesHint;
  final String closedLabel;
  final String newPlaceLabel;
  final IconData icon;
  final List<String> categories;

  static const restaurant = SpeedstarBusinessTypeConfig(
    type: 'restaurant',
    label: 'مطعم',
    placeLabel: 'المطعم',
    itemLabel: 'صنف',
    itemsLabel: 'الأصناف',
    menuLabel: 'المنيو',
    searchHint: 'ابحث في القائمة...',
    notesHint: 'مثال: بدون بصل، حار جداً...',
    closedLabel: 'المطعم مغلق',
    newPlaceLabel: 'مطعم جديد',
    icon: Icons.restaurant_rounded,
    categories: [
      'كل الأصناف',
      'الوجبات الرئيسية',
      'الوجبات',
      'السندويتشات',
      'البرغر',
      'البيتزا',
      'المقبلات',
      'الشوربات',
      'المشروبات',
      'الحلويات',
      'السلطات',
      'الإضافات',
      'الفطور',
      'أصناف أخرى',
    ],
  );

  static const grocery = SpeedstarBusinessTypeConfig(
    type: 'grocery',
    label: 'بقالة',
    placeLabel: 'البقالة',
    itemLabel: 'منتج',
    itemsLabel: 'المنتجات',
    menuLabel: 'المنتجات',
    searchHint: 'ابحث عن منتج...',
    notesHint: 'مثال: بديل مناسب عند عدم التوفر...',
    closedLabel: 'البقالة مغلقة',
    newPlaceLabel: 'بقالة جديدة',
    icon: Icons.local_grocery_store_rounded,
    categories: [
      'كل الأصناف',
      'مواد غذائية',
      'مشروبات',
      'ألبان وأجبان',
      'مخبوزات',
      'خضروات وفواكه',
      'منظفات',
      'عناية شخصية',
      'أصناف أخرى',
    ],
  );

  static const pharmacy = SpeedstarBusinessTypeConfig(
    type: 'pharmacy',
    label: 'صيدلية',
    placeLabel: 'الصيدلية',
    itemLabel: 'منتج',
    itemsLabel: 'المنتجات',
    menuLabel: 'منتجات الصيدلية',
    searchHint: 'ابحث عن دواء أو منتج...',
    notesHint: 'مثال: بديل مناسب أو تركيز محدد...',
    closedLabel: 'الصيدلية مغلقة',
    newPlaceLabel: 'صيدلية جديدة',
    icon: Icons.local_pharmacy_rounded,
    categories: [
      'كل الأصناف',
      'أدوية',
      'وصفات طبية',
      'فيتامينات',
      'عناية شخصية',
      'مستلزمات طبية',
      'أم وطفل',
      'أصناف أخرى',
    ],
  );

  static const brand = SpeedstarBusinessTypeConfig(
    type: 'brand',
    label: 'براند',
    placeLabel: 'البراند',
    itemLabel: 'منتج',
    itemsLabel: 'المنتجات',
    menuLabel: 'المنتجات',
    searchHint: 'ابحث عن منتج...',
    notesHint: 'مثال: لون أو مقاس مفضل...',
    closedLabel: 'البراند غير متاح',
    newPlaceLabel: 'براند جديد',
    icon: Icons.workspace_premium_rounded,
    categories: [
      'كل الأصناف',
      'ملابس',
      'أحذية',
      'حقائب',
      'إكسسوارات',
      'عناية وجمال',
      'منتجات منزلية',
      'أصناف أخرى',
    ],
  );

  static const ecommerce = SpeedstarBusinessTypeConfig(
    type: 'ecommerce',
    label: 'متجر إلكتروني',
    placeLabel: 'المتجر الإلكتروني',
    itemLabel: 'منتج',
    itemsLabel: 'المنتجات',
    menuLabel: 'المنتجات',
    searchHint: 'ابحث عن منتج أو متجر...',
    notesHint: 'مثال: لون أو مقاس أو بديل مناسب...',
    closedLabel: 'المتجر غير متاح',
    newPlaceLabel: 'متجر جديد',
    icon: Icons.shopping_bag_rounded,
    categories: [
      'كل الأصناف',
      'إلكترونيات',
      'ملابس',
      'عناية وجمال',
      'منزل ومطبخ',
      'كتب وقرطاسية',
      'ألعاب',
      'أصناف أخرى',
    ],
  );

  static const Map<String, SpeedstarBusinessTypeConfig> _byType = {
    'restaurant': restaurant,
    'grocery': grocery,
    'pharmacy': pharmacy,
    'brand': brand,
    'ecommerce': ecommerce,
  };

  static SpeedstarBusinessTypeConfig resolve(dynamic raw) {
    final key = (raw ?? '').toString().trim().toLowerCase();
    return _byType[key] ?? restaurant;
  }

  static bool isSupported(dynamic raw) {
    final key = (raw ?? '').toString().trim().toLowerCase();
    return _byType.containsKey(key);
  }
}
