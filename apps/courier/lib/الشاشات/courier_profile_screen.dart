import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'courier_edit_profile_screen.dart';
import 'courier_ui.dart';

class CourierProfileScreen extends StatelessWidget {
  final String driverId;

  const CourierProfileScreen({super.key, required this.driverId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildCourierAppBar('الملف الشخصي'),
      body: CourierPageBackground(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('drivers')
              .doc(driverId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const CourierEmptyState(
                title: 'لا توجد بيانات متاحة',
                message: 'سيظهر الملف الشخصي هنا بعد اكتمال بيانات المندوب.',
                icon: Icons.person_off_outlined,
              );
            }

            final data = snapshot.data!.data() as Map<String, dynamic>;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                CourierHeroCard(
                  title: (data['name'] ?? 'اسم غير متاح').toString(),
                  subtitle: (data['phone'] ?? 'رقم غير متاح').toString(),
                  icon: Icons.account_circle_rounded,
                  trailing: CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white.withValues(alpha: 0.20),
                    backgroundImage: (data['profileImage'] ?? '')
                            .toString()
                            .trim()
                            .isNotEmpty
                        ? NetworkImage(data['profileImage'])
                        : null,
                    child: (data['profileImage'] ?? '')
                            .toString()
                            .trim()
                            .isEmpty
                        ? const Icon(Icons.person_rounded, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                CourierSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CourierSectionTitle(
                        title: 'بيانات المندوب',
                        subtitle: 'مراجعة بيانات الحساب والهوية والمنطقة.',
                      ),
                      const SizedBox(height: 16),
                      _ProfileRow(
                        title: 'البريد الإلكتروني',
                        value: (data['email'] ?? 'غير متاح').toString(),
                      ),
                      const SizedBox(height: 10),
                      _ProfileRow(
                        title: 'المدينة',
                        value: (data['region'] ?? 'غير متاحة').toString(),
                      ),
                      const SizedBox(height: 10),
                      _ProfileRow(
                        title: 'رقم الهوية',
                        value: (data['idNumber'] ?? 'غير متاح').toString(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
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
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('تعديل البيانات'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    if (!context.mounted) return;
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('تسجيل الخروج'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F1E7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF7A6857),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
