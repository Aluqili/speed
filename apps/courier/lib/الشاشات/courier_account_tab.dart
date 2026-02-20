import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CourierAccountTab extends StatefulWidget {
  final String driverId;

  const CourierAccountTab({Key? key, required this.driverId}) : super(key: key);

  @override
  State<CourierAccountTab> createState() => _CourierAccountTabState();
}

class _CourierAccountTabState extends State<CourierAccountTab> {
  Map<String, dynamic>? driverData;
  int completedOrders = 0;
  double totalEarnings = 0;

  @override
  void initState() {
    super.initState();
    _fetchDriverData();
    _fetchCompletedOrders();
  }

  Future<void> _fetchDriverData() async {
    final doc = await FirebaseFirestore.instance.collection('drivers').doc(widget.driverId).get();
    if (doc.exists) {
      setState(() {
        driverData = doc.data();
      });
    }
  }

  Future<void> _fetchCompletedOrders() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('orders')
        .where('assignedDriverId', isEqualTo: widget.driverId)
        .where('status', isEqualTo: 'تم التوصيل')
        .get();

    double total = 0;
    for (var doc in snapshot.docs) {
      total += (doc.data()['deliveryFee'] ?? 0).toDouble();
    }

    setState(() {
      completedOrders = snapshot.docs.length;
      totalEarnings = total;
    });
  }

  void _editField(String fieldName, String currentValue) async {
    final controller = TextEditingController(text: currentValue);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('تعديل $fieldName'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: 'ادخل $fieldName الجديد'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('حفظ')),
        ],
      ),
    );

    if (result != null && result != currentValue) {
      await FirebaseFirestore.instance.collection('drivers').doc(widget.driverId).update({fieldName: result});
      _fetchDriverData();
    }
  }

  void _changePassword() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تغيير كلمة المرور'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'كلمة المرور الجديدة'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('تغيير')),
        ],
      ),
    );

    if (result != null && result.length >= 6) {
      try {
        await FirebaseAuth.instance.currentUser?.updatePassword(result);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم تغيير كلمة المرور')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    } else if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ كلمة المرور قصيرة جدًا')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (driverData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final name = driverData!['name'] ?? 'غير معروف';
    final phone = driverData!['phone'] ?? 'غير متاح';

    return Scaffold(
      appBar: AppBar(title: const Text('حسابي')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GFCard(
              padding: const EdgeInsets.all(16),
              elevation: 4,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('👤 معلومات الحساب', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(height: 20),
                  Row(
                    children: [
                      const Text('الاسم: ', style: TextStyle(fontSize: 16)),
                      Expanded(child: Text(name, style: const TextStyle(fontSize: 16))),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.grey),
                        onPressed: () => _editField('name', name),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('رقم الهاتف: ', style: TextStyle(fontSize: 16)),
                      Expanded(child: Text(phone, style: const TextStyle(fontSize: 16))),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.grey),
                        onPressed: () => _editField('phone', phone),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('📄 معرف المندوب: ${widget.driverId}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            GFCard(
              padding: const EdgeInsets.all(16),
              elevation: 4,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📊 إحصائيات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('الطلبات المكتملة:', style: TextStyle(fontSize: 16)),
                      Text('$completedOrders', style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('إجمالي الأرباح:', style: TextStyle(fontSize: 16)),
                      Text('$totalEarnings ج.س', style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            GFButton(
              onPressed: _changePassword,
              text: 'تغيير كلمة المرور',
              icon: const Icon(Icons.lock),
              fullWidthButton: true,
              color: GFColors.DANGER,
              shape: GFButtonShape.pills,
            ),
          ],
        ),
      ),
    );
  }
}
