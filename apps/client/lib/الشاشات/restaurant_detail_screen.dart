import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:getwidget/getwidget.dart';
import 'package:provider/provider.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';
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

  String? _selectedCategory;
  bool isClosed = false;
  String statusText = '';
  Color statusColor = Colors.green;
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
      });
    });
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
      final current = aggregated[key] ?? {
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

    String selected = orderedKeys.contains('medium') ? 'medium' : orderedKeys.first;
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('اختر حجم $itemName'),
        content: StatefulBuilder(
          builder: (context, setInnerState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: orderedKeys
                  .map(
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
                  )
                  .toList(),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, selected),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );

    if (picked == null) return;
    final price = sizes[picked];
    if (price == null) return;

    final variantId = '${widget.restaurantId}_${docId}_$picked';
    await cartProvider.addToCartSimple(
      widget.restaurantId,
      variantId,
      itemName,
      price,
      menuItemId: docId,
      sizeKey: picked,
      sizeLabel: _sizeLabel(picked),
    );
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
                        child: Text(
                          widget.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                            shadows: [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 4,
                                offset: Offset(1, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              centerTitle: true,
              title: null,
            ),
            if (statusText.isNotEmpty)
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  color: statusColor,
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    statusText,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'قائمة الأصناف',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: textColorPrimary,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 8),
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
                        // استخراج الفئات
                        final Set<String> categories = {'كل الأصناف'};
                        for (var doc in items) {
                          final data = doc.data() as Map<String, dynamic>;
                          if (data['category'] != null &&
                              data['category'].toString().isNotEmpty) {
                            categories.add(data['category']);
                          }
                        }
                        final List<String> categoryList = categories.toList();
                        return SizedBox(
                          height: 40,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            reverse: true,
                            itemCount: categoryList.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final cat = categoryList[index];
                              final selected = _selectedCategory == null
                                  ? cat == 'كل الأصناف'
                                  : _selectedCategory == cat;
                              return ChoiceChip(
                                label: Text(cat,
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                selected: selected,
                                onSelected: (val) {
                                  setState(() {
                                    _selectedCategory =
                                        cat == 'كل الأصناف' ? null : cat;
                                  });
                                },
                                selectedColor: primaryColor,
                                backgroundColor: Colors.grey[200],
                                labelStyle: TextStyle(
                                  color: selected
                                      ? Colors.white
                                      : textColorPrimary,
                                ),
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
                  final items = snapshot.data!.docs;
                  // تصفية حسب الفئة
                  final filteredItems = _selectedCategory == null
                      ? items
                      : items.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return data['category'] == _selectedCategory;
                        }).toList();
                  return ListView.builder(
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final doc = filteredItems[index];
                      final data = doc.data() as Map<String, dynamic>;
                        final itemId = '${widget.restaurantId}_${doc.id}';
                      final itemName = data['name'] ?? '';
                        final sizes = _extractSizes(data);
                        final hasSizes = sizes.isNotEmpty;
                      final itemPrice =
                          (data['price'] as num?)?.toDouble() ?? 0.0;
                      final itemImage = data['imageUrl'] ?? '';
                        final quantity = hasSizes
                          ? cartProvider.getQuantityByMenuItem(
                            widget.restaurantId,
                            doc.id,
                          )
                          : cartProvider.getQuantity(itemId);
                      final imageProvider = (itemImage.isNotEmpty)
                          ? NetworkImage(itemImage)
                          : null;
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 0, vertical: 8),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.08),
                                spreadRadius: 1,
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            textDirection: TextDirection.rtl,
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          // حالة التوفر: تظهر فقط إذا غير متوفر
                                          if (data['available'] == false)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: closedColor,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Text(
                                                'غير متوفر',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            ),
                                          // اسم الصنف
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                right: 12),
                                            child: Text(
                                              itemName,
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: textColorPrimary,
                                                  letterSpacing: 0.5,
                                                  height: 1.2),
                                              textAlign: TextAlign.right,
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        hasSizes
                                            ? _sizesSummary(sizes)
                                            : '${NumberFormat.decimalPattern().format(itemPrice)} ج.س',
                                        style: TextStyle(
                                            color: textColorSecondary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            letterSpacing: 0.2),
                                      ),
                                      if (hasSizes) ...[
                                        const SizedBox(height: 8),
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
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: const Color(0xFFE2E8F0),
                                                ),
                                              ),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    _sizeLabel(entry.key),
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    '${NumberFormat.decimalPattern().format(entry.value)} ج.س',
                                                    style: const TextStyle(
                                                      color: primaryColor,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      // الأزرار تحت الاسم والسعر مباشرة
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          GFIconButton(
                                            icon:
                                                const Icon(Icons.add, size: 18),
                                            onPressed: (isClosed ||
                                                    data['available'] == false)
                                                ? null
                                                : () async {
                                                    if (hasSizes) {
                                                      await _showSizePickerAndAddToCart(
                                                        cartProvider: cartProvider,
                                                        docId: doc.id,
                                                        itemName: itemName,
                                                        sizes: sizes,
                                                      );
                                                      return;
                                                    }
                                                    await cartProvider.addToCartSimple(
                                                      widget.restaurantId,
                                                      itemId,
                                                      itemName,
                                                      itemPrice,
                                                      menuItemId: doc.id,
                                                    );
                                                  },
                                            color: primaryColor,
                                            type: GFButtonType.outline,
                                            size: GFSize.SMALL,
                                            shape: GFIconButtonShape.circle,
                                            splashColor:
                                                accentColor.withOpacity(0.2),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8),
                                            child: Text(quantity.toString(),
                                                style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black)),
                                          ),
                                          GFIconButton(
                                            icon: const Icon(Icons.remove,
                                              size: 18),
                                            onPressed: (isClosed ||
                                                    data['available'] == false ||
                                                    quantity <= 0)
                                                ? null
                                                : () async {
                                                    if (hasSizes) {
                                                      await _showSizePickerAndRemoveFromCart(
                                                        cartProvider: cartProvider,
                                                        restaurantId: widget.restaurantId,
                                                        docId: doc.id,
                                                        itemName: itemName,
                                                      );
                                                      return;
                                                    }
                                                    await cartProvider
                                                        .removeOneItem(itemId);
                                                  },
                                            color: primaryColor,
                                            type: GFButtonType.outline,
                                            size: GFSize.SMALL,
                                            shape: GFIconButtonShape.circle,
                                            splashColor:
                                                closedColor.withOpacity(0.15),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: imageProvider != null
                                      ? Image(
                                          image: imageProvider,
                                          width: 95,
                                          height: 95,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          width: 95,
                                          height: 95,
                                          color: Colors.grey[200],
                                          child: Icon(Icons.fastfood,
                                              color: Colors.grey[500]),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: cartProvider.cartItems.isNotEmpty
            ? FloatingActionButton.extended(
                backgroundColor: primaryColor,
                icon: const Icon(Icons.shopping_cart),
                label: const Text('تأكيد الطلب'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ClientCartScreen(),
                    ),
                  );
                },
              )
            : null,
      ),
    );
  }
}
