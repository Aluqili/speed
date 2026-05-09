import 'package:flutter/material.dart';
import '../الثيم/client_theme.dart';
import '../مكونات/glass_card.dart';
import '../الخدمات/rewards_service.dart';

class ClientRewardsScreen extends StatelessWidget {
  const ClientRewardsScreen({super.key, required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: StreamBuilder<int>(
        stream: RewardsService.pointsStream(clientId),
        builder: (context, pointsSnap) {
          final points = pointsSnap.data ?? 0;
          final nextLevel = RewardsService.nextLevelPoints(points);
          final level = RewardsService.levelName(points);
          final progress = (points / nextLevel).clamp(0.0, 1.0);

          return CustomScrollView(
            slivers: [
              const SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                pinned: true,
                title: Text('نقاطي ومكافآتي'),
                actions: [SizedBox(width: 16)],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    children: [
                      // ── بطاقة رصيد النقاط ──
                      _PointsCard(
                        points: points,
                        level: level,
                        progress: progress,
                        nextLevel: nextLevel,
                      ),
                      const SizedBox(height: 16),

                      // ── زر الاستبدال ──
                      if (points >= RewardsService.minRedeemPoints)
                        _RedeemBanner(points: points),
                      if (points >= RewardsService.minRedeemPoints)
                        const SizedBox(height: 16),

                      // ── قائمة المكافآت ──
                      _RewardsGrid(),
                      const SizedBox(height: 24),

                      // ── سجل النقاط ──
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'سجل النقاط',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),

              // ── تاريخ النقاط ──
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: RewardsService.pointsHistoryStream(clientId),
                builder: (ctx, snap) {
                  final history = snap.data ?? [];
                  if (history.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 24),
                        child: Center(
                          child: Text(
                            'لا توجد معاملات نقاط بعد.\nأكمل طلبك الأول واكسب نقاطك!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                              fontSize: 14,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: _HistoryTile(data: history[i]),
                      ),
                      childCount: history.length,
                    ),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          );
        },
      ),
    );
  }
}

class _PointsCard extends StatelessWidget {
  const _PointsCard({
    required this.points,
    required this.level,
    required this.progress,
    required this.nextLevel,
  });

  final int points;
  final String level;
  final double progress;
  final int nextLevel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: ClientColors.warmGradient,
        boxShadow: ClientColors.glowShadow(opacity: 0.45, blur: 28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'رصيد النقاط',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.80),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$points',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'نقطة',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded,
                        color: ClientColors.accent, size: 16),
                    const SizedBox(width: 5),
                    Text(
                      level,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'التقدم نحو المستوى التالي',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$points / $nextLevel نقطة',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _RedeemBanner extends StatelessWidget {
  const _RedeemBanner({required this.points});
  final int points;

  @override
  Widget build(BuildContext context) {
    final discount = RewardsService.pointsToDiscount(points);
    return GlowGlassCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: ClientColors.primaryGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.redeem_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'لديك رصيد قابل للاستبدال!',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'يمكنك خصم ${discount.toStringAsFixed(0)} على طلبك القادم',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: ClientColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'استخدم',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardsGrid extends StatelessWidget {
  static const _rewards = [
    (icon: Icons.local_offer_rounded,  label: 'خصم 10%',      points: 200),
    (icon: Icons.delivery_dining,      label: 'توصيل مجاني',  points: 350),
    (icon: Icons.fastfood_rounded,     label: 'طبق مجاني',    points: 750),
    (icon: Icons.card_giftcard_rounded,label: 'كوبون 500',     points: 1000),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'العروض المتاحة',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.4,
          ),
          itemCount: _rewards.length,
          itemBuilder: (context, i) {
            final reward = _rewards[i];
            return GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(reward.icon,
                      color: ClientColors.primary, size: 28),
                  const Spacer(),
                  Text(
                    reward.label,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          color: ClientColors.accent, size: 14),
                      const SizedBox(width: 3),
                      Text(
                        '${reward.points} نقطة',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final pts = (data['points'] as num?)?.toInt() ?? 0;
    final isAdd = pts > 0;
    final note = data['note'] as String? ?? 'معاملة نقاط';
    final ts = data['createdAt'];
    String dateStr = '';
    if (ts is DateTime) {
      dateStr =
          '${ts.day}/${ts.month}/${ts.year}';
    }

    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (isAdd ? ClientColors.success : ClientColors.error)
                  .withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isAdd ? Icons.add_circle_rounded : Icons.remove_circle_rounded,
              color:
                  isAdd ? ClientColors.success : ClientColors.error,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (dateStr.isNotEmpty)
                  Text(
                    dateStr,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '${isAdd ? '+' : ''}$pts',
            style: TextStyle(
              color: isAdd ? ClientColors.success : ClientColors.error,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
