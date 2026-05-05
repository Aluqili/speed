import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';
import 'cart_provider.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'client_cart_screen.dart';

class RestaurantDetailScreen extends StatefulWidget {
  final String restaurantId;
  final String name;
  final String image;
  final String offers;
  final String clientId;

  const RestaurantDetailScreen({
    Key? key,
    required this.restaurantId,
    required this.name,
    required this.image,
    required this.offers,
    required this.clientId,
  }) : super(key: key);

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  static const Color primaryColor = AppThemeArabic.clientPrimary;
  static const Color accentColor = AppThemeArabic.clientAccent;
  static const Color backgroundColor = AppThemeArabic.clientBackground;
  static const Color cardColor = Colors.white;
  static const Color textColorPrimary = Color(0xFF1A1D26);
  static const Color textColorSecondary = Color(0xFF6B7280);
  static const Color closedColor = Color(0xFFFF3B30);
  static const List<String> _globalCategoryOrder = [
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
  ];

  String? _selectedCategory;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  bool isClosed = false;
  String statusText = '';
  Color statusColor = Colors.green;
  double? _ratingAverage;
  int _ratingCount = 0;
  List<Map<String, dynamic>> _offerHighlights = [];
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _restaurantSubscription;

  @override
  void initState() {
    super.initState();
    _listenToRestaurantStatus();
  }

  @override
  void dispose() {
    _restaurantSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _listenToRestaurantStatus() {
    _restaurantSubscription = FirebaseFirestore.instance
        .collection('restaurants')
        .doc(widget.restaurantId)
        .snapshots()
        .listen((doc) {
      final resolved = _resolveRestaurantStatus(doc.data());
      if (!mounted) return;
      setState(() {
        isClosed = resolved['isClosed'] as bool;
        statusText = resolved['text'] as String;
        statusColor = resolved['color'] as Color;
        _ratingAverage = ((doc.data()?['ratingAverage'] ??
                doc.data()?['averageRating']) as num?)
            ?.toDouble();
        _ratingCount =
            ((doc.data()?['ratingCount'] ?? doc.data()?['reviewCount']) as num?)
                    ?.toInt() ??
                0;
        _offerHighlights =
            ((doc.data()?['offerHighlights'] as List?) ?? const [])
                .whereType<Map>()
                .map((entry) => Map<String, dynamic>.from(entry))
                .toList();
      });
    });
  }

  String _formatOfferWindow(dynamic startsAt, dynamic endsAt) {
    String format(dynamic value) {
      if (value is Timestamp) {
        final date = value.toDate();
        return DateFormat('d/M h:mm a', 'ar').format(date);
      }
      return '';
    }

    final start = format(startsAt);
    final end = format(endsAt);
    if (start.isEmpty && end.isEmpty) return '';
    if (start.isEmpty) return 'ينتهي $end';
    if (end.isEmpty) return 'يبدأ $start';
    return '$start - $end';
  }

  Widget _buildOfferHighlightsSection() {
    final fallbackOffersText = widget.offers.trim();
    if (_offerHighlights.isEmpty && fallbackOffersText.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_offerHighlights.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accentColor.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                fallbackOffersText,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: textColorPrimary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.local_offer_rounded, color: accentColor),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const SizedBox(height: 14),
        Row(
          children: [
            const Spacer(),
            const Text(
              'العروض الحالية',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: textColorPrimary,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.local_offer_rounded, color: accentColor),
          ],
        ),
        const SizedBox(height: 12),
        ..._offerHighlights.map((offer) {
          final imageUrl = (offer['imageUrl'] ?? '').toString().trim();
          final badgeText = (offer['badgeText'] ?? '').toString().trim();
          final summaryText = (offer['summaryText'] ?? '').toString().trim();
          final description = (offer['description'] ?? '').toString().trim();
          final title = (offer['title'] ?? '').toString().trim();
          final windowText =
              _formatOfferWindow(offer['startsAt'], offer['endsAt']);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: accentColor.withOpacity(0.22)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      imageUrl,
                      width: 88,
                      height: 88,
                      fit: BoxFit.cover,
                    ),
                  ),
                if (imageUrl.isNotEmpty) const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          if (badgeText.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                badgeText,
                                style: const TextStyle(
                                  color: textColorPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          const Spacer(),
                          Flexible(
                            child: Text(
                              title,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: textColorPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        summaryText.isNotEmpty ? summaryText : description,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: textColorSecondary,
                          height: 1.4,
                        ),
                      ),
                      if (windowText.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          windowText,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  String _restaurantRatingText() {
    if (_ratingAverage == null || _ratingAverage! <= 0) {
      return 'مطعم جديد';
    }
    if (_ratingCount > 0) {
      return '${_formatRatingValue(_ratingAverage!)} · $_ratingCount تقييم';
    }
    return _formatRatingValue(_ratingAverage!);
  }

  String _formatRatingValue(double value) {
    final normalized = value.toStringAsFixed(1);
    return normalized.endsWith('.0')
        ? normalized.substring(0, normalized.length - 2)
        : normalized;
  }

  Map<String, dynamic> _resolveRestaurantStatus(Map<String, dynamic>? data) {
    if (data == null) {
      return {
        'isClosed': true,
        'text': 'تعذر تحميل حالة المطعم',
        'color': Colors.red,
      };
    }

    if (data['temporarilyClosed'] == true) {
      return {
        'isClosed': true,
        'text': 'المطعم مغلق مؤقتًا',
        'color': Colors.orange,
      };
    }

    final hours = data['workingHours'] as Map<String, dynamic>?;
    final todayKey = _getDayKey(DateTime.now().weekday);
    final today = hours?[todayKey] as Map<String, dynamic>?;
    if (today == null) {
      return {
        'isClosed': true,
        'text': 'المطعم مغلق اليوم',
        'color': Colors.red,
      };
    }

    final status = (today['status'] ?? '').toString().trim();
    if (status == 'مغلق') {
      return {
        'isClosed': true,
        'text': 'المطعم مغلق اليوم',
        'color': Colors.red,
      };
    }

    final ranges = _extractTimeRanges(today, status);
    if (ranges.isEmpty) {
      return {
        'isClosed': true,
        'text': 'المطعم مغلق - وقت غير معروف',
        'color': Colors.red,
      };
    }

    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    for (final range in ranges) {
      final open = range['open'] as TimeOfDay;
      final close = range['close'] as TimeOfDay;
      if (_isWithinTimeRange(nowMinutes, open, close)) {
        return {
          'isClosed': false,
          'text': 'المطعم مفتوح الآن',
          'color': Colors.green,
        };
      }
    }

    final nextOpening = _findNextOpening(nowMinutes, ranges);
    if (nextOpening != null) {
      return {
        'isClosed': true,
        'text': 'المطعم مغلق الآن - يفتح الساعة ${nextOpening['label']}',
        'color': Colors.red,
      };
    }

    return {
      'isClosed': true,
      'text': 'المطعم أغلق لهذا اليوم',
      'color': Colors.red,
    };
  }

  List<Map<String, dynamic>> _extractTimeRanges(
    Map<String, dynamic> dayData,
    String status,
  ) {
    final ranges = <Map<String, dynamic>>[];

    void addRange(dynamic openValue, dynamic closeValue) {
      final openText = openValue?.toString().trim() ?? '';
      final closeText = closeValue?.toString().trim() ?? '';
      final open = _parseTime(openText);
      final close = _parseTime(closeText);
      if (open == null || close == null) return;
      ranges.add({
        'label': openText,
        'open': open,
        'close': close,
      });
    }

    if (status == 'صباحي ومسائي' ||
        (dayData['morning'] is Map && dayData['evening'] is Map)) {
      final morning = dayData['morning'] as Map<String, dynamic>?;
      final evening = dayData['evening'] as Map<String, dynamic>?;
      addRange(morning?['open'], morning?['close']);
      addRange(evening?['open'], evening?['close']);
      return ranges;
    }

    addRange(dayData['open'], dayData['close']);
    return ranges;
  }

  bool _isWithinTimeRange(int nowMinutes, TimeOfDay open, TimeOfDay close) {
    final openMinutes = open.hour * 60 + open.minute;
    final closeMinutes = close.hour * 60 + close.minute;
    if (closeMinutes >= openMinutes) {
      return nowMinutes >= openMinutes && nowMinutes <= closeMinutes;
    }
    return nowMinutes >= openMinutes || nowMinutes <= closeMinutes;
  }

  Map<String, dynamic>? _findNextOpening(
    int nowMinutes,
    List<Map<String, dynamic>> ranges,
  ) {
    Map<String, dynamic>? nearest;
    var bestDelta = 1 << 30;
    for (final range in ranges) {
      final open = range['open'] as TimeOfDay;
      final openMinutes = open.hour * 60 + open.minute;
      final delta = openMinutes >= nowMinutes
          ? openMinutes - nowMinutes
          : (24 * 60 - nowMinutes) + openMinutes;
      if (delta < bestDelta) {
        bestDelta = delta;
        nearest = range;
      }
    }
    return nearest;
  }

  TimeOfDay? _parseTime(String time) {
    try {
      final isPM = time.contains('م');
      final parts = time.replaceAll(RegExp(r'[^0-9:]'), '').split(':');
      if (parts.length != 2) return null;
      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1]);
      if (isPM && hour < 12) hour += 12;
      if (!isPM && hour == 12) hour = 0;
      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return null;
    }
  }

  String _getDayKey(int weekday) {
    switch (weekday) {
      case DateTime.saturday:
        return 'saturday';
      case DateTime.sunday:
        return 'sunday';
      case DateTime.monday:
        return 'monday';
      case DateTime.tuesday:
        return 'tuesday';
      case DateTime.wednesday:
        return 'wednesday';
      case DateTime.thursday:
        return 'thursday';
      case DateTime.friday:
        return 'friday';
      default:
        return '';
    }
  }

  Map<String, double> _extractSizes(Map<String, dynamic> data) {
    final raw = data['sizes'];
    if (raw is! Map) return const {};
    final sizes = <String, double>{};
    for (final entry in raw.entries) {
      final key = entry.key.toString().trim().toLowerCase();
      if (key.isEmpty) continue;
      final value = entry.value;
      final parsed = value is num
          ? value.toDouble()
          : double.tryParse(value.toString().trim().replaceAll(',', '.'));
      if (parsed != null && parsed > 0) {
        sizes[key] = parsed;
      }
    }
    return sizes;
  }

  String _sizeLabel(String sizeKey) {
    switch (sizeKey) {
      case 'small':
        return 'صغير';
      case 'medium':
        return 'وسط';
      case 'large':
        return 'كبير';
      default:
        return sizeKey;
    }
  }

  String _sizesSummary(Map<String, double> sizes) {
    final small = sizes['small'];
    final medium = sizes['medium'];
    final large = sizes['large'];
    final parts = <String>[];
    if (small != null) {
      parts.add('صغير ${NumberFormat.decimalPattern().format(small)} ج.س');
    }
    if (medium != null) {
      parts.add('وسط ${NumberFormat.decimalPattern().format(medium)} ج.س');
    }
    if (large != null) {
      parts.add('كبير ${NumberFormat.decimalPattern().format(large)} ج.س');
    }
    return parts.join(' • ');
  }

  String _sanitizeCategoryToken(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[_\-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه');
  }

  String _canonicalCategoryLabel(String rawCategory) {
    final raw = rawCategory.trim();
    if (raw.isEmpty) return 'أصناف أخرى';

    final token = _sanitizeCategoryToken(raw);

    bool containsAny(List<String> values) {
      for (final value in values) {
        if (token.contains(_sanitizeCategoryToken(value))) {
          return true;
        }
      }
      return false;
    }

    if (containsAny([
      'all',
      'all items',
      'كل الاصناف',
      'جميع الاصناف',
    ])) {
      return 'كل الأصناف';
    }
    if (containsAny([
      'main',
      'main course',
      'main dish',
      'الوجبات الرئيسية',
      'وجبات رئيسية',
      'الاطباق الرئيسية',
      'اطباق رئيسية',
    ])) {
      return 'الوجبات الرئيسية';
    }
    if (containsAny([
      'meal',
      'meals',
      'وجبة',
      'وجبات',
      'اطباق',
      'أطباق',
    ])) {
      return 'الوجبات';
    }
    if (containsAny(['appetizer', 'starter', 'مقبلات'])) {
      return 'المقبلات';
    }
    if (containsAny(['soup', 'soups', 'شوربة', 'شوربات'])) {
      return 'الشوربات';
    }
    if (containsAny(['salad', 'salads', 'سلطة', 'سلطات'])) {
      return 'السلطات';
    }
    if (containsAny(
        ['sandwich', 'sandwiches', 'wrap', 'ساندويتش', 'سندويتش'])) {
      return 'السندويتشات';
    }
    if (containsAny(['burger', 'burgers', 'برغر', 'برجر'])) {
      return 'البرغر';
    }
    if (containsAny(['pizza', 'pizzas', 'بيتزا'])) {
      return 'البيتزا';
    }
    if (containsAny(['breakfast', 'فطور', 'افطار'])) {
      return 'الفطور';
    }
    if (containsAny([
      'drink',
      'drinks',
      'beverage',
      'juice',
      'مشروب',
      'مشروبات',
      'عصير',
      'عصائر'
    ])) {
      return 'المشروبات';
    }
    if (containsAny(['dessert', 'desserts', 'sweet', 'حلويات', 'تحلية'])) {
      return 'الحلويات';
    }
    if (containsAny(
        ['extra', 'extras', 'addon', 'add on', 'اضافة', 'اضافات'])) {
      return 'الإضافات';
    }

    return raw;
  }

  int _categoryRank(String category) {
    final canonical = _canonicalCategoryLabel(category);
    final index = _globalCategoryOrder.indexOf(canonical);
    return index >= 0 ? index : _globalCategoryOrder.length;
  }

  List<String> _sortedCategoriesFromDocs(List<QueryDocumentSnapshot> docs) {
    final categories = <String>{};
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      categories
          .add(_canonicalCategoryLabel((data['category'] ?? '').toString()));
    }
    final ordered = categories.where((value) => value.isNotEmpty).toList()
      ..sort((a, b) {
        final rankCompare = _categoryRank(a).compareTo(_categoryRank(b));
        if (rankCompare != 0) return rankCompare;
        return a.compareTo(b);
      });
    return ordered;
  }

  List<QueryDocumentSnapshot> _sortMenuDocs(List<QueryDocumentSnapshot> docs) {
    final sorted = List<QueryDocumentSnapshot>.from(docs);
    sorted.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;
      final aCategory =
          _canonicalCategoryLabel((aData['category'] ?? '').toString());
      final bCategory =
          _canonicalCategoryLabel((bData['category'] ?? '').toString());
      final categoryCompare =
          _categoryRank(aCategory).compareTo(_categoryRank(bCategory));
      if (categoryCompare != 0) return categoryCompare;
      final labelCompare = aCategory.compareTo(bCategory);
      if (labelCompare != 0) return labelCompare;
      final aUnavailable = aData['available'] == false ? 1 : 0;
      final bUnavailable = bData['available'] == false ? 1 : 0;
      final availableCompare = aUnavailable.compareTo(bUnavailable);
      if (availableCompare != 0) return availableCompare;
      final aName = (aData['name'] ?? '').toString().trim();
      final bName = (bData['name'] ?? '').toString().trim();
      return aName.compareTo(bName);
    });
    return sorted;
  }

  List<_MenuSection> _buildMenuSections(List<QueryDocumentSnapshot> docs) {
    final q = _searchQuery.trim().toLowerCase();
    final grouped = <String, List<QueryDocumentSnapshot>>{};
    for (final doc in _sortMenuDocs(docs)) {
      final data = doc.data() as Map<String, dynamic>;
      final category =
          _canonicalCategoryLabel((data['category'] ?? '').toString());
      if (_selectedCategory != null && category != _selectedCategory) {
        continue;
      }
      if (q.isNotEmpty) {
        final name = (data['name'] ?? '').toString().toLowerCase();
        final desc =
            (data['description'] ?? data['details'] ?? '').toString().toLowerCase();
        if (!name.contains(q) && !desc.contains(q)) continue;
      }
      grouped.putIfAbsent(category, () => <QueryDocumentSnapshot>[]).add(doc);
    }

    final categories = grouped.keys.toList()
      ..sort((a, b) {
        final rankCompare = _categoryRank(a).compareTo(_categoryRank(b));
        if (rankCompare != 0) return rankCompare;
        return a.compareTo(b);
      });

    return categories
        .map((category) => _MenuSection(
              title: category,
              items: grouped[category] ?? const <QueryDocumentSnapshot>[],
            ))
        .where((section) => section.items.isNotEmpty)
        .toList();
  }

  Widget _buildCategoryChip({
    required String label,
    required int count,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? primaryColor : const Color(0xFFE5E7EB),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : const [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withOpacity(0.2)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  color: selected ? Colors.white : textColorSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : textColorPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuSectionHeader(_MenuSection section) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${section.items.length} صنف',
              style: const TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const Spacer(),
          Text(
            section.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: textColorPrimary,
            ),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }

  Widget _qtyButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: enabled
              ? primaryColor.withOpacity(0.08)
              : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: enabled
                ? primaryColor.withOpacity(0.3)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? primaryColor : Colors.grey[400],
        ),
      ),
    );
  }

  Widget _buildMenuItemCard({
    required QueryDocumentSnapshot doc,
    required Map<String, dynamic> data,
    required CartProvider cartProvider,
  }) {
    final itemId = '${widget.restaurantId}_${doc.id}';
    final itemName = (data['name'] ?? '').toString();
    final itemDescription =
        (data['description'] ?? data['details'] ?? '').toString().trim();
    final categoryLabel =
        _canonicalCategoryLabel((data['category'] ?? '').toString());
    final sizes = _extractSizes(data);
    final hasSizes = sizes.isNotEmpty;
    final itemPrice = (data['price'] as num?)?.toDouble() ?? 0.0;
    final itemImage = (data['imageUrl'] ?? '').toString();
    final quantity = hasSizes
        ? cartProvider.getQuantityByMenuItem(widget.restaurantId, doc.id)
        : cartProvider.getQuantity(itemId);
    final imageProvider = itemImage.isNotEmpty ? NetworkImage(itemImage) : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            textDirection: TextDirection.rtl,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: imageProvider != null
                    ? Image(
                        image: imageProvider,
                        width: 104,
                        height: 104,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 104,
                          height: 104,
                          color: const Color(0xFFF3F4F6),
                          child:
                              Icon(Icons.fastfood, color: Colors.grey[500], size: 34),
                        ),
                      )
                    : Container(
                        width: 104,
                        height: 104,
                        color: const Color(0xFFF3F4F6),
                        child: Icon(Icons.fastfood,
                            color: Colors.grey[500], size: 34),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        if (data['available'] == false)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: closedColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'غير متوفر',
                              style: TextStyle(
                                color: closedColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        const Spacer(),
                        Flexible(
                          child: Text(
                            itemName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: textColorPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            categoryLabel,
                            style: const TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            hasSizes
                                ? _sizesSummary(sizes)
                                : '${NumberFormat.decimalPattern().format(itemPrice)} ج.س',
                            style: const TextStyle(
                              color: textColorSecondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (itemDescription.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        itemDescription,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: textColorSecondary,
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ],
                    if (hasSizes) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.end,
                        children: sizes.entries.map((entry) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border:
                                  Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _sizeLabel(entry.key),
                                  style: const TextStyle(
                                    color: textColorPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${NumberFormat.decimalPattern().format(entry.value)} ج.س',
                                  style: const TextStyle(
                                    color: primaryColor,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _qtyButton(
                          icon: Icons.add_rounded,
                          enabled: !isClosed && data['available'] != false,
                          onTap: () async {
                            if (hasSizes) {
                              await _showSizePickerAndAddToCart(
                                cartProvider: cartProvider,
                                docId: doc.id,
                                itemName: itemName,
                                sizes: sizes,
                              );
                              return;
                            }
                            if (quantity == 0) {
                              await _showNotesAndAddToCart(
                                cartProvider: cartProvider,
                                itemId: itemId,
                                docId: doc.id,
                                itemName: itemName,
                                itemPrice: itemPrice,
                              );
                            } else {
                              await cartProvider.addToCartSimple(
                                widget.restaurantId,
                                itemId,
                                itemName,
                                itemPrice,
                                menuItemId: doc.id,
                              );
                            }
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            quantity.toString(),
                            style: const TextStyle(
                              color: textColorPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        _qtyButton(
                          icon: Icons.remove_rounded,
                          enabled: !isClosed &&
                              data['available'] != false &&
                              quantity > 0,
                          onTap: () async {
                            if (hasSizes) {
                              await _showSizePickerAndRemoveFromCart(
                                cartProvider: cartProvider,
                                restaurantId: widget.restaurantId,
                                docId: doc.id,
                                itemName: itemName,
                              );
                              return;
                            }
                            await cartProvider.removeOneItem(itemId);
                          },
                        ),
                        const Spacer(),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: quantity > 0
                                ? primaryColor.withOpacity(0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            quantity > 0 ? 'في السلة: $quantity' : 'أضف للسلة',
                            style: TextStyle(
                              color: quantity > 0
                                  ? primaryColor
                                  : textColorSecondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSizePickerAndRemoveFromCart({
    required CartProvider cartProvider,
    required String restaurantId,
    required String docId,
    required String itemName,
  }) async {
    final variants = cartProvider.variantsForMenuItem(restaurantId, docId);
    if (variants.isEmpty) return;

    if (variants.length == 1) {
      await cartProvider.removeOneItem(variants.first.id);
      return;
    }

    final aggregated = <String, Map<String, dynamic>>{};
    for (final variant in variants) {
      final key = variant.sizeKey ?? variant.id;
      final current = aggregated[key] ??
          {
            'id': variant.id,
            'sizeLabel': variant.sizeLabel ?? 'حجم غير محدد',
            'price': variant.price,
            'quantity': 0,
          };
      current['quantity'] = (current['quantity'] as int) + variant.quantity;
      aggregated[key] = current;
    }

    String? pickedId;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('اختر الحجم المراد إنقاصه من $itemName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: aggregated.values
              .map(
                (entry) => ListTile(
                  title: Text(entry['sizeLabel'].toString()),
                  subtitle: Text(
                    '${NumberFormat.decimalPattern().format(entry['price'])} ج.س • الكمية ${entry['quantity']}',
                  ),
                  onTap: () {
                    pickedId = entry['id'].toString();
                    Navigator.pop(context);
                  },
                ),
              )
              .toList(),
        ),
      ),
    );

    if (pickedId != null) {
      await cartProvider.removeOneItem(pickedId!);
    }
  }

  Future<void> _showNotesAndAddToCart({
    required CartProvider cartProvider,
    required String itemId,
    required String docId,
    required String itemName,
    required double itemPrice,
  }) async {
    final notesController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('إضافة $itemName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ملاحظات خاصة (اختياري)',
                  style:
                      TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: notesController,
                textDirection: TextDirection.rtl,
                maxLines: 2,
                autofocus: false,
                decoration: InputDecoration(
                  hintText: 'مثال: بدون بصل، حار جداً...',
                  hintStyle: const TextStyle(fontSize: 13),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                notesController.dispose();
                Navigator.pop(ctx, false);
              },
              child: const Text('تخطي'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('إضافة للسلة'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      await cartProvider.addToCartSimple(
        widget.restaurantId,
        itemId,
        itemName,
        itemPrice,
        menuItemId: docId,
        notes: notesController.text.trim().isEmpty
            ? null
            : notesController.text.trim(),
      );
    }
    notesController.dispose();
  }

  Future<void> _showSizePickerAndAddToCart({
    required CartProvider cartProvider,
    required String docId,
    required String itemName,
    required Map<String, double> sizes,
  }) async {
    final orderedKeys = ['small', 'medium', 'large']
        .where((key) => sizes.containsKey(key))
        .toList();
    if (orderedKeys.isEmpty) return;

    String selected =
        orderedKeys.contains('medium') ? 'medium' : orderedKeys.first;
    final notesController = TextEditingController();

    final picked = await showDialog<String>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('أضف $itemName للسلة'),
          content: StatefulBuilder(
            builder: (context, setInnerState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...orderedKeys.map(
                      (key) => RadioListTile<String>(
                        value: key,
                        groupValue: selected,
                        onChanged: (value) {
                          if (value == null) return;
                          setInnerState(() => selected = value);
                        },
                        title: Text(_sizeLabel(key)),
                        subtitle: Text(
                          '${NumberFormat.decimalPattern().format(sizes[key])} ج.س',
                        ),
                      ),
                    ),
                    const Divider(height: 20),
                    const Text('ملاحظات خاصة (اختياري)',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: notesController,
                      textDirection: TextDirection.rtl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'مثال: بدون بصل، حار جداً...',
                        hintStyle: const TextStyle(fontSize: 13),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                notesController.dispose();
                Navigator.pop(context);
              },
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, selected),
              child: const Text('إضافة للسلة'),
            ),
          ],
        ),
      ),
    );

    if (picked == null) {
      notesController.dispose();
      return;
    }
    final price = sizes[picked];
    if (price == null) {
      notesController.dispose();
      return;
    }

    final variantId = '${widget.restaurantId}_${docId}_$picked';
    await cartProvider.addToCartSimple(
      widget.restaurantId,
      variantId,
      itemName,
      price,
      menuItemId: docId,
      sizeKey: picked,
      sizeLabel: _sizeLabel(picked),
      notes: notesController.text.trim().isEmpty
          ? null
          : notesController.text.trim(),
    );
    notesController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 220,
              backgroundColor: primaryColor,
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    widget.image.isNotEmpty
                        ? Image.network(widget.image, fit: BoxFit.cover)
                        : Container(
                            color: Colors.grey[200],
                            child: Icon(Icons.storefront,
                                size: 56, color: Colors.grey[500]),
                          ),
                    Container(
                      color: Colors.black.withOpacity(0.3),
                    ),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // حالة المطعم
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.85),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        isClosed ? 'مغلق الآن' : 'مفتوح الآن',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // التقييم
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.16),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _restaurantRatingText(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      const Icon(Icons.star_rounded,
                                          color: accentColor, size: 16),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              widget.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                shadows: [
                                  Shadow(
                                    color: Colors.black54,
                                    blurRadius: 4,
                                    offset: Offset(1, 1),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              centerTitle: true,
              title: null,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'استكشف الأصناف',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: textColorPrimary,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'القائمة مرتبة تلقائياً حسب التصنيف لسهولة التصفح.',
                      style: TextStyle(
                        color: textColorSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    _buildOfferHighlightsSection(),
                    const SizedBox(height: 14),
                    // ─── حقل البحث ────────────────────────────────────
                    TextField(
                      controller: _searchController,
                      textDirection: TextDirection.rtl,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: InputDecoration(
                        hintText: 'ابحث في القائمة...',
                        hintStyle: const TextStyle(
                            color: Colors.grey, fontSize: 14),
                        prefixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.grey, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : const Icon(Icons.search,
                                color: Colors.grey, size: 20),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<QuerySnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('restaurants')
                          .doc(widget.restaurantId)
                          .collection('full_menu')
                          .get(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final items = snapshot.data!.docs;
                        if (items.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        final categories = _sortedCategoriesFromDocs(items);
                        final counts = <String, int>{};
                        for (var doc in items) {
                          final data = doc.data() as Map<String, dynamic>;
                          final category = _canonicalCategoryLabel(
                              (data['category'] ?? '').toString());
                          counts[category] = (counts[category] ?? 0) + 1;
                        }
                        return SizedBox(
                          height: 52,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            reverse: true,
                            itemCount: categories.length + 1,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return _buildCategoryChip(
                                  label: 'كل الأصناف',
                                  count: items.length,
                                  selected: _selectedCategory == null,
                                  onTap: () {
                                    setState(() {
                                      _selectedCategory = null;
                                    });
                                  },
                                );
                              }

                              final cat = categories[index - 1];
                              return _buildCategoryChip(
                                label: cat,
                                count: counts[cat] ?? 0,
                                selected: _selectedCategory == cat,
                                onTap: () {
                                  setState(() {
                                    _selectedCategory = cat;
                                  });
                                },
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            SliverFillRemaining(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('restaurants')
                    .doc(widget.restaurantId)
                    .collection('full_menu')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('تعذر تحميل قائمة المطعم حالياً.'),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                        child: Text('لا توجد أصناف متاحة حالياً.'));
                  }
                  final sections = _buildMenuSections(snapshot.data!.docs);
                  if (sections.isEmpty) {
                    return const Center(
                        child: Text('لا توجد أصناف ضمن هذا التصنيف حالياً.'));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 88),
                    itemCount: sections.length,
                    itemBuilder: (context, index) {
                      final section = sections[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildMenuSectionHeader(section),
                          ...section.items.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            return _buildMenuItemCard(
                              doc: doc,
                              data: data,
                              cartProvider: cartProvider,
                            );
                          }),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: cartProvider.cartItems.isNotEmpty
            ? GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ClientCartScreen()),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${cartProvider.totalPrice.toStringAsFixed(2)} ج.س',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${cartProvider.cartItems.fold(0, (s, i) => s + i.quantity)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.shopping_cart_rounded,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 6),
                      const Text(
                        'السلة',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

class _MenuSection {
  final String title;
  final List<QueryDocumentSnapshot> items;

  const _MenuSection({
    required this.title,
    required this.items,
  });
}
