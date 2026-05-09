import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../الثيم/client_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'restaurant_detail_screen.dart';

class ClientFavoritesTab extends StatelessWidget {
  final String clientId;
  const ClientFavoritesTab({super.key, required this.clientId});

  Future<void> _removeFavorite(BuildContext context, String docId) async {
    await FirebaseFirestore.instance
        .collection('favorites')
        .doc(docId)
        .delete();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت الإزالة من المفضلة')),
      );
    }
  }

  void _openFavorite(BuildContext context, Map<String, dynamic> data) {
    final restaurantId = (data['restaurantId'] ?? '').toString().trim();
    if (restaurantId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RestaurantDetailScreen(
          restaurantId: restaurantId,
          name: (data['restaurantName'] ?? 'مطعم').toString(),
          image: (data['restaurantImage'] ?? '').toString(),
          offers: (data['offers'] ?? '').toString(),
          clientId: clientId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('المفضلة'),
          centerTitle: true,
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('favorites')
              .where('clientId', isEqualTo: clientId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  color: ClientColors.primary,
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _EmptyFavorites();
            }

            final docs = [...snapshot.data!.docs]..sort((a, b) {
                final aT = ((a.data() as Map)['createdAt'] as Timestamp?)
                        ?.seconds ??
                    0;
                final bT = ((b.data() as Map)['createdAt'] as Timestamp?)
                        ?.seconds ??
                    0;
                return bT.compareTo(aT);
              });

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final type = (data['type'] ?? 'restaurant').toString();
                final isMeal = type == 'meal';

                final title = isMeal
                    ? (data['mealName'] ?? 'صنف غير معروف').toString()
                    : (data['restaurantName'] ?? 'مطعم غير معروف').toString();

                final subtitle = isMeal
                    ? (data['restaurantName'] ?? 'مطعم').toString()
                    : ((data['offers'] ?? '').toString().trim().isNotEmpty
                        ? data['offers'].toString()
                        : 'اضغط للتصفح');

                final imageUrl = isMeal
                    ? (data['mealImage'] ?? data['restaurantImage'] ?? '')
                        .toString()
                    : (data['restaurantImage'] ?? '').toString();

                return _FavoriteCard(
                  title: title,
                  subtitle: subtitle,
                  imageUrl: imageUrl,
                  isMeal: isMeal,
                  onTap: () => _openFavorite(context, data),
                  onRemove: () => _removeFavorite(context, docs[index].id),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ─── بطاقة المفضل ──────────────────────────────────────────────────────────

class _FavoriteCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imageUrl;
  final bool isMeal;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _FavoriteCard({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.isMeal,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? ClientColors.surface : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final subtitleColor = isDark ? ClientColors.textSecondary : const Color(0xFF6B6B6B);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // ─── زر الحذف ─────────────────────────────────
                IconButton(
                  onPressed: onRemove,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  icon: const Icon(
                    Icons.favorite_rounded,
                    color: ClientColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 4),
                // ─── المعلومات ────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // شارة النوع
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isMeal
                                  ? ClientColors.accent
                                      .withValues(alpha: 0.15)
                                  : ClientColors.primary
                                      .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isMeal
                                      ? Icons.fastfood_rounded
                                      : Icons.storefront_rounded,
                                  size: 11,
                                  color: isMeal
                                      ? ClientColors.accent
                                      : ClientColors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isMeal ? 'وجبة' : 'مطعم',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isMeal
                                        ? ClientColors.accent
                                        : ClientColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        title,
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        textAlign: TextAlign.right,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: subtitleColor,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // ─── الصورة ───────────────────────────────────
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 72,
                    height: 72,
                    color: Theme.of(context).cardColor,
                    child: imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _PlaceholderIcon(
                              isMeal: isMeal,
                            ),
                          )
                        : _PlaceholderIcon(isMeal: isMeal),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaceholderIcon extends StatelessWidget {
  final bool isMeal;
  const _PlaceholderIcon({required this.isMeal});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ClientColors.primary.withValues(alpha: 0.07),
      child: Icon(
        isMeal ? Icons.fastfood_rounded : Icons.storefront_rounded,
        color: ClientColors.primary.withValues(alpha: 0.4),
        size: 28,
      ),
    );
  }
}

// ─── حالة المفضلة الفارغة ───────────────────────────────────────────────────

class _EmptyFavorites extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: ClientColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite_border_rounded,
                size: 48,
                color: ClientColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'قائمة مفضلتك فارغة',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'تصفح المطاعم واضغط ❤️ لحفظ ما يعجبك',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
