import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:getwidget/getwidget.dart';
import 'package:provider/provider.dart';
import 'package:speedstar_core/الخدمات/مزود_السلة.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:speedstar_core/الشاشات/سلة_الطلب.dart';

class StoreDetailScreen extends StatefulWidget {
  final String restaurantId;
  final String name;
  final String image;
  final String offers;
  final String clientId;

  const StoreDetailScreen({
    Key? key,
    required this.restaurantId,
    required this.name,
    required this.image,
    required this.offers,
    required this.clientId,
  }) : super(key: key);

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  static const Color primaryColor = Color(0xFFFE724C);
  static const Color accentColor = Color(0xFFFFC529);
  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color cardColor = Colors.white;
  static const Color textColorPrimary = Color(0xFF1A1D26);
  static const Color textColorSecondary = Color(0xFF6B7280);
  static const Color closedColor = Color(0xFFFF3B30);

  String? _selectedCategory;
  bool isClosed = false;
  String statusText = '';
  Color statusColor = Colors.green;

  @override
  void initState() {
    super.initState();
    _checkRestaurantStatus();
  }

  Future<void> _checkRestaurantStatus() async {
    final doc = await FirebaseFirestore.instance
        .collection('restaurants')
        .doc(widget.restaurantId)
        .get();

    final data = doc.data();
    if (data == null) return;

    final closed = data['temporarilyClosed'] == true;
    final hours = data['workingHours'] as Map<String, dynamic>?;

    if (closed) {
      setState(() {
        isClosed = true;
        statusText = 'المطعم مغلق مؤقتًا';
        statusColor = Colors.orange;
      });
      return;
    }

    final now = DateTime.now();
    final todayKey = _getDayKey(now.weekday);
    final today = hours?[todayKey];

    if (today == null) {
      setState(() {
        isClosed = true;
        statusText = 'المطعم مغلق اليوم';
        statusColor = Colors.red;
      });
      return;
    }

    final open = _parseTime(today['open']);
    final close = _parseTime(today['close']);
    if (open == null || close == null) {
      setState(() {
        isClosed = true;
        statusText = 'المطعم مغلق - وقت غير معروف';
        statusColor = Colors.red;
      });
      return;
    }

    final nowMinutes = now.hour * 60 + now.minute;
    final openMinutes = open.hour * 60 + open.minute;
    final closeMinutes = close.hour * 60 + close.minute;

    if (nowMinutes < openMinutes || nowMinutes > closeMinutes) {
      setState(() {
        isClosed = true;
        statusText = 'المطعم مغلق الآن - يفتح الساعة ${today['open']}';
        statusColor = Colors.red;
      });
    }
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
                        : Image.asset('assets/images/default.png', fit: BoxFit.cover),
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
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                          return const Center(child: CircularProgressIndicator());
                        }
                        final items = snapshot.data!.docs;
                        // استخراج الفئات
                        final Set<String> categories = {'كل الأصناف'};
                        for (var doc in items) {
                          final data = doc.data() as Map<String, dynamic>;
                          if (data['category'] != null && data['category'].toString().isNotEmpty) {
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
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final cat = categoryList[index];
                              final selected = _selectedCategory == null
                                  ? cat == 'كل الأصناف'
                                  : _selectedCategory == cat;
                              return ChoiceChip(
                                label: Text(cat, style: TextStyle(fontWeight: FontWeight.bold)),
                                selected: selected,
                                onSelected: (val) {
                                  setState(() {
                                    _selectedCategory = cat == 'كل الأصناف' ? null : cat;
                                  });
                                },
                                selectedColor: primaryColor,
                                backgroundColor: Colors.grey[200],
                                labelStyle: TextStyle(
                                  color: selected ? Colors.white : textColorPrimary,
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
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('لا توجد أصناف متاحة حالياً.'));
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
                      final itemPrice = (data['price'] as num?)?.toDouble() ?? 0.0;
                      final itemImage = data['imageUrl'] ?? '';
                      final quantity = cartProvider.getQuantity(itemId);
                      final imageProvider = (itemImage.isNotEmpty)
                          ? NetworkImage(itemImage)
                          : const AssetImage('assets/images/default.png') as ImageProvider;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
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
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          // حالة التوفر: تظهر فقط إذا غير متوفر
                                          if (data['available'] == false)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: closedColor,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Text(
                                                'غير متوفر',
                                                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          // اسم الصنف
                                          Padding(
                                            padding: const EdgeInsets.only(right: 12),
                                            child: Text(
                                              itemName,
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColorPrimary, letterSpacing: 0.5, height: 1.2),
                                              textAlign: TextAlign.right,
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text('${NumberFormat.decimalPattern().format(itemPrice)} ج.س',
                                          style: TextStyle(color: textColorSecondary, fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.2)),
                                      const SizedBox(height: 8),
                                      // الأزرار تحت الاسم والسعر مباشرة
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          GFIconButton(
                                            icon: const Icon(Icons.add, size: 18),
                                            onPressed: (isClosed || data['available'] == false) ? null : () {
                                              cartProvider.addToCartSimple(itemId, itemName, itemPrice);
                                            },
                                            color: primaryColor,
                                            type: GFButtonType.outline,
                                            size: GFSize.SMALL,
                                            shape: GFIconButtonShape.circle,
                                            splashColor: accentColor.withOpacity(0.2),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            child: Text(quantity.toString(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black)),
                                          ),
                                          GFIconButton(
                                            icon: const Icon(Icons.remove, size: 18),
                                            onPressed: (isClosed || data['available'] == false) ? null : () {
                                              cartProvider.removeOneItem(itemId);
                                            },
                                            color: primaryColor,
                                            type: GFButtonType.outline,
                                            size: GFSize.SMALL,
                                            shape: GFIconButtonShape.circle,
                                            splashColor: closedColor.withOpacity(0.15),
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
                                  child: Image(
                                    image: imageProvider,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      width: 80,
                                      height: 80,
                                      color: Colors.grey[200],
                                      child: Icon(Icons.broken_image, color: Colors.grey[400]),
                                    ),
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
                      builder: (_) => const CartScreenArabic(),
                    ),
                  );
                },
              )
            : null,
      ),
    );
  }
}
