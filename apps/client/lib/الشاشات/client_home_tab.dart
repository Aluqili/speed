import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:geolocator/geolocator.dart';
import 'package:getwidget/getwidget.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';

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
  static const Color primaryColor = AppThemeArabic.clientPrimary;
  static const Color accentColor = AppThemeArabic.clientAccent;
  static const Color backgroundColor = AppThemeArabic.clientBackground;
  static const Color cardColor = Colors.white;
  static const Color textColorPrimary = AppThemeArabic.clientTextPrimary;
  static const Color textColorSecondary = AppThemeArabic.clientTextSecondary;
  static const Color openColor = AppThemeArabic.clientSuccess;
  static const Color closedColor = AppThemeArabic.clientError;

  String _currentDisplayedLocation = "الخرطوم، السودان";
  double? _clientLatitude;
  double? _clientLongitude;
  String? _clientStateId;
  bool _addressStateResolved = false;
  final List<String> _recentSearches = [];
  static const double _defaultFallbackVisibleDistanceKm = 120;

  double get _fallbackVisibleDistanceKm {
    try {
      final value =
          FirebaseRemoteConfig.instance.getDouble('client_state_guard_distance_km');
      return value > 0 ? value : _defaultFallbackVisibleDistanceKm;
    } catch (_) {
      return _defaultFallbackVisibleDistanceKm;
    }
  }

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
      final clientData = doc.data() ?? <String, dynamic>{};
      final defaultAddressId = clientData['defaultAddressId'];

      DocumentSnapshot<Map<String, dynamic>>? addressDoc;
      if (defaultAddressId != null && defaultAddressId.toString().isNotEmpty) {
        addressDoc = await FirebaseFirestore.instance
            .collection('clients')
            .doc(widget.clientId)
            .collection('addresses')
            .doc(defaultAddressId.toString())
            .get();
      }

      if (addressDoc == null || !addressDoc.exists) {
        final firstAddress = await FirebaseFirestore.instance
            .collection('clients')
            .doc(widget.clientId)
            .collection('addresses')
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();
        if (firstAddress.docs.isNotEmpty) {
          addressDoc = firstAddress.docs.first;
        }
      }

      if (!mounted || addressDoc == null || !addressDoc.exists) return;

      final addressData = addressDoc.data() ?? <String, dynamic>{};
      final addressName =
          (addressData['addressName'] ?? 'عنوان بدون اسم').toString();
      final lat = (addressData['latitude'] as num?)?.toDouble();
      final lng = (addressData['longitude'] as num?)?.toDouble();
      final stateId = _normalizeStateId(
        addressData['stateId'] ??
            addressData['state'] ??
            addressData['city'] ??
            addressData['administrativeArea'],
      );

      setState(() {
        _currentDisplayedLocation = addressName;
        _clientLatitude = lat;
        _clientLongitude = lng;
        _clientStateId = stateId;
        _addressStateResolved = true;
      });
    } on FirebaseException catch (e) {
      debugPrint('تعذر جلب العنوان الافتراضي: ${e.code} - ${e.message}');
    } catch (e) {
      debugPrint('تعذر جلب العنوان الافتراضي: $e');
    } finally {
      if (mounted && !_addressStateResolved) {
        setState(() {
          _addressStateResolved = true;
        });
      }
    }
  }

  bool get _isStateRolloutEnabled {
    try {
      return FirebaseRemoteConfig.instance.getBool('client_state_rollout_enabled');
    } catch (_) {
      return false;
    }
  }

  String get _stateRolloutBlockMessage {
    const fallback =
        'لسه ما جيناكم في الولاية يا غالي\nتابعنا على منصات التواصل عشان تعرف حنجيكم متين\nوقريباً حنصلكم.. انتظرونا! ❤️';
    try {
      final value = FirebaseRemoteConfig.instance
          .getString('client_state_rollout_block_message')
          .trim();
      return value.isNotEmpty ? value : fallback;
    } catch (_) {
      return fallback;
    }
  }

  Set<String> get _enabledStatesFromRemote {
    try {
      final raw =
          FirebaseRemoteConfig.instance.getString('client_enabled_states_csv');
      if (raw.trim().isEmpty) {
        return <String>{};
      }
      final parts = raw
          .split(RegExp(r'[,;\n|]'))
          .map(_normalizeStateId)
          .where((value) => value.isNotEmpty)
          .toSet();
      return parts;
    } catch (_) {
      return <String>{};
    }
  }

  bool _isClientStateEnabledForRollout() {
    final clientState = (_clientStateId ?? '').trim();
    if (clientState.isEmpty) {
      return false;
    }
    final enabledStates = _enabledStatesFromRemote;
    return enabledStates.contains(clientState);
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
  Future<List<Map<String, dynamic>>> fetchAllMeals(
      List<Map<String, dynamic>> restaurants) async {
    List<Map<String, dynamic>> allMeals = [];
    for (final r in restaurants) {
      final restaurantId = r['id'];
      if (restaurantId != null) {
        try {
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
        } on FirebaseException {
          continue;
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

  String _normalizeSearchText(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\u064B-\u0652]'), '')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي');
  }

  int _searchScore(String query, String text) {
    if (query.isEmpty || text.isEmpty) return 0;
    if (text == query) return 1200;
    if (text.startsWith(query)) return 900;
    if (text.contains(' $query')) return 700;
    if (text.contains(query)) return 450;
    final qTokens = query.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (qTokens.isEmpty) return 0;
    var tokenHits = 0;
    for (final token in qTokens) {
      if (text.contains(token)) tokenHits += 1;
    }
    if (tokenHits == 0) return 0;
    return 250 + (tokenHits * 60);
  }

  List<Map<String, dynamic>> _buildSearchEntries(List<Map<String, dynamic>> searchItems) {
    final entries = <Map<String, dynamic>>[];
    final labelsSeen = <String>{};

    for (final item in searchItems) {
      final type = (item['type'] ?? '').toString();
      final name = (item['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;

      final restaurant = (item['restaurant'] as Map<String, dynamic>?) ??
          (type == 'restaurant' ? item['restaurant'] as Map<String, dynamic>? : null) ??
          (type == 'restaurant' ? item : null);
      final restaurantName = (restaurant?['name'] ?? '').toString().trim();
      final offers = (restaurant?['offers'] ?? '').toString().trim();
      final category = (item['meal']?['category'] ?? item['category'] ?? '').toString().trim();

      String label = type == 'meal'
          ? '🍽 $name — ${restaurantName.isNotEmpty ? restaurantName : 'مطعم'}'
          : '🏬 $name';
      if (labelsSeen.contains(label)) {
        label = '$label (${entries.length + 1})';
      }
      labelsSeen.add(label);

      final searchBlob = [name, restaurantName, offers, category]
          .where((e) => e.isNotEmpty)
          .join(' ');

      entries.add({
        'label': label,
        'type': type,
        'name': name,
        'restaurant': restaurant,
        'searchText': _normalizeSearchText(searchBlob),
        'subtitle': type == 'meal'
            ? (category.isNotEmpty ? '$restaurantName · $category' : restaurantName)
            : (offers.isNotEmpty ? offers : 'مطعم'),
      });
    }

    return entries;
  }

  void _rememberSearch(String label) {
    _recentSearches.remove(label);
    _recentSearches.insert(0, label);
    if (_recentSearches.length > 6) {
      _recentSearches.removeRange(6, _recentSearches.length);
    }
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
        if (_isStateRolloutEnabled && !_addressStateResolved) {
          return const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (_isStateRolloutEnabled && !_isClientStateEnabledForRollout()) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              backgroundColor: backgroundColor,
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_off_rounded,
                        size: 64,
                        color: primaryColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _stateRolloutBlockMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          height: 1.7,
                          fontWeight: FontWeight.w700,
                          color: textColorPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        // الكود الأصلي كما هو:
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: backgroundColor,
            body: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('restaurants')
                  .where('approvalStatus', isEqualTo: 'approved')
                  .where('menuEverApproved', isEqualTo: true)
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
                  final distanceKm = _distanceKmToRestaurant(data);
                  final restaurantStateId = _restaurantStateId(data);
                  return {
                    'id': doc.id,
                    ...data,
                    'distanceKm': distanceKm,
                    'stateId': restaurantStateId,
                    'image': data['logoImageUrl'] ??
                        '', // تمرير شعار المطعم للحقل image
                  };
                }).where((restaurant) {
                  final clientState = _clientStateId;
                  if (clientState == null || clientState.isEmpty) {
                    return true;
                  }
                  final restaurantState =
                      (restaurant['stateId'] as String?)?.trim() ?? '';
                  if (restaurantState.isEmpty) {
                    final distanceKm = restaurant['distanceKm'] as double?;
                    return distanceKm != null &&
                        distanceKm <= _fallbackVisibleDistanceKm;
                  }
                  return restaurantState == clientState;
                }).toList();

                restaurants.sort((a, b) {
                  final da = (a['distanceKm'] as double?);
                  final db = (b['distanceKm'] as double?);
                  if (da == null && db == null) return 0;
                  if (da == null) return 1;
                  if (db == null) return -1;
                  return da.compareTo(db);
                });

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
                          builder: (BuildContext context,
                              BoxConstraints constraints) {
                            return SingleChildScrollView(
                              physics: NeverScrollableScrollPhysics(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(height: topPadding),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0),
                                    child: _buildTopBar(context),
                                  ),
                                  const SizedBox(height: 4),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0),
                                    child: FutureBuilder<
                                        List<Map<String, dynamic>>>(
                                      future: fetchAllMeals(restaurants),
                                      builder: (context, mealSnapshot) {
                                        if (mealSnapshot.connectionState ==
                                            ConnectionState.waiting) {
                                          return Center(
                                              child: CircularProgressIndicator(
                                                  color: primaryColor));
                                        }
                                        final allMeals =
                                            mealSnapshot.data ?? [];
                                        // دمج المطاعم والوجبات في قائمة البحث
                                        final List<Map<String, dynamic>>
                                            searchItems = [
                                          ...restaurants.map((r) => {
                                                'type': 'restaurant',
                                                'name': r['name'].toString(),
                                                'restaurant': r,
                                              }),
                                          ...allMeals
                                        ];
                                        return _buildSearchBar(
                                            context, searchItems);
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _buildSectionHeader(Icons.local_offer,
                                  'عروضنا لك', textColorPrimary),
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.only(
                            left: 16, right: 16, bottom: 20),
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
                                final imageProvider =
                                    (r['image']?.toString().isNotEmpty ?? false)
                                        ? NetworkImage(r['image'].toString())
                                        : null;
                                return _buildRestaurantCard(
                                    context, r, imageProvider);
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
                              final imageProvider =
                                  (r['image']?.toString().isNotEmpty ?? false)
                                      ? NetworkImage(r['image'].toString())
                                      : null;

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
            final doc = await FirebaseFirestore.instance
                .collection('clients')
                .doc(widget.clientId)
                .get();
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
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('clients')
              .doc(widget.clientId)
              .collection('notifications')
              .orderBy('timestamp', descending: true)
              .limit(50)
              .snapshots(),
          builder: (context, snapshot) {
            final hasUnread = (snapshot.data?.docs ?? const [])
                .any((doc) => doc.data()['isRead'] != true);

            return IconButton(
              icon: Stack(
                children: [
                  Icon(Icons.notifications_none, size: 28, color: textColorPrimary),
                  if (hasUnread)
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
                    builder: (_) =>
                        ClientNotificationsScreen(clientId: widget.clientId),
                  ),
                );
              },
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
    final entries = _buildSearchEntries(searchItems);
    final labels = entries.map((e) => e['label'].toString()).toList(growable: false);
    final entryByLabel = <String, Map<String, dynamic>>{
      for (final e in entries) e['label'].toString(): e,
    };

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
          searchList: labels,
          searchQueryBuilder: (String query, List<String?> list) async {
            final normalizedQuery = _normalizeSearchText(query);
            if (normalizedQuery.isEmpty) {
              return _recentSearches.where((label) => entryByLabel.containsKey(label)).toList();
            }

            final scored = <MapEntry<String, int>>[];
            for (final raw in list) {
              final label = (raw ?? '').trim();
              if (label.isEmpty) continue;
              final entry = entryByLabel[label];
              if (entry == null) continue;
              final score = _searchScore(normalizedQuery, entry['searchText'].toString());
              if (score > 0) {
                scored.add(MapEntry(label, score));
              }
            }

            scored.sort((a, b) {
              final byScore = b.value.compareTo(a.value);
              if (byScore != 0) return byScore;
              return a.key.length.compareTo(b.key.length);
            });

            return scored.take(25).map((e) => e.key).toList();
          },
          overlaySearchListItemBuilder: (String? item) {
            if (item == null || item.trim().isEmpty)
              return const SizedBox.shrink();
            final entry = entryByLabel[item];
            final subtitle = (entry?['subtitle'] ?? '').toString();
            final type = (entry?['type'] ?? '').toString();
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    item,
                    style: TextStyle(
                      color: textColorPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Tajawal',
                    ),
                    textAlign: TextAlign.right,
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: textColorSecondary,
                        fontSize: 12,
                        fontFamily: 'Tajawal',
                      ),
                      textAlign: TextAlign.right,
                    ),
                  if (type.isNotEmpty)
                    Text(
                      type == 'meal' ? 'وجبة' : 'مطعم',
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Tajawal',
                      ),
                      textAlign: TextAlign.right,
                    ),
                ],
              ),
            );
          },
          onItemSelected: (selected) async {
            if (selected == null || selected.trim().isEmpty) return;
            final entry = entryByLabel[selected];
            if (entry == null) return;

            _rememberSearch(selected);

            if (entry['type'] == 'restaurant') {
              final restaurant = entry['restaurant'] as Map<String, dynamic>?;
              if (restaurant != null) {
                _openRestaurantDetail(context, restaurant);
              }
              return;
            }

            if (entry['type'] == 'meal') {
              final restaurant = entry['restaurant'] as Map<String, dynamic>?;
              if (restaurant != null) {
                _openRestaurantDetail(context, restaurant);
              }
            }
          },
          searchBoxInputDecoration: InputDecoration(
            hintText: 'ابحث عن مطعم، وجبة، أو عرض...',
            hintStyle: TextStyle(
                color: Colors.grey[600], fontSize: 16, fontFamily: 'Tajawal'),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: true,
            fillColor: Colors.white,
            prefixIcon: Icon(Icons.search, color: primaryColor, size: 28),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
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
    ImageProvider? imageProvider,
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
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                children: [
                  if (imageProvider != null)
                    Image(
                      image: imageProvider,
                      width: double.infinity,
                      height: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: double.infinity,
                        height: 120,
                        color: Colors.grey[200],
                        child:
                            Icon(Icons.broken_image, color: Colors.grey[400]),
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      height: 120,
                      color: Colors.grey[200],
                      child: Icon(Icons.storefront,
                          color: Colors.grey[500], size: 36),
                    ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
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
                          _distanceText(r['distanceKm'] as double?),
                          style: TextStyle(
                            fontSize: 13,
                            color: textColorSecondary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.near_me,
                            color: textColorSecondary.withOpacity(0.7),
                            size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '4.5',
                          style: TextStyle(
                            fontSize: 13,
                            color: textColorSecondary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.star_rounded, color: accentColor, size: 18),
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
    ImageProvider? imageProvider,
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
                        _distanceText(r['distanceKm'] as double?),
                        style: TextStyle(
                          fontSize: 13,
                          color: textColorSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.near_me,
                          color: textColorSecondary.withOpacity(0.7), size: 18),
                      const SizedBox(width: 12),
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
                      Icon(Icons.access_time,
                          color: textColorSecondary.withOpacity(0.7), size: 18),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isOpen
                            ? openColor.withOpacity(0.15)
                            : closedColor.withOpacity(0.15),
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
              child: imageProvider != null
                  ? Image(
                      image: imageProvider,
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 90,
                        height: 90,
                        color: Colors.grey[200],
                        child:
                            Icon(Icons.broken_image, color: Colors.grey[400]),
                      ),
                    )
                  : Container(
                      width: 90,
                      height: 90,
                      color: Colors.grey[200],
                      child: Icon(Icons.storefront, color: Colors.grey[500]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  double? _distanceKmToRestaurant(Map<String, dynamic> restaurantData) {
    final clientLat = _clientLatitude;
    final clientLng = _clientLongitude;
    if (clientLat == null || clientLng == null) return null;

    double? restLat;
    double? restLng;

    final geo = restaurantData['location'];
    if (geo is GeoPoint) {
      restLat = geo.latitude;
      restLng = geo.longitude;
    }

    restLat ??= (restaurantData['restaurantLat'] as num?)?.toDouble();
    restLng ??= (restaurantData['restaurantLng'] as num?)?.toDouble();
    restLat ??= (restaurantData['latitude'] as num?)?.toDouble();
    restLng ??= (restaurantData['longitude'] as num?)?.toDouble();
    restLat ??= (restaurantData['lat'] as num?)?.toDouble();
    restLng ??= (restaurantData['lng'] as num?)?.toDouble();

    if (restLat == null || restLng == null) return null;

    final meters = Geolocator.distanceBetween(
      clientLat,
      clientLng,
      restLat,
      restLng,
    );
    return meters / 1000;
  }

  String _distanceText(double? distanceKm) {
    if (distanceKm == null) return 'المسافة غير متاحة';
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()} م';
    }
    return '${distanceKm.toStringAsFixed(1)} كم';
  }

  String _restaurantStateId(Map<String, dynamic> restaurantData) {
    return _normalizeStateId(
      restaurantData['stateId'] ??
          restaurantData['state'] ??
          restaurantData['region'] ??
          restaurantData['city'],
    );
  }

  String _normalizeStateId(dynamic raw) {
    final value = (raw ?? '').toString().trim();
    if (value.isEmpty) return '';
    final normalized = value
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .toLowerCase();

    const khartoumAliases = {
      'الخرطوم',
      'خرطوم',
      'khartoum',
      'khartum',
      'بحري',
      'bahri',
      'khartoum north',
      'ام درمان',
      'امدرمان',
      'ام درمان الكبرى',
      'omdurman',
      'omdorman',
      'oum durman',
    };
    if (khartoumAliases.contains(normalized)) {
      return 'khartoum';
    }
    return normalized;
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
      String cleanedTime =
          time.replaceAll('ص', 'AM').replaceAll('م', 'PM').trim();
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
