class MenuItem {
  final String id;
  final String name;
  final double price;
  final String? imageUrl;
  final String? description;
  final String? category;
  final bool isAvailable;
  final DateTime? createdAt;

  MenuItem({
    required this.id,
    required this.name,
    required this.price,
    this.imageUrl,
    this.description,
    this.category,
    this.isAvailable = true,
    this.createdAt,
  });
}
