import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_new_address_screen.dart';
import 'address_details_screen.dart';

class AddressSelectionScreen extends StatelessWidget {
  final String userId;
  final String userType;
  final bool isSelecting;
  // دالة تُستدعى عند اختيار عنوان، تُستخدم إذا كنت تريد معالجة الاختيار خارج الشاشة
  final Function(Map<String, dynamic>)? onAddressSelected;

  const AddressSelectionScreen({
    Key? key,
    required this.userId,
    required this.userType,
    this.isSelecting = false,
    this.onAddressSelected, // تم إضافة المعامل الجديد
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFFFE724C);
    final collectionPath = userType + 's';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: const Text('العناوين', style: TextStyle(color: Colors.black87)),
          iconTheme: const IconThemeData(color: Colors.black87),
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection(collectionPath).doc(userId).snapshots(),
          builder: (context, snapshot) {
            final defaultAddressId = snapshot.hasData &&
                    snapshot.data!.data() != null &&
                    (snapshot.data!.data() as Map<String, dynamic>).containsKey('defaultAddressId')
                ? snapshot.data!.get('defaultAddressId')
                : null;

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(collectionPath)
                  .doc(userId)
                  .collection('addresses')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, addressSnapshot) {
                if (!addressSnapshot.hasData || addressSnapshot.data!.docs.isEmpty) {
                  return _buildEmptyState(context);
                }

                final addresses = addressSnapshot.data!.docs;

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: addresses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final addressDoc = addresses[index];
                    final address = addressDoc.data() as Map<String, dynamic>;
                    final addressId = addressDoc.id;
                    final isDefault = addressId == defaultAddressId;

                    return InkWell(
                      onTap: () async {
                        if (isSelecting) {
                          final selectedAddressData = {
                            'addressId': addressId,
                            'addressName': address['addressName'],
                            'latitude': address['latitude'],
                            'longitude': address['longitude'],
                          };
                          // تحديث العنوان الافتراضي في قاعدة البيانات عند الاختيار
                          await FirebaseFirestore.instance
                              .collection(userType + 's')
                              .doc(userId)
                              .update({'defaultAddressId': addressId});
                          if (onAddressSelected != null) {
                            onAddressSelected!(selectedAddressData);
                          }
                          Navigator.pop(context, selectedAddressData);
                        } else {
                          _showAddressOptions(context, addressId, address, isDefault);
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.06),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.location_on, color: Color(0xFFFE724C)),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  address['addressName'] ?? 'عنوان بدون اسم',
                                  textAlign: TextAlign.right, // محاذاة لليمين
                                ),
                              ),
                              if (isDefault) const Icon(Icons.star, color: Colors.amber, size: 20),
                            ],
                          ),
                          subtitle: Text(
                            'إحداثيات: (${address['latitude']?.toStringAsFixed(4) ?? 'N/A'}, ${address['longitude']?.toStringAsFixed(4) ?? 'N/A'})',
                            style: const TextStyle(fontSize: 12),
                            textAlign: TextAlign.right, // محاذاة لليمين
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: primaryColor,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddNewAddressScreen(
                  userId: userId,
                  userType: userType,
                ),
              ),
            );
          },
          child: const Icon(Icons.add_location_alt),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.location_off, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text('لا توجد عناوين محفوظة.', style: TextStyle(fontSize: 16, color: Colors.grey)),
        ],
      ),
    );
  }

  void _showAddressOptions(BuildContext context, String addressId, Map<String, dynamic> address, bool isDefault) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl, // تطبيق الاتجاه لأسفل ورقة الخيارات
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.visibility),
                title: const Text('عرض العنوان', textAlign: TextAlign.right), // محاذاة لليمين
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddressDetailsScreen(
                        addressName: address['addressName'],
                        latitude: address['latitude'],
                        longitude: address['longitude'],
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('حذف العنوان', textAlign: TextAlign.right), // محاذاة لليمين
                onTap: () async {
                  Navigator.pop(ctx);
                  await FirebaseFirestore.instance
                      .collection(userType + 's')
                      .doc(userId)
                      .collection('addresses')
                      .doc(addressId)
                      .delete();
                },
              ),
              if (!isDefault)
                ListTile(
                  leading: const Icon(Icons.star),
                  title: const Text('تعيين كعنوان افتراضي', textAlign: TextAlign.right), // محاذاة لليمين
                  onTap: () async {
                    Navigator.pop(ctx);
                    await FirebaseFirestore.instance
                        .collection(userType + 's')
                        .doc(userId)
                        .update({'defaultAddressId': addressId});
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}