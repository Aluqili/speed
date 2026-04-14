import 'package:flutter/material.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';

class StoreReportsScreen extends StatelessWidget {
  final String restaurantId;
  const StoreReportsScreen({Key? key, required this.restaurantId})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeArabic.storeBackground,
      appBar: AppBar(
        title: const Text('التقارير والإحصائيات'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _heroCard(
            title: 'تقارير المتجر',
            subtitle:
                'سنضيف هنا لاحقًا المبيعات، أفضل الأصناف، ومقارنة الأداء حسب الأيام.',
            icon: Icons.insights_outlined,
          ),
          const SizedBox(height: 16),
          _sectionCard(
            title: 'المخطط القادم',
            child: const Column(
              children: [
                _RoadmapTile(
                  icon: Icons.payments_outlined,
                  title: 'تقارير الإيرادات',
                  subtitle: 'إجمالي المبيعات اليومية والأسبوعية والشهرية.',
                ),
                SizedBox(height: 10),
                _RoadmapTile(
                  icon: Icons.local_dining_outlined,
                  title: 'أفضل الأصناف',
                  subtitle: 'الأكثر طلبًا والأعلى عائدًا داخل المتجر.',
                ),
                SizedBox(height: 10),
                _RoadmapTile(
                  icon: Icons.schedule_outlined,
                  title: 'أوقات الذروة',
                  subtitle: 'تحليل الفترات الأكثر نشاطًا لاستقبال الطلبات.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroCard({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          Icon(icon, color: Colors.white, size: 34),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w800,
              fontFamily: 'Tajawal',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white70,
              fontFamily: 'Tajawal',
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              fontFamily: 'Tajawal',
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _RoadmapTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _RoadmapTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppThemeArabic.storeSurface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppThemeArabic.storePrimary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppThemeArabic.storePrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Tajawal',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppThemeArabic.storeTextSecondary,
                    fontFamily: 'Tajawal',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
