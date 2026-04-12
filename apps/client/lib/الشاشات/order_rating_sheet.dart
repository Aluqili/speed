import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';

const _ratingFunctionsRegion = 'me-central1';

bool canSubmitOrderRating(Map<String, dynamic> orderData) {
  final status =
      ((orderData['orderStatus'] ?? orderData['status']) as String? ?? '')
          .trim()
          .toLowerCase();
  final alreadyRated = orderData['hasClientRating'] == true ||
      ((orderData['restaurantRating'] as num?)?.toDouble() ?? 0) > 0;
  return !alreadyRated && (status == 'delivered' || status == 'تم التوصيل');
}

Future<bool?> showOrderRatingSheet(
  BuildContext context, {
  required String orderId,
  required Map<String, dynamic> orderData,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _OrderRatingSheet(
      orderId: orderId,
      orderData: orderData,
    ),
  );
}

class _OrderRatingSheet extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> orderData;

  const _OrderRatingSheet({
    required this.orderId,
    required this.orderData,
  });

  @override
  State<_OrderRatingSheet> createState() => _OrderRatingSheetState();
}

class _OrderRatingSheetState extends State<_OrderRatingSheet> {
  final TextEditingController _restaurantCommentController =
      TextEditingController();
  final TextEditingController _courierCommentController =
      TextEditingController();
  final HttpsCallable _submitCallable =
      FirebaseFunctions.instanceFor(region: _ratingFunctionsRegion)
          .httpsCallable('submitOrderRatings');

  int _restaurantRating = 0;
  int _courierRating = 0;
  bool _isSubmitting = false;

  bool get _hasCourier {
    return (widget.orderData['assignedDriverId'] ?? '')
        .toString()
        .trim()
        .isNotEmpty;
  }

  String get _restaurantName {
    return (widget.orderData['restaurantName'] ?? 'المطعم').toString().trim();
  }

  String get _courierName {
    return (widget.orderData['driverName'] ?? 'المندوب').toString().trim();
  }

  @override
  void dispose() {
    _restaurantCommentController.dispose();
    _courierCommentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_restaurantRating < 1) {
      _showMessage('اختر تقييم المطعم أولاً.');
      return;
    }
    if (_hasCourier && _courierRating < 1) {
      _showMessage('اختر تقييم المندوب أولاً.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _submitCallable.call({
        'orderId': widget.orderId,
        'restaurantRating': _restaurantRating,
        'restaurantComment': _restaurantCommentController.text.trim(),
        if (_hasCourier) 'courierRating': _courierRating,
        if (_hasCourier)
          'courierComment': _courierCommentController.text.trim(),
      });

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال تقييمك بنجاح.')),
      );
    } on FirebaseFunctionsException catch (error) {
      _showMessage(error.message ?? 'تعذر إرسال التقييم حالياً.');
    } catch (_) {
      _showMessage('تعذر إرسال التقييم حالياً.');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Center(
                    child: Container(
                      width: 58,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'قيّم تجربتك',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppThemeArabic.clientTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'تقييمك يساعدنا على إظهار المطاعم والمندوبين الأفضل بشكل حقيقي.',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: AppThemeArabic.clientTextSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildRatingSection(
                    title: _restaurantName,
                    subtitle: 'تقييم المطعم سيظهر لبقية العملاء.',
                    value: _restaurantRating,
                    onChanged: (value) {
                      setState(() {
                        _restaurantRating = value;
                      });
                    },
                    controller: _restaurantCommentController,
                    hintText: 'اكتب ملاحظتك عن جودة الطلب أو سرعة التجهيز',
                    icon: Icons.storefront_rounded,
                  ),
                  if (_hasCourier) ...[
                    const SizedBox(height: 14),
                    _buildRatingSection(
                      title: _courierName,
                      subtitle: 'قيّم أسلوب التوصيل والتعامل والالتزام.',
                      value: _courierRating,
                      onChanged: (value) {
                        setState(() {
                          _courierRating = value;
                        });
                      },
                      controller: _courierCommentController,
                      hintText: 'اكتب ملاحظتك عن المندوب',
                      icon: Icons.delivery_dining_rounded,
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppThemeArabic.clientPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'إرسال التقييم',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
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

  Widget _buildRatingSection({
    required String title,
    required String subtitle,
    required int value,
    required ValueChanged<int> onChanged,
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
        border:
            Border.all(color: AppThemeArabic.clientPrimary.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppThemeArabic.clientTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: AppThemeArabic.clientTextSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppThemeArabic.clientPrimary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: AppThemeArabic.clientPrimary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: List.generate(5, (index) {
              final starValue = index + 1;
              final selected = starValue <= value;
              return InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => onChanged(starValue),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFFFEDD5) : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: selected
                          ? AppThemeArabic.clientAccent
                          : Colors.grey.withOpacity(0.22),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$starValue',
                        style: TextStyle(
                          color: selected
                              ? AppThemeArabic.clientTextPrimary
                              : AppThemeArabic.clientTextSecondary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        selected
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: AppThemeArabic.clientAccent,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            maxLines: 3,
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: const TextStyle(fontSize: 13),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.withOpacity(0.18)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.withOpacity(0.18)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: AppThemeArabic.clientPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
