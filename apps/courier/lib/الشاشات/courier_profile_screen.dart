import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';

import 'courier_edit_profile_screen.dart'; // ✅ استدعاء شاشة تعديل الملف الشخصي

class CourierProfileScreen extends StatelessWidget {
  final String driverId;

  const CourierProfileScreen({Key? key, required this.driverId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeArabic.clientBackground,
      appBar: AppBar(
        title: const Text('الملف الشخصي', style: TextStyle(color: AppThemeArabic.clientPrimary, fontWeight: FontWeight.bold, fontSize: 20, fontFamily: 'Tajawal')),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 1,
        iconTheme: const IconThemeData(color: AppThemeArabic.clientPrimary),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('drivers').doc(driverId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: GFLoader(type: GFLoaderType.circle));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text('لا توجد بيانات متاحة.'),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: GFAvatar(
                  radius: 50,
                  backgroundImage: NetworkImage(
                    data['profileImage'] ?? 'https://via.placeholder.com/150',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  data['name'] ?? 'اسم غير متاح',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  data['phone'] ?? 'رقم غير متاح',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
              const Divider(height: 40),

              _buildProfileInfo(title: 'البريد الإلكتروني', value: data['email'] ?? 'غير متاح'),
              const SizedBox(height: 12),
              _buildProfileInfo(title: 'المدينة', value: data['region'] ?? 'غير متاحة'),
              const SizedBox(height: 12),
              _buildProfileInfo(title: 'رقم الهوية', value: data['idNumber'] ?? 'غير متاح'),

              const SizedBox(height: 24),

              // زر تعديل البيانات
              GFButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CourierEditProfileScreen(
                        driverId: driverId,
                        currentData: data,
                      ),
                    ),
                  );
                },
                text: 'تعديل البيانات',
                icon: const Icon(Icons.edit),
                color: AppThemeArabic.clientPrimary,
                fullWidthButton: true,
                size: GFSize.LARGE,
                shape: GFButtonShape.pills,
              ),

              const SizedBox(height: 16),

              // زر تسجيل الخروج
              GFButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (!context.mounted) return;
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                text: 'تسجيل الخروج',
                icon: const Icon(Icons.logout),
                color: GFColors.DANGER,
                fullWidthButton: true,
                size: GFSize.LARGE,
                shape: GFButtonShape.pills,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProfileInfo({required String title, required String value}) {
    return GFListTile(
      titleText: title,
      subTitleText: value,
      icon: const Icon(Icons.arrow_forward_ios, size: 16),
    );
  }
}
