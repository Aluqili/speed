import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'restaurant_detail_screen.dart';

class ClientFavoritesTab extends StatelessWidget {
  final String clientId;
  const ClientFavoritesTab({Key? key, required this.clientId})
      : super(key: key);

  Future<void> _removeFavorite(String docId) {
    return FirebaseFirestore.instance
        .collection('favorites')
        .doc(docId)
        .delete();
  }

  void _openFavorite(BuildContext context, Map<String, dynamic> data) {
    final restaurantId = (data['restaurantId'] ?? '').toString().trim();
    if (restaurantId.isEmpty) {
      return;
    }

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
    const Color textColor = Color(0xFF1A1D26);
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('المفضلة'),
        backgroundColor: Colors.white,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 20,
          fontFamily: 'Tajawal',
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        elevation: 1,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('favorites')
            .where('clientId', isEqualTo: clientId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('لا توجد عناصر مفضلة حتى الآن'));
          }
          final docs = [...snapshot.data!.docs]..sort((a, b) {
              final aSeconds = (((a.data()
                          as Map<String, dynamic>)['createdAt']) as Timestamp?)
                      ?.seconds ??
                  0;
              final bSeconds = (((b.data()
                          as Map<String, dynamic>)['createdAt']) as Timestamp?)
                      ?.seconds ??
                  0;
              return bSeconds.compareTo(aSeconds);
            });
          return ListView.builder(
            padding: const EdgeInsets.all(16),
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
                      ? (data['offers'] ?? '').toString()
                      : 'مطعم مفضل');
              final imageUrl = isMeal
                  ? (data['mealImage'] ?? data['restaurantImage'] ?? '')
                      .toString()
                  : (data['restaurantImage'] ?? '').toString();

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.06),
                      offset: const Offset(0, 2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 56,
                      height: 56,
                      color: Colors.grey.shade200,
                      child: imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.image_not_supported_outlined),
                            )
                          : Icon(
                              isMeal
                                  ? Icons.fastfood_rounded
                                  : Icons.storefront_rounded,
                              color: Colors.grey.shade600,
                            ),
                    ),
                  ),
                  title: Text(
                    title,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    subtitle,
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    onPressed: () => _removeFavorite(docs[index].id),
                    icon: const Icon(Icons.favorite_rounded,
                        color: Color(0xFFE11D48)),
                  ),
                  onTap: () => _openFavorite(context, data),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
