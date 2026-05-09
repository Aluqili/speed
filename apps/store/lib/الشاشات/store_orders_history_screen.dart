import 'package:flutter/material.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';

class StoreOrdersHistoryScreen extends StatelessWidget {
  final String restaurantId;
  const StoreOrdersHistoryScreen({Key? key, required this.restaurantId})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('سجل الطلبات'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppThemeArabic.storePrimary, Color(0xFF0EA5A4)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(26),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.history_rounded, color: Colors.white, size: 34),
                SizedBox(height: 16),
                Text(
                  'سجل الطلبات',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Tajawal',
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'سيظهر هنا لاحقًا أرشيف الطلبات السابقة مع إمكانات التصفية والبحث.',
                  style: TextStyle(color: Colors.white70, fontFamily: 'Tajawal'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardTheme.color ?? AppThemeArabic.storeSurface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'المزايا القادمة',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Tajawal',
                  ),
                ),
                SizedBox(height: 14),
                _HistoryPoint('البحث برقم الطلب أو اسم العميل.'),
                SizedBox(height: 10),
                _HistoryPoint('تصفية حسب الحالة والفترة الزمنية.'),
                SizedBox(height: 10),
                _HistoryPoint('إجماليات سريعة للطلبات المكتملة والملغاة.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryPoint extends StatelessWidget {
  final String text;

  const _HistoryPoint(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: AppThemeArabic.storeAccent,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontFamily: 'Tajawal'),
          ),
        ),
      ],
    );
  }
}
