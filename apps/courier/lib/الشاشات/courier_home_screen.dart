import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:location/location.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'courier_active_orders_screen.dart';
import 'courier_order_history_screen.dart';
import 'courier_notifications_screen.dart';
import 'courier_profile_screen.dart';
import 'courier_new_orders_screen.dart'; // ✅ إضافة شاشة الطلبات الجديدة

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

class CourierHomeScreen extends StatefulWidget {
  final String driverId;

  const CourierHomeScreen({Key? key, required this.driverId}) : super(key: key);

  @override
  State<CourierHomeScreen> createState() => _CourierHomeScreenState();
}

class _CourierHomeScreenState extends State<CourierHomeScreen> {
  bool isAvailable = false;
  bool _loadingAvailability = true;
  final Location location = Location();

  @override
  void initState() {
    super.initState();
    _initAvailability();
    _initLocationTracking();
    _initFCM();
  }

  // جلب حالة التوفر من Firestore
  void _initAvailability() {
    FirebaseFirestore.instance
        .collection('drivers')
        .doc(widget.driverId)
        .get()
        .then((doc) {
      if (doc.exists) {
        setState(() {
          isAvailable = (doc.data()?['available'] as bool?) ?? false;
          _loadingAvailability = false;
        });
      } else {
        FirebaseFirestore.instance
            .collection('drivers')
            .doc(widget.driverId)
            .set({'available': false});
        setState(() {
          isAvailable = false;
          _loadingAvailability = false;
        });
      }
    });
  }

  // تتبع الموقع
  void _initLocationTracking() async {
    location.onLocationChanged.listen((loc) {
      FirebaseFirestore.instance
          .collection('drivers')
          .doc(widget.driverId)
          .update({
        'location': GeoPoint(loc.latitude!, loc.longitude!),
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      });
    });
  }

  // إعداد FCM
  void _initFCM() {
    FirebaseMessaging.instance.requestPermission();
    FirebaseMessaging.onMessage.listen(_showLocalNotification);
  }

  // تفعيل الموقع
  Future<bool> _ensureLocationEnabled() async {
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) return false;
    }
    var permission = await location.hasPermission();
    if (permission == PermissionStatus.denied) {
      permission = await location.requestPermission();
      if (permission != PermissionStatus.granted) return false;
    }
    return true;
  }

  // تبديل التوفر
  Future<void> _toggleAvailability(bool value) async {
    if (value) {
      bool ok = await _ensureLocationEnabled();
      if (!ok) {
        setState(() => isAvailable = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرجاء تفعيل خدمة الموقع أولاً')),
        );
        return;
      }
    }
    setState(() => isAvailable = value);
    await FirebaseFirestore.instance
        .collection('drivers')
        .doc(widget.driverId)
        .update({'available': value});
  }

  // عرض إشعار محلي
  void _showLocalNotification(RemoteMessage msg) async {
    const androidDetails = AndroidNotificationDetails(
      'driver_channel',
      'Driver Notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification'),
    );
    const platformDetails = NotificationDetails(android: androidDetails);
    await flutterLocalNotificationsPlugin.show(
      0,
      msg.notification?.title ?? '',
      msg.notification?.body ?? '',
      platformDetails,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الرئيسية - المندوب')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _loadingAvailability
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'مرحبًا بك أيها المندوب!',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text('معرفك هو: ${widget.driverId}', style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 16),

                  SwitchListTile(
                    title: const Text('التوفر للطلبات'),
                    subtitle: Text(isAvailable ? 'متاح' : 'غير متاح'),
                    value: isAvailable,
                    onChanged: _toggleAvailability,
                  ),
                  const SizedBox(height: 24),

                  _buildDriverOption(
                    icon: Icons.new_releases,
                    title: 'الطلبات الجديدة',
                    subtitle: 'عرض الطلبات الجديدة المتاحة',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CourierNewOrdersScreen(driverId: widget.driverId),
                      ),
                    ),
                  ),
                  _buildDriverOption(
                    icon: Icons.delivery_dining,
                    title: 'الطلبات الجارية',
                    subtitle: 'عرض الطلبات التي تقوم بتسليمها',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CourierActiveOrdersScreen(driverId: widget.driverId),
                      ),
                    ),
                  ),
                  _buildDriverOption(
                    icon: Icons.history,
                    title: 'سجل الطلبات',
                    subtitle: 'عرض سجل الطلبات التي تم تسليمها',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CourierOrderHistoryScreen(driverId: widget.driverId),
                      ),
                    ),
                  ),
                  _buildDriverOption(
                    icon: Icons.notifications,
                    title: 'الإشعارات',
                    subtitle: 'عرض الإشعارات والتحديثات الجديدة',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CourierNotificationsScreen(driverId: widget.driverId),
                      ),
                    ),
                  ),
                  _buildDriverOption(
                    icon: Icons.person,
                    title: 'الملف الشخصي',
                    subtitle: 'عرض وتعديل بياناتك الشخصية',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CourierProfileScreen(driverId: widget.driverId),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildDriverOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) =>
      Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: ListTile(
          leading: Icon(icon, size: 28),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: onTap,
        ),
      );
}
