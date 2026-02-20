import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ClientSettingsScreen extends StatefulWidget {
  const ClientSettingsScreen({Key? key}) : super(key: key);

  @override
  State<ClientSettingsScreen> createState() => _ClientSettingsScreenState();
}

class _ClientSettingsScreenState extends State<ClientSettingsScreen> {
  bool notificationsEnabled = true;
  String language = 'العربية';
  Map<String, dynamic>? userData;

  static const Color primaryColor = Color(0xFFFE724C);
  static const Color backgroundColor = Color(0xFFF5F5F5);

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _fetchUserData();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    language = prefs.getString('language') ?? 'العربية';
    notificationsEnabled = prefs.getBool('notifications') ?? true;
    _updateLocaleFromLanguage(language);
    setState(() {});
  }

  void _updateLocaleFromLanguage(String lang) {
    if (lang == 'English') {
      Get.updateLocale(const Locale('en'));
    } else {
      Get.updateLocale(const Locale('ar'));
    }
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('clients').doc(user.uid).get();
      userData = doc.data();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: Text('settings'.tr, style: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 20, fontFamily: 'Tajawal')),
          backgroundColor: Colors.white,
          centerTitle: true,
          iconTheme: const IconThemeData(color: primaryColor),
          elevation: 1,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Card(
            color: Colors.white,
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.language, color: primaryColor),
                      const SizedBox(width: 10),
                      Text('language'.tr, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
                      const Spacer(),
                      DropdownButton<String>(
                        value: language,
                        items: [
                          DropdownMenuItem(value: 'العربية', child: Text('arabic'.tr)),
                          DropdownMenuItem(value: 'English', child: Text('english'.tr)),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() { language = val; _updateLocaleFromLanguage(val); });
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  Row(
                    children: [
                      const Icon(Icons.notifications, color: primaryColor),
                      const SizedBox(width: 10),
                      Text('notifications'.tr, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
                      const Spacer(),
                      Switch(
                        value: notificationsEnabled,
                        activeColor: primaryColor,
                        onChanged: (val) => setState(() => notificationsEnabled = val),
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  if (userData != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.person, color: primaryColor),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('${'name'.tr}: ${userData!['name']?.toString().isNotEmpty == true ? userData!['name'] : 'غير متاح'}', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 15), overflow: TextOverflow.ellipsis),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          tooltip: 'تعديل الاسم',
                          onPressed: () async {
                            final newName = await showDialog<String>(
                              context: context,
                              builder: (context) {
                                final controller = TextEditingController(text: userData!['name'] ?? '');
                                return AlertDialog(
                                  title: const Text('تعديل الاسم'),
                                  content: SingleChildScrollView(
                                    child: TextField(controller: controller, decoration: const InputDecoration(labelText: 'الاسم الجديد')),
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
                                    ElevatedButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('حفظ')),
                                  ],
                                );
                              },
                            );
                            if (newName != null && newName.isNotEmpty) {
                              await FirebaseFirestore.instance.collection('clients').doc(FirebaseAuth.instance.currentUser!.uid).update({'name': newName});
                              setState(() => userData!['name'] = newName);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث الاسم')));
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.email, color: primaryColor),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('${'email'.tr}: ${userData!['email']?.toString().isNotEmpty == true ? userData!['email'] : 'غير متاح'}', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 15), overflow: TextOverflow.ellipsis),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          tooltip: 'تعديل البريد الإلكتروني',
                          onPressed: () async {
                            final newEmail = await showDialog<String>(
                              context: context,
                              builder: (context) {
                                final controller = TextEditingController(text: userData!['email'] ?? '');
                                return AlertDialog(
                                  title: const Text('تعديل البريد الإلكتروني'),
                                  content: SingleChildScrollView(
                                    child: TextField(controller: controller, decoration: const InputDecoration(labelText: 'البريد الجديد')),
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
                                    ElevatedButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('حفظ')),
                                  ],
                                );
                              },
                            );
                            if (newEmail != null && newEmail.isNotEmpty) {
                              await FirebaseFirestore.instance.collection('clients').doc(FirebaseAuth.instance.currentUser!.uid).update({'email': newEmail});
                              setState(() => userData!['email'] = newEmail);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث البريد الإلكتروني')));
                            }
                          },
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.phone, color: primaryColor),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('${'phone'.tr}: ${userData!['phone']?.toString().isNotEmpty == true ? userData!['phone'] : 'غير متاح'}', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 15), overflow: TextOverflow.ellipsis),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          tooltip: 'تعديل رقم الجوال',
                          onPressed: () async {
                            final newPhone = await showDialog<String>(
                              context: context,
                              builder: (context) {
                                final controller = TextEditingController(text: userData!['phone'] ?? '');
                                return AlertDialog(
                                  title: const Text('تعديل رقم الجوال'),
                                  content: SingleChildScrollView(
                                    child: TextField(controller: controller, decoration: const InputDecoration(labelText: 'رقم الجوال الجديد'), keyboardType: TextInputType.phone),
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
                                    ElevatedButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('حفظ')),
                                  ],
                                );
                              },
                            );
                            if (newPhone != null && newPhone.isNotEmpty) {
                              await FirebaseFirestore.instance.collection('clients').doc(FirebaseAuth.instance.currentUser!.uid).update({'phone': newPhone});
                              setState(() => userData!['phone'] = newPhone);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث رقم الجوال')));
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      label: Text('logout'.tr, style: const TextStyle(fontSize: 16, fontFamily: 'Tajawal')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        Get.offAllNamed('/login');
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

}
