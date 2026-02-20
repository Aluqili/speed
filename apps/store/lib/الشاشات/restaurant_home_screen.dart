import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';

import 'store_settings_screen.dart';
import 'store_add_menu_item_screen.dart';
import 'store_full_menu_screen.dart';
import 'store_working_hours_screen.dart';
import 'store_wallet_screen.dart';
import 'chat_screen.dart';
import 'store_current_orders_screen.dart';

const Color primaryColor = Color(0xFFFE724C);
const Color backgroundColor = Color(0xFFF5F5F5);
const _statusPriority = [
  'قيد المراجعة',
  'قيد التجهيز',
  'قيد التوصيل',
  'بانتظار المطعم',
  'تم التوصيل',
  'ملغي',
  'انتظار الدفع',
];

class StoreDashboardScreen extends StatefulWidget {
  final String restaurantId;
  const StoreDashboardScreen({Key? key, required this.restaurantId})
      : super(key: key);

  @override
  State<StoreDashboardScreen> createState() => _StoreDashboardScreenState();
}

class _StoreDashboardScreenState extends State<StoreDashboardScreen> {
  // إعادة تحميل بيانات المطعم عند فتح القائمة الجانبية
  void _onDrawerChanged(bool isOpened) {
    if (isOpened) {
      _loadRestaurantInfo();
    }
  }
  bool temporarilyClosed = false;
  bool autoAcceptOrders = false;
  Set<String> notifiedOrders = {}; // لمنع تكرار الجرس لنفس الطلب
  final AudioPlayer _audioPlayer = AudioPlayer();

  String? restaurantName;
  String? logoUrl;

  @override
  void initState() {
    super.initState();
    _saveRestaurantId();
    _checkUserRole();
    _loadTemporaryStatus();
    _loadAutoAccept();
    _loadRestaurantInfo();
  }

  Future<void> _saveRestaurantId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('restaurantId', widget.restaurantId);
  }

  Future<void> _checkUserRole() async {
    if (FirebaseAuth.instance.currentUser == null) {
      Get.offAllNamed('/login');
    }
  }

  Future<void> _loadTemporaryStatus() async {
    final doc = await FirebaseFirestore.instance
        .collection('restaurants')
        .doc(widget.restaurantId)
        .get();
    setState(() => temporarilyClosed = doc['temporarilyClosed'] == true);
  }

  Future<void> _toggleTemporaryClosure(bool value) async {
    setState(() => temporarilyClosed = value);
    await FirebaseFirestore.instance
        .collection('restaurants')
        .doc(widget.restaurantId)
        .update({'temporarilyClosed': value});
  }

  Future<void> _loadAutoAccept() async {
    final doc = await FirebaseFirestore.instance
        .collection('restaurants')
        .doc(widget.restaurantId)
        .get();
    setState(() {
      autoAcceptOrders = doc['autoAcceptOrders'] == true;
    });
    // استمع لأي تغيير في الإعدادات
    FirebaseFirestore.instance
        .collection('restaurants')
        .doc(widget.restaurantId)
        .snapshots()
        .listen((doc) {
      setState(() {
        autoAcceptOrders = doc['autoAcceptOrders'] == true;
      });
    });
  }

  Future<void> _loadRestaurantInfo() async {
    final doc = await FirebaseFirestore.instance
        .collection('restaurants')
        .doc(widget.restaurantId)
        .get();
    if (doc.exists) {
      setState(() {
        restaurantName = doc['name'] ?? null;
        logoUrl = doc['logoImageUrl'] ?? null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
  backgroundColor: backgroundColor,
  onDrawerChanged: _onDrawerChanged,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          title: const Text(
            'لوحة تحكم المطعم',
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 22,
              fontFamily: 'Tajawal',
              letterSpacing: 1.1,
            ),
          ),
          iconTheme: const IconThemeData(color: primaryColor),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.support_agent, color: primaryColor),
              tooltip: 'الدعم',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(userId: widget.restaurantId),
                  ),
                );
              },
            ),
          ],
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
          ),
        ),
        drawer: Drawer(
          child: Container(
            color: Colors.white,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                  ),
                  child: DrawerHeader(
                    margin: EdgeInsets.zero,
                    padding: EdgeInsets.zero,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        logoUrl != null && logoUrl!.isNotEmpty
                            ? CircleAvatar(
                                radius: 44,
                                backgroundColor: Colors.white,
                                backgroundImage: NetworkImage(logoUrl!),
                              )
                            : CircleAvatar(
                                radius: 44,
                                backgroundColor: Colors.white,
                                child: Icon(Icons.restaurant, color: primaryColor, size: 48),
                              ),
                        const SizedBox(height: 12),
                        Text(
                          restaurantName != null && restaurantName!.isNotEmpty
                              ? restaurantName!
                              : 'اسم المطعم غير متوفر',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Tajawal',
                            fontSize: 20,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'معرف: ${widget.restaurantId}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontFamily: 'Tajawal',
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _drawerTile(
                  icon: Icons.add,
                  iconBg: Colors.orange.shade50,
                  text: ' إضافة عنصر جديد',
                  onTap: () {
                    Navigator.pop(context);
                    Get.to(() => StoreAddMenuItemScreen(restaurantId: widget.restaurantId));
                  },
                ),
                const SizedBox(height: 2),
                _drawerTile(
                  icon: Icons.menu_book,
                  iconBg: Colors.blue.shade50,
                  text: ' القائمة الكاملة',
                  onTap: () {
                    Navigator.pop(context);
                    Get.to(() => StoreFullMenuScreen(restaurantId: widget.restaurantId));
                  },
                ),
                const SizedBox(height: 2),
                _drawerTile(
                  icon: Icons.receipt_long,
                  iconBg: Colors.purple.shade50,
                  text: ' الطلبات الحالية',
                  onTap: () {
                    Navigator.pop(context);
                    Get.to(() => StoreCurrentOrdersScreen(restaurantId: widget.restaurantId));
                  },
                ),
                const SizedBox(height: 2),
                _drawerTile(
                  icon: Icons.access_time,
                  iconBg: Colors.green.shade50,
                  text: ' أوقات الدوام',
                  onTap: () {
                    Navigator.pop(context);
                    Get.to(() => StoreWorkingHoursScreen(restaurantId: widget.restaurantId));
                  },
                ),
                const SizedBox(height: 2),
                _drawerTile(
                  icon: Icons.account_balance_wallet,
                  iconBg: Colors.amber.shade50,
                  text: ' محفظتي',
                  onTap: () {
                    Navigator.pop(context);
                    Get.to(() => StoreWalletScreen(restaurantId: widget.restaurantId));
                  },
                ),
                const SizedBox(height: 2),
                Card(
                  elevation: 0,
                  color: Colors.red.shade50,
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: SwitchListTile(
                    title: const Text(' إيقاف مؤقت لاستقبال الطلبات', style: TextStyle(fontFamily: 'Tajawal')),
                    value: temporarilyClosed,
                    onChanged: _toggleTemporaryClosure,
                    secondary: const Icon(Icons.pause_circle_filled, color: Colors.red),
                    activeColor: primaryColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const Divider(indent: 18, endIndent: 18, height: 24),
                _drawerTile(
                  icon: Icons.settings,
                  iconBg: Colors.grey.shade200,
                  text: ' الإعدادات',
                  iconColor: Colors.grey,
                  onTap: () {
                    Navigator.pop(context);
                    Get.to(() => StoreSettingsScreen(restaurantId: widget.restaurantId));
                  },
                ),
                const SizedBox(height: 10),
                // زر تسجيل الخروج
                _drawerTile(
                  icon: Icons.logout,
                  iconBg: Colors.red.shade100,
                  text: 'تسجيل الخروج',
                  iconColor: Colors.red,
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await FirebaseAuth.instance.signOut();
                    await prefs.remove('userType');
                    Get.offAllNamed('/roleSelection');
                  },
                ),
              ],
            ),
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .where('restaurantId', isEqualTo: widget.restaurantId)
              .where('orderStatus', whereIn: _statusPriority)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: primaryColor));
            }
            var docs = snapshot.data?.docs ?? [];

            // رتب حسب أولوية الحالة ثم الإنشاء
            docs.sort((a, b) {
              final sa = _statusPriority.indexOf(a['orderStatus'] as String);
              final sb = _statusPriority.indexOf(b['orderStatus'] as String);
              if (sa != sb) return sa.compareTo(sb);
              final ta = (a['createdAt'] as Timestamp?);
              final tb = (b['createdAt'] as Timestamp?);
              if (ta != null && tb != null) return tb.compareTo(ta);
              return 0;
            });

            // منطق القبول التلقائي والتنبيه
            for (final doc in docs) {
              final data = doc.data() as Map<String, dynamic>;
              final docId = doc.id;
              final status = data['orderStatus'] as String;
              // إذا الطلب جديد ولم يتم التنبيه عليه
              if (status == 'قيد المراجعة' && !notifiedOrders.contains(docId)) {
                // تشغيل جرس تنبيه (audioplayers) بشكل متكرر وبصوت مرتفع
                _audioPlayer.setReleaseMode(ReleaseMode.loop);
                _audioPlayer.setVolume(1.0);
                _audioPlayer.play(
                  AssetSource('sounds/notification.mp3'),
                  volume: 1.0,
                );
                notifiedOrders.add(docId);

                // القبول التلقائي
                if (autoAcceptOrders && !temporarilyClosed) {
                  FirebaseFirestore.instance
                      .collection('orders')
                      .doc(docId)
                      .update({'orderStatus': 'قيد التجهيز'});
                }
              }
            }

            if (docs.isEmpty) {
              return const Center(
                child: Text('🕒 لا توجد طلبات حالياً', style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final docId = docs[index].id;
                final status = data['orderStatus'] as String;

                Widget orderDetails = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text('👤 العميل: ${data['clientName'] ?? 'غير متوفر'}', style: const TextStyle(fontFamily: 'Tajawal')),
                    Text('💰 الإجمالي: ${data['total'] ?? 0} ج.س', style: const TextStyle(fontFamily: 'Tajawal')),
                    if (data['items'] != null && data['items'] is List)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('تفاصيل الطلب:', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
                            ...List.generate((data['items'] as List).length, (i) {
                              final item = (data['items'] as List)[i];
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  children: [
                                    if (item['imageUrl'] != null && item['imageUrl'].toString().isNotEmpty)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Image.network(
                                          item['imageUrl'],
                                          width: 32,
                                          height: 32,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${item['name']} × ${item['quantity']}',
                                        style: const TextStyle(fontFamily: 'Tajawal'),
                                      ),
                                    ),
                                    Text('${item['price']} ج.س', style: const TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                  ],
                );

                if (status == 'قيد المراجعة') {
                  // الطلب الجديد: التفاصيل تظهر مباشرة
                  return Card(
                    elevation: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const SizedBox(width: 8),
                              Text(
                                '📦 رقم الطلب: ${data['orderNumber'] ?? data['orderId'] ?? docId}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal', fontSize: 16),
                              ),
                              const SizedBox(width: 10),
                              const Text('🆕 جديد',
                                  style: TextStyle(
                                      color: Colors.red, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
                            ],
                          ),
                          orderDetails,
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    await FirebaseFirestore.instance.collection('orders').doc(docId).update({
                                      'orderStatus': 'قيد التجهيز',
                                      'assignedDriverId': null,
                                      'candidateDrivers': [],
                                      'driverResponded': false,
                                      'driverResponseTime': null
                                    });
                                    _audioPlayer.stop();
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                  child: const Text('قبول الطلب', style: TextStyle(color: Colors.white)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    await FirebaseFirestore.instance.collection('orders').doc(docId).update({'orderStatus': 'ملغي'});
                                    _audioPlayer.stop();
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                  child: const Text('رفض الطلب', style: TextStyle(color: Colors.white)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                } else {
                  // الطلبات الأخرى: التفاصيل تظهر عند الضغط
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.white,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                          ),
                          builder: (_) => Padding(
                            padding: const EdgeInsets.all(18),
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (data['items'] != null && data['items'] is List)
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('تفاصيل الطلب:', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal', fontSize: 16)),
                                        const SizedBox(height: 8),
                                        ...List.generate((data['items'] as List).length, (i) {
                                          final item = (data['items'] as List)[i];
                                          return Card(
                                            margin: const EdgeInsets.symmetric(vertical: 4),
                                            elevation: 0,
                                            color: backgroundColor,
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                                              child: Row(
                                                children: [
                                                  if (item['imageUrl'] != null && item['imageUrl'].toString().isNotEmpty)
                                                    ClipRRect(
                                                      borderRadius: BorderRadius.circular(6),
                                                      child: Image.network(
                                                        item['imageUrl'],
                                                        width: 38,
                                                        height: 38,
                                                        fit: BoxFit.cover,
                                                      ),
                                                    ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      '${item['name']} × ${item['quantity']}',
                                                      style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w500, color: primaryColor),
                                                    ),
                                                  ),
                                                  Text('${item['price']} ج.س', style: const TextStyle(fontFamily: 'Tajawal', color: primaryColor)),
                                                ],
                                              ),
                                            ),
                                          );
                                        }),
                                      ],
                                    ),
                                  const Divider(height: 24),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('رقم الطلب:', style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey.shade700)),
                                      Text('${data['orderNumber'] ?? data['orderId'] ?? docId}', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('الحالة:', style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey.shade700)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: status == 'قيد التجهيز' ? Colors.orange.shade50 : status == 'قيد التوصيل' ? Colors.blue.shade50 : Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          status,
                                          style: TextStyle(
                                            color: status == 'قيد التجهيز' ? Colors.orange : status == 'قيد التوصيل' ? Colors.blueGrey : Colors.green,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Tajawal',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('الإجمالي:', style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey.shade700)),
                                      Text('${data['total'] ?? 0} ج.س', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  const Divider(height: 24),
                                  if (status == 'قيد التجهيز')
                                    _actionButton(' جاهز', () async {
                                      await FirebaseFirestore.instance.collection('orders').doc(docId).update({'orderStatus': 'قيد التوصيل'});
                                      setState(() {});
                                      Get.snackbar('تم', 'تم تحديث حالة الطلب إلى قيد التوصيل', snackPosition: SnackPosition.BOTTOM);
                                    }),
                                  if (status == 'قيد التوصيل')
                                    const Padding(
                                      padding: EdgeInsets.only(top: 10),
                                      child: Text('📦 الطلب في الطريق',
                                          style: TextStyle(color: Colors.blueGrey, fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              status == 'قيد التجهيز' ? Icons.kitchen : Icons.delivery_dining,
                              color: status == 'قيد التجهيز' ? Colors.orange : Colors.blueGrey,
                              size: 26,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '📦 رقم الطلب: ${data['orderId'] ?? docId}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal', fontSize: 16),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              status == 'قيد التجهيز' ? 'قيد التجهيز' : 'قيد التوصيل',
                              style: TextStyle(
                                color: status == 'قيد التجهيز' ? Colors.orange : Colors.blueGrey,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Tajawal',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
              },
            );
          },
        ),
      ),
    );
  }

  Widget _drawerTile({
    required IconData icon,
    required String text,
    Color? iconColor,
    Color? iconBg,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          splashColor: primaryColor.withOpacity(0.10),
          highlightColor: primaryColor.withOpacity(0.06),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: iconBg ?? primaryColor.withOpacity(0.09),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(7),
                  child: Icon(icon, color: iconColor ?? primaryColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionButton(String label, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            minimumSize: const Size.fromHeight(45),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(label, style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal')),
        ),
      ),
    );
  }
}