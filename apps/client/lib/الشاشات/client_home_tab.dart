import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:getwidget/getwidget.dart';

import 'restaurant_detail_screen.dart';
import 'client_notifications_screen.dart';
import 'address_selection_screen.dart';
import 'add_new_address_screen.dart';
import 'chat_screen.dart';

class ClientHomeTab extends StatefulWidget {
  final String clientId;
  final String? initialLocation;

  const ClientHomeTab({
    Key? key,
    required this.clientId,
    this.initialLocation,
  }) : super(key: key);

  @override
  _ClientHomeTabState createState() => _ClientHomeTabState();
}

class _ClientHomeTabState extends State<ClientHomeTab> {
  static const Color primaryColor = Color(0xFFFE724C);
  static const Color accentColor = Color(0xFFFFC529);
  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color cardColor = Colors.white;
  static const Color textColorPrimary = Color(0xFF1A1D26);
  static const Color textColorSecondary = Color(0xFF6B7280);
  static const Color openColor = Color(0xFF34C759);
  static const Color closedColor = Color(0xFFFF3B30);

  String _currentDisplayedLocation = "الخرطوم، السودان";

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null && widget.initialLocation!.isNotEmpty) {
      _currentDisplayedLocation = widget.initialLocation!;
    }
    _refreshDefaultAddress();
    _checkAndForceAddress();
  }

  Future<void> _refreshDefaultAddress() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('clients')
          .doc(widget.clientId)
          .get();
      final defaultAddressId = doc.data()?['defaultAddressId'];
      if (defaultAddressId != null) {
        final addressDoc = await FirebaseFirestore.instance
            .collection('clients')
            .doc(widget.clientId)
            .collection('addresses')
            .doc(defaultAddressId)
            .get();
        final addressName = addressDoc.data()?['addressName'] ?? 'عنوان بدون اسم';
        if (!mounted) return;
        setState(() {
          _currentDisplayedLocation = addressName;
        });
      }
    } on FirebaseException catch (e) {
      debugPrint('تعذر جلب العنوان الافتراضي: ${e.code} - ${e.message}');
    } catch (e) {
      debugPrint('تعذر جلب العنوان الافتراضي: $e');
    }
  }

  // التحقق من وجود عنوان وإجبار المستخدم على إضافة عنوان إذا لم يوجد
  Future<void> _checkAndForceAddress() async {
    try {
      final addressesSnapshot = await FirebaseFirestore.instance
          .collection('clients')
          .doc(widget.clientId)
          .collection('addresses')
          .limit(1)
          .get();
      if (addressesSnapshot.docs.isEmpty && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddNewAddressScreen(
              userId: widget.clientId,
              userType: 'client',
            ),
          ),
        );
        if (!mounted) return;
        // بعد إضافة العنوان، أعد التحقق (في حال أغلق المستخدم الشاشة بدون إضافة)
        _checkAndForceAddress();
      }
    } on FirebaseException catch (e) {
      debugPrint('تعذر التحقق من العناوين: ${e.code} - ${e.message}');
    } catch (e) {
      debugPrint('تعذر التحقق من العناوين: $e');
    }
  }

  // دالة لجلب جميع الوجبات من subcollection full_menu لكل مطعم
  Future<List<Map<String, dynamic>>> fetchAllMeals(List<Map<String, dynamic>> restaurants) async {
    List<Map<String, dynamic>> allMeals = [];
    for (final r in restaurants) {
      final restaurantId = r['id'];
      if (restaurantId != null) {
        final mealsSnapshot = await FirebaseFirestore.instance
            .collection('restaurants')
            .doc(restaurantId)
            .collection('full_menu')
            .get();
        for (final doc in mealsSnapshot.docs) {
          final data = doc.data();
          if ((data['name']?.toString() ?? '').isNotEmpty) {
            allMeals.add({
              'type': 'meal',
              'name': data['name'].toString(),
              'restaurant': r,
              'meal': data,
            });
          }
        }
      }
    }
    return allMeals;
  }

  // مراقبة حذف جميع العناوين أثناء الاستخدام
  Stream<bool> get _hasNoAddressesStream {
    return FirebaseFirestore.instance
        .collection('clients')
        .doc(widget.clientId)
        .collection('addresses')
        .snapshots()
        .map((snapshot) => snapshot.docs.isEmpty);
  }

  @override
  Widget build(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;

    return StreamBuilder<bool>(
      stream: _hasNoAddressesStream,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data == true) {
          Future.microtask(() async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddNewAddressScreen(
                  userId: widget.clientId,
                  userType: 'client',
                ),
              ),
            );
          });
          return const Center(child: CircularProgressIndicator());
        }
        // الكود الأصلي كما هو:
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: backgroundColor,
            body: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('restaurants')
                  .snapshots(),
              builder: (ctx, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'لا توجد مطاعم متاحة حالياً',
                      style: TextStyle(
                        fontSize: 16,
                        color: textColorSecondary,
                      ),
                    ),
                  );
                }

                final restaurants = snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return {
                    'id': doc.id,
                    ...data,
                    'image': data['logoImageUrl'] ?? '', // تمرير شعار المطعم للحقل image
                  };
                }).toList();

                return SafeArea(
                  child: CustomScrollView(
                    physics: BouncingScrollPhysics(),
                    slivers: [
                      SliverAppBar(
                        expandedHeight: 180,
                        floating: true,
                        pinned: false,
                        backgroundColor: backgroundColor,
                        elevation: 0,
                        flexibleSpace: LayoutBuilder(
                          builder: (BuildContext context, BoxConstraints constraints) {
                            return SingleChildScrollView(
                              physics: NeverScrollableScrollPhysics(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(height: topPadding),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                    child: _buildTopBar(context),
                                  ),
                                  const SizedBox(height: 4),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                    child: FutureBuilder<List<Map<String, dynamic>>>(
                                      future: fetchAllMeals(restaurants),
                                      builder: (context, mealSnapshot) {
                                        if (mealSnapshot.connectionState == ConnectionState.waiting) {
                                          return Center(child: CircularProgressIndicator(color: primaryColor));
                                        }
                                        final allMeals = mealSnapshot.data ?? [];
                                        // دمج المطاعم والوجبات في قائمة البحث
                                        final List<Map<String, dynamic>> searchItems = [
                                          ...restaurants.map((r) => {
                                            'type': 'restaurant',
                                            'name': r['name'].toString(),
                                            'restaurant': r,
                                          }),
                                          ...allMeals
                                        ];
                                        return _buildSearchBar(context, searchItems);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _buildSectionHeader(Icons.local_offer, 'عروضنا لك', textColorPrimary),
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
                        sliver: SliverToBoxAdapter(
                          child: SizedBox(
                            height: 200,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: restaurants.length,
                              reverse: true,
                              physics: BouncingScrollPhysics(),
                              itemBuilder: (ctx, idx) {
                                final r = restaurants[idx];
                                final imageProvider = (r['image']?.toString().isNotEmpty ?? false)
                                    ? NetworkImage(r['image'].toString())
                                    : const AssetImage('assets/images/default.png') as ImageProvider;
                                return _buildRestaurantCard(context, r, imageProvider);
                              },
                            ),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverToBoxAdapter(
                          child: _buildSectionHeader(
                            Icons.restaurant,
                            'المطاعم',
                            textColorPrimary,
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, idx) {
                              final r = restaurants[idx];
                              final imageProvider = (r['image']?.toString().isNotEmpty ?? false)
                                  ? NetworkImage(r['image'].toString())
                                  : const AssetImage('assets/images/default.png') as ImageProvider;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 15),
                                child: _buildRestaurantListTile(
                                  context,
                                  r,
                                  imageProvider,
                                ),
                              );
                            },
                            childCount: restaurants.length,
                          ),
                        ),
                      ),
                    ], // تأكد من إغلاق قائمة slivers هنا
                  ), // إغلاق CustomScrollView
                ); // إغلاق SafeArea
              }, // إغلاق builder الخاص بـ StreamBuilder<QuerySnapshot>
            ), // إغلاق body: StreamBuilder
          ), // إغلاق Scaffold
        ); // إغلاق Directionality
      }, // إغلاق builder الخاص بـ StreamBuilder<bool>
    ); // إغلاق StreamBuilder<bool>
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // زر الدعم في الأعلى
        IconButton(
          icon: const Icon(Icons.support_agent, color: primaryColor, size: 28),
          tooltip: 'تواصل مع الدعم',
          onPressed: () async {
            // جلب اسم العميل من قاعدة البيانات
            final doc = await FirebaseFirestore.instance.collection('clients').doc(widget.clientId).get();
            final clientName = doc.data()?['name'] ?? 'عميل';
            final chatId = '${widget.clientId}-support';
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  currentUserId: widget.clientId,
                  otherUserId: 'support',
                  currentUserRole: 'client',
                  chatId: chatId,
                  currentUserName: clientName,
                ),
              ),
            );
          },
        ),
        GestureDetector(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddressSelectionScreen(
                  userId: widget.clientId,
                  userType: 'client',
                  isSelecting: true,
                ),
              ),
            );
            // بعد العودة من شاشة العناوين، جلب العنوان الافتراضي من قاعدة البيانات
            await _refreshDefaultAddress();
          },
          child: Row(
            children: [
              Text(
                _currentDisplayedLocation,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: textColorSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.location_on_outlined, color: primaryColor, size: 20),
            ],
          ),
        ),
        IconButton(
          icon: Stack(
            children: [
              Icon(Icons.notifications_none, size: 28, color: textColorPrimary),
              Positioned(
                top: 2,
                left: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
              )
            ],
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ClientNotificationsScreen(clientId: widget.clientId),
              ),
            );
          },
        ),
      ],
    );
  }

  // تحسين البحث ليشمل المطاعم والوجبات
  Widget _buildSearchBar(
    BuildContext context,
    List<Map<String, dynamic>> searchItems,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white, // خلفية بيضاء واضحة
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 12,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
        child: GFSearchBar<String?>(
          searchList: searchItems.map<String?>((e) => e['name'] as String?).where((name) => name != null && name.trim().isNotEmpty).toSet().toList(),
          searchQueryBuilder: (String query, List<String?> list) async {
            final normalizedQuery = query.trim().toLowerCase();
            if (normalizedQuery.isEmpty) return <String?>[];
            return list.where((item) {
              final normalizedItem = (item ?? '').trim().toLowerCase();
              return normalizedItem.contains(normalizedQuery);
            }).toList();
          },
          overlaySearchListItemBuilder: (String? item) {
            if (item == null || item.trim().isEmpty) return const SizedBox.shrink();
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                item,
                style: TextStyle(
                  color: textColorPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Tajawal',
                ),
                textAlign: TextAlign.right,
              ),
            );
          },
          onItemSelected: (selected) async {
            final meals = searchItems.where((e) => e['type'] == 'meal' && e['name'] == selected).toList();
            if (meals.isNotEmpty) {
              final restaurantsWithMeal = meals.map((e) => e['restaurant']).toSet().toList();
              await showModalBottomSheet(
                context: context,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                builder: (ctx) => ListView.builder(
                  shrinkWrap: true,
                  itemCount: restaurantsWithMeal.length,
                  itemBuilder: (ctx, idx) {
                    final r = restaurantsWithMeal[idx];
                    return ListTile(
                      title: Text(r['name'] ?? '', textAlign: TextAlign.right),
                      onTap: () {
                        Navigator.pop(ctx);
                        _openRestaurantDetail(context, r);
                      },
                    );
                  },
                ),
              );
            } else {
              final idx = searchItems.indexWhere((e) => e['name'] == selected);
              if (idx != -1) {
                final item = searchItems[idx];
                if (item['type'] == 'restaurant') {
                  _openRestaurantDetail(context, item['restaurant']);
                }
              }
            }
          },
          searchBoxInputDecoration: InputDecoration(
            hintText: 'ابحث عن مطعم أو وجبة...',
            hintStyle: TextStyle(color: Colors.grey[600], fontSize: 16, fontFamily: 'Tajawal'),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: true,
            fillColor: Colors.white,
            prefixIcon: Icon(Icons.search, color: primaryColor, size: 28),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start, // محاذاة لليمين العربي
      children: [
        Icon(icon, color: primaryColor, size: 24),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.right,
        ),
      ],
    );
  }

  Widget _buildRestaurantCard(
    BuildContext context,
    Map<String, dynamic> r,
    ImageProvider imageProvider,
  ) {
    final status = getRestaurantStatus(r);
    final isOpen = status.contains('مفتوح');

    return GestureDetector(
      onTap: () => _openRestaurantDetail(context, r),
      child: Container(
        width: 180,
        margin: const EdgeInsets.only(left: 15),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                children: [
                  Image(
                    image: imageProvider,
                    width: double.infinity,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: double.infinity,
                      height: 120,
                      color: Colors.grey[200],
                      child: Icon(Icons.broken_image, color: Colors.grey[400]),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isOpen ? openColor : closedColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isOpen ? 'مفتوح' : 'مغلق',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (r['hasOffers'] == true)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'عرض',
                          style: TextStyle(
                            color: textColorPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      r['name']?.toString() ?? 'اسم غير متاح',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: textColorPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '4.5',
                          style: TextStyle(
                            fontSize: 13,
                            color: textColorSecondary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.star_rounded, color: accentColor, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'مجاني',
                          style: TextStyle(
                            fontSize: 13,
                            color: textColorSecondary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.delivery_dining, color: textColorSecondary.withOpacity(0.7), size: 18),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantListTile(
    BuildContext context,
    Map<String, dynamic> r,
    ImageProvider imageProvider,
  ) {
    final status = getRestaurantStatus(r);
    final isOpen = status.contains('مفتوح');

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openRestaurantDetail(context, r),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    r['name']?.toString() ?? 'اسم غير متاح',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: textColorPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    r['offers']?.toString() ?? 'عروض مميزة',
                    style: TextStyle(
                      color: textColorSecondary,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '4.5',
                        style: TextStyle(
                          fontSize: 13,
                          color: textColorSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.star_rounded, color: accentColor, size: 18),
                      const SizedBox(width: 12),
                      Text(
                        '30-45 دقيقة',
                        style: TextStyle(
                          fontSize: 13,
                          color: textColorSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.access_time, color: textColorSecondary.withOpacity(0.7), size: 18),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isOpen ? openColor.withOpacity(0.15) : closedColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isOpen ? 'مفتوح الآن' : 'مغلق الآن',
                        style: TextStyle(
                          color: isOpen ? openColor : closedColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 15),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image(
                image: imageProvider,
                width: 90,
                height: 90,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 90,
                  height: 90,
                  color: Colors.grey[200],
                  child: Icon(Icons.broken_image, color: Colors.grey[400]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openRestaurantDetail(BuildContext context, Map<String, dynamic> r) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RestaurantDetailScreen(
          restaurantId: r['id'],
          name: r['name']?.toString() ?? '',
          image: r['image']?.toString() ?? '',
          offers: r['offers']?.toString() ?? '',
          clientId: widget.clientId,
        ),
      ),
    );
  }

  String getRestaurantStatus(Map<String, dynamic> data) {
    final temporarilyClosed = data['temporarilyClosed'] == true;
    final workingHours = data['workingHours'] as Map<String, dynamic>?;

    if (temporarilyClosed) return 'مغلق مؤقتًا';

    final now = DateTime.now();
    final todayKey = _getDayKey(now.weekday);
    final todayHours = workingHours?[todayKey];

    if (todayHours == null) return 'مغلق اليوم';

    final openStr = todayHours['open'] ?? '';
    final closeStr = todayHours['close'] ?? '';

    if (openStr.isEmpty || closeStr.isEmpty) return 'مغلق';

    final open = _parseArabicTime(openStr);
    final close = _parseArabicTime(closeStr);

    if (open == null || close == null) return 'مغلق - خطأ في الوقت';

    final nowMinutes = now.hour * 60 + now.minute;
    final openMinutes = open.hour * 60 + open.minute;
    int closeMinutesAdjusted = close.hour * 60 + close.minute;
    if (closeMinutesAdjusted < openMinutes) {
      closeMinutesAdjusted += 24 * 60;
    }

    if (nowMinutes >= openMinutes && nowMinutes < closeMinutesAdjusted) {
      return 'مفتوح الآن';
    } else if (nowMinutes < openMinutes) {
      return 'مغلق الآن - يفتح الساعة $openStr';
    } else {
      return 'مغلق الآن - يغلق الساعة $closeStr';
    }
  }

  TimeOfDay? _parseArabicTime(String time) {
    try {
      String cleanedTime = time.replaceAll('ص', 'AM').replaceAll('م', 'PM').trim();
      final parts = cleanedTime.split(':');
      if (parts.length != 2) return null;

      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1].substring(0, 2));

      bool isPM = cleanedTime.contains('PM');
      bool isAM = cleanedTime.contains('AM');

      if (isPM && hour < 12) {
        hour += 12;
      } else if (isAM && hour == 12) {
        hour = 0;
      }

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
}