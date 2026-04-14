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
      final callable = FirebaseFunctions.instanceFor(region: 'me-central1')
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

  String _formatCreatedAt(dynamic createdAt) {
    if (createdAt is Timestamp) {
      final dt = createdAt.toDate();
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppThemeArabic.storeBackground,
        appBar: AppBar(
          title: const Text('طلبات تعديل الإدارة'),
          centerTitle: true,
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
              return Center(
                child: Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_outlined,
                        size: 52,
                        color: AppThemeArabic.storePrimary,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'لا توجد طلبات تعديل معلقة',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(14),
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppThemeArabic.storePrimary, Color(0xFF14B8A6)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'مركز موافقات الإدارة',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'راجع الطلبات المعلقة بسرعة وقرّر الموافقة أو الرفض من نفس الشاشة.',
                        style: TextStyle(color: Colors.white70, fontFamily: 'Tajawal'),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          '${pendingDocs.length} طلبات معلقة',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            fontFamily: 'Tajawal',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ...pendingDocs.map((doc) {
                  final data = doc.data();
                  final requestId = doc.id;
                  final processing = _processingIds.contains(requestId);
                  final reason = (data['reason'] ?? '').toString();
                  final type = (data['type'] ?? '').toString();
                  final createdText = _formatCreatedAt(data['createdAt']);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.black12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: AppThemeArabic.storePrimary.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.assignment_turned_in_outlined,
                                color: AppThemeArabic.storePrimary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _typeLabel(type),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                  fontFamily: 'Tajawal',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _infoRow('السبب', reason.isEmpty ? '-' : reason),
                        const SizedBox(height: 8),
                        _infoRow('تاريخ الطلب', createdText),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: processing
                                    ? null
                                    : () => _respond(requestId, 'approved'),
                                icon: processing
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.check_circle_outline),
                                label: const Text('موافقة'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  minimumSize: const Size.fromHeight(48),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: processing
                                    ? null
                                    : () => _respond(requestId, 'rejected'),
                                icon: const Icon(Icons.cancel_outlined),
                                label: const Text('رفض'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  minimumSize: const Size.fromHeight(48),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppThemeArabic.storeSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontFamily: 'Tajawal',
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'Tajawal'),
            ),
          ),
        ],
      ),
    );
  }
}
