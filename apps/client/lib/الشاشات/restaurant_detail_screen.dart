import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../الثيم/client_theme.dart';
import 'cart_provider.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'client_cart_screen.dart';

class RestaurantDetailScreen extends StatefulWidget {
  final String restaurantId;
  final String name;
  final String image;
  final String offers;
  final String clientId;

  const RestaurantDetailScreen({
    super.key,
    required this.restaurantId,
    required this.name,
    required this.image,
    required this.offers,
    required this.clientId,
  });

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  static const Color primaryColor = ClientColors.primary;
  static const Color accentColor = ClientColors.accent;
  static const Color closedColor = ClientColors.error;
  static const Color openColor = ClientColors.success;

  bool _isDark = false;
  Color get _bg => _isDark ? ClientColors.background : ClientColors.lightBackground;
  Color get _cardBg => _isDark ? ClientColors.surface : Colors.white;
  Color get _softSurface =>
      _isDark ? const Color(0xFF24140A) : const Color(0xFFFFF8F3);
  Color get _textPrimary => _isDark ? Colors.white : ClientColors.lightTextPrimary;
  Color get _textSecondary => _isDark ? ClientColors.textSecondary : ClientColors.lightTextSecondary;
  Color get _chipBg => _isDark ? const Color(0x1AFFFFFF) : const Color(0xFFFFF8F3);
  Color get _chipBorder => _isDark ? const Color(0x33FF6B00) : const Color(0x33FF6B00);

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
  Color statusColor = ClientColors.success;
  double? _ratingAverage;
  int _ratingCount = 0;
  List<Map<String, dynamic>> _offerHighlights = [];
  String _restaurantImage = '';
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _restaurantSubscription;

  Map<String, dynamic>? _asStringMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  int? _asInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  String _cleanImageUrl(dynamic value) {
    final text = (value ?? '').toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return '';
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return '';
    if (uri.scheme != 'http' && uri.scheme != 'https') return '';
    return text;
  }

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
      final data = doc.data() ?? const <String, dynamic>{};
      final rawHighlights = data['offerHighlights'];
      final highlightsSource =
          rawHighlights is Iterable ? rawHighlights : const [];
      final highlights = highlightsSource
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();
      final firstOfferImage =
          highlights.isEmpty ? '' : _cleanImageUrl(highlights.first['imageUrl']);
      final resolvedImage = [
        data['coverImage'],
        data['logoImageUrl'],
        data['imageUrl'],
        data['image'],
        firstOfferImage,
      ].map(_cleanImageUrl).firstWhere((url) => url.isNotEmpty, orElse: () => '');

      setState(() {
        isClosed = resolved['isClosed'] as bool;
        statusText = resolved['text'] as String;
        statusColor = resolved['color'] as Color;
        _ratingAverage = _asDouble(data['ratingAverage']) ??
            _asDouble(data['averageRating']);
        _ratingCount =
            _asInt(data['ratingCount']) ?? _asInt(data['reviewCount']) ?? 0;
        _offerHighlights = highlights;
        _restaurantImage = resolvedImage;
      });
    });
  }

  String get _heroImage {
    if (_restaurantImage.trim().isNotEmpty) return _restaurantImage.trim();
    final widgetImage = _cleanImageUrl(widget.image);
    if (widgetImage.isNotEmpty) return widgetImage;
    if (_offerHighlights.isNotEmpty) {
      final offerImage = _cleanImageUrl(_offerHighlights.first['imageUrl']);
      if (offerImage.isNotEmpty) return offerImage;
    }
    return '';
  }

  String _formatOfferDiscountLabel(Map<String, dynamic> offer) {
    final discountType =
        (offer['discountType'] ?? '').toString().trim().toLowerCase();
    final discountValue = _asDouble(offer['discountValue']) ?? 0;
    if (discountType == 'percent' && discountValue > 0) {
      return 'خصم ${_formatPercentValue(discountValue)}%';
    }

    final badgeText = (offer['badgeText'] ?? '').toString().trim();
    final percentMatch =
        RegExp(r'([0-9]+(?:[.,][0-9]+)?)\s*[%٪]').firstMatch(badgeText);
    if (percentMatch == null) {
      return '';
    }
    final rawValue = percentMatch.group(1)!.replaceAll(',', '.');
    final parsedValue = double.tryParse(rawValue);
    final valueText = parsedValue == null
        ? percentMatch.group(1)!
        : _formatPercentValue(parsedValue);
    return 'خصم $valueText%';
  }

  String _formatPercentValue(double value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
  }

  String _offerDisplayText(
    Map<String, dynamic> offer, {
    required String title,
    required String discountLabel,
  }) {
    final candidates = [
      offer['description'],
      offer['offerText'],
      offer['text'],
      offer['body'],
    ];
    for (final value in candidates) {
      final text = (value ?? '').toString().trim();
      if (text.isEmpty || text == title || text == discountLabel) continue;
      return text;
    }
    return '';
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
          color: _softSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accentColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            const Icon(Icons.local_offer_rounded, color: accentColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                fallbackOffersText,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          textDirection: TextDirection.rtl,
          children: [
            const Icon(Icons.local_offer_rounded, color: accentColor),
            const SizedBox(width: 8),
            Text(
              'العروض الحالية',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._offerHighlights.map((offer) {
          final imageUrl = _cleanImageUrl(offer['imageUrl']);
          final rawTitle = (offer['title'] ?? '').toString().trim();
          final discountLabel = _formatOfferDiscountLabel(offer);
          final title = rawTitle.isNotEmpty ? rawTitle : 'عرض متاح';
          final bodyText = _offerDisplayText(
            offer,
            title: title,
            discountLabel: discountLabel,
          );

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _softSurface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: accentColor.withValues(alpha: 0.22)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              textDirection: TextDirection.rtl,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: 88,
                      height: 88,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const Icon(Icons.fastfood_rounded, size: 40),
                    ),
                  ),
                if (imageUrl.isNotEmpty) const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        textDirection: TextDirection.rtl,
                        children: [
                          Expanded(
                            child: Text(
                              title.isEmpty ? 'عرض متاح' : title,
                              textAlign: TextAlign.right,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: _textPrimary,
                              ),
                            ),
                          ),
                          if (discountLabel.isNotEmpty)
                            const SizedBox(width: 8),
                          if (discountLabel.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                discountLabel,
                                style: TextStyle(
                                  color: _textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (bodyText.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          bodyText,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: _textSecondary,
                            height: 1.4,
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
        'color': closedColor,
      };
    }

    if (data['temporarilyClosed'] == true) {
      return {
        'isClosed': true,
        'text': 'المطعم مغلق مؤقتًا',
        'color': const Color(0xFFF59E0B),
      };
    }

    final hours = _asStringMap(data['workingHours']);
    final todayKey = _getDayKey(DateTime.now().weekday);
    final today = _asStringMap(hours?[todayKey]);
    if (today == null) {
      return {
        'isClosed': true,
        'text': 'المطعم مغلق اليوم',
        'color': closedColor,
      };
    }

    final status = (today['status'] ?? '').toString().trim();
    if (status == 'مغلق') {
      return {
        'isClosed': true,
        'text': 'المطعم مغلق اليوم',
        'color': closedColor,
      };
    }

    final ranges = _extractTimeRanges(today, status);
    if (ranges.isEmpty) {
      return {
        'isClosed': true,
        'text': 'المطعم مغلق - وقت غير معروف',
        'color': closedColor,
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
          'color': openColor,
        };
      }
    }

    final nextOpening = _findNextOpening(nowMinutes, ranges);
    if (nextOpening != null) {
      return {
        'isClosed': true,
        'text': 'المطعم مغلق الآن - يفتح الساعة ${nextOpening['label']}',
        'color': closedColor,
      };
    }

    return {
      'isClosed': true,
      'text': 'المطعم أغلق لهذا اليوم',
      'color': closedColor,
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
      final morning = _asStringMap(dayData['morning']);
      final evening = _asStringMap(dayData['evening']);
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
          color: selected ? primaryColor : _chipBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? primaryColor : _chipBorder,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : const [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: TextDirection.rtl,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : _textPrimary,
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
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
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
          color: enabled ? primaryColor.withValues(alpha: 0.08) : _chipBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: enabled
                ? primaryColor.withValues(alpha: 0.3)
                : _chipBorder,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? primaryColor : _textSecondary.withValues(alpha: 0.55),
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
    final imageProvider = itemImage.isNotEmpty ? CachedNetworkImageProvider(itemImage) : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(22),
          border: _isDark
              ? Border.all(color: const Color(0x1AFF6B00))
              : Border.all(color: const Color(0x0F000000)),
          boxShadow: [
            BoxShadow(
              color: _isDark
                  ? Colors.black.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.05),
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
                          color: _softSurface,
                          child:
                              Icon(Icons.fastfood, color: primaryColor, size: 34),
                        ),
                      )
                    : Container(
                        width: 104,
                        height: 104,
                        color: _softSurface,
                        child: const Icon(Icons.fastfood,
                            color: primaryColor, size: 34),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        Flexible(
                          child: Text(
                            itemName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: _textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (data['available'] == false)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: closedColor.withValues(alpha: 0.12),
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
                            color: accentColor.withValues(alpha: 0.12),
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
                            color: _chipBg,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: _chipBorder),
                          ),
                          child: Text(
                            hasSizes
                                ? _sizesSummary(sizes)
                                : '${NumberFormat.decimalPattern().format(itemPrice)} ج.س',
                            style: TextStyle(
                              color: _textSecondary,
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
                        style: TextStyle(
                          color: _textSecondary,
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
                              color: _chipBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: _chipBorder),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _sizeLabel(entry.key),
                                  style: TextStyle(
                                    color: _textPrimary,
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
                      textDirection: TextDirection.rtl,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: quantity > 0
                                ? primaryColor.withValues(alpha: 0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            quantity > 0 ? 'في السلة: $quantity' : 'أضف للسلة',
                            style: TextStyle(
                              color: quantity > 0
                                  ? primaryColor
                                  : _textSecondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const Spacer(),
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
                            style: TextStyle(
                              color: _textPrimary,
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
    _isDark = Theme.of(context).brightness == Brightness.dark;
    final cartProvider = Provider.of<CartProvider>(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bg,
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
                    _heroImage.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: _heroImage,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              color: primaryColor.withValues(alpha: 0.10),
                              child: const Icon(Icons.storefront,
                                  size: 56, color: primaryColor),
                            ),
                          )
                        : Container(
                            color: primaryColor.withValues(alpha: 0.10),
                            child: const Icon(Icons.storefront,
                                size: 56, color: primaryColor),
                          ),
                    Container(
                      color: Colors.black.withValues(alpha: 0.3),
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
                                    color: statusColor.withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
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
                                    color: Colors.white.withValues(alpha: 0.16),
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
                    Text(
                      'استكشف الأصناف',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: _textPrimary,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'القائمة مرتبة تلقائياً حسب التصنيف لسهولة التصفح.',
                      style: TextStyle(
                        color: _textSecondary,
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
                        hintStyle:
                            TextStyle(color: _textSecondary, fontSize: 14),
                        prefixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.close,
                                    color: _textSecondary, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : Icon(Icons.search,
                                color: _textSecondary, size: 20),
                        filled: true,
                        fillColor: _softSurface,
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
                        return SizedBox(
                          height: 52,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: categories.length + 1,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return _buildCategoryChip(
                                  label: 'كل الأصناف',
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
                        color: primaryColor.withValues(alpha: 0.35),
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
                          color: Colors.white.withValues(alpha: 0.2),
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
