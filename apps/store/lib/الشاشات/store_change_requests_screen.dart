import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';

class StoreChangeRequestsScreen extends StatefulWidget {
  const StoreChangeRequestsScreen({super.key, required this.restaurantId});

  final String restaurantId;

  @override
  State<StoreChangeRequestsScreen> createState() =>
      _StoreChangeRequestsScreenState();
}

class _StoreChangeRequestsScreenState extends State<StoreChangeRequestsScreen> {
  final Set<String> _processingIds = <String>{};

  String _typeLabel(String type) {
    switch (type) {
      case 'setAutoAcceptOrders':
        return 'تفعيل/إيقاف القبول التلقائي';
      case 'setTemporarilyClosed':
        return 'فتح/إغلاق مؤقت';
      case 'updateStoreFields':
        return 'تعديل بيانات المتجر';
      default:
        return type;
    }
  }

  Future<void> _respond(String requestId, String decision) async {
    if (_processingIds.contains(requestId)) return;
    setState(() => _processingIds.add(requestId));

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('respondStoreChangeRequest');
      await callable.call({
        'requestId': requestId,
        'decision': decision,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            decision == 'approved'
                ? 'تمت الموافقة على طلب التعديل'
                : 'تم رفض طلب التعديل',
          ),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تنفيذ الطلب: ${e.message ?? e.code}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(requestId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppThemeArabic.clientBackground,
        appBar: AppBar(
          title: const Text('طلبات تعديل الإدارة', style: TextStyle(color: AppThemeArabic.clientPrimary, fontWeight: FontWeight.bold, fontSize: 20, fontFamily: 'Tajawal')),
          backgroundColor: Colors.white,
          centerTitle: true,
          elevation: 1,
          iconTheme: const IconThemeData(color: AppThemeArabic.clientPrimary),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
          ),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('storeChangeRequests')
              .where('restaurantId', isEqualTo: widget.restaurantId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const Center(
                child: Text('تعذر تحميل طلبات التعديل'),
              );
            }

            final allDocs = snapshot.data?.docs ?? [];
            final pendingDocs = allDocs.where((d) {
              final data = d.data();
              return (data['status'] ?? '').toString() == 'pending';
            }).toList();

            if (pendingDocs.isEmpty) {
              return const Center(child: Text('لا توجد طلبات تعديل معلقة'));
            }

            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: pendingDocs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final doc = pendingDocs[index];
                final data = doc.data();
                final requestId = doc.id;
                final processing = _processingIds.contains(requestId);

                final reason = (data['reason'] ?? '').toString();
                final type = (data['type'] ?? '').toString();
                final createdAt = data['createdAt'];
                final createdText = createdAt is Timestamp
                    ? createdAt.toDate().toString()
                    : '-';

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _typeLabel(type),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('السبب: ${reason.isEmpty ? '-' : reason}'),
                        const SizedBox(height: 6),
                        Text('تاريخ الطلب: $createdText'),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: processing
                                    ? null
                                    : () => _respond(requestId, 'approved'),
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text('موافقة'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: processing
                                    ? null
                                    : () => _respond(requestId, 'rejected'),
                                icon: const Icon(Icons.cancel_outlined),
                                label: const Text('رفض'),
                              ),
                            ),
                          ],
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
    );
  }
}
