/// Model representing a menu item visible to users.
/// Maps to the `menu_items` table in User DB.
class UserMenuItem {
  final String id;
  final String cookId;
  final String name;
  final String? description;
  final double price;
  final int quantityAvailable;
  final String category;
  final String? imageUrl;
  final bool isAvailable;
  final DateTime createdAt;

  UserMenuItem({
    required this.id,
    required this.cookId,
    required this.name,
    this.description,
    required this.price,
    this.quantityAvailable = 0,
    required this.category,
    this.imageUrl,
    this.isAvailable = true,
    required this.createdAt,
  });

  factory UserMenuItem.fromMap(Map<String, dynamic> map) {
    return UserMenuItem(
      id: (map['id'] ?? '').toString(),
      cookId: map['cook_id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'],
      price: (map['price'] ?? 0).toDouble(),
      quantityAvailable: map['quantity_available'] ?? 0,
      category: map['category'] ?? '',
      imageUrl: map['image_url'],
      isAvailable: map['is_available'] ?? true,
      createdAt: DateTime.parse(
        map['created_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  /// Price display text
  String get priceText => '\u20B9${price.toStringAsFixed(0)}';
}
