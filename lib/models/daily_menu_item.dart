/// Model representing a daily menu item visible to users.
/// Maps to the `daily_menus` table in User DB.
class UserDailyMenuItem {
  final String id;
  final String cookId;
  final String date;
  final String name;
  final String? description;
  final String? imageUrl;
  final String category; // special, breakfast, lunch, dinner, snacks
  final double price;
  final int quantity;
  final bool isAvailable;

  UserDailyMenuItem({
    required this.id,
    required this.cookId,
    required this.date,
    required this.name,
    this.description,
    this.imageUrl,
    required this.category,
    required this.price,
    this.quantity = 0,
    this.isAvailable = true,
  });

  factory UserDailyMenuItem.fromMap(Map<String, dynamic> map) {
    return UserDailyMenuItem(
      id: (map['id'] ?? '').toString(),
      cookId: map['cook_id'] ?? '',
      date: map['date'] ?? '',
      name: map['name'] ?? '',
      description: map['description'],
      imageUrl: map['image_url'],
      category: map['category'] ?? 'lunch',
      price: (map['price'] ?? 0).toDouble(),
      quantity: map['quantity'] ?? 0,
      isAvailable: map['is_available'] ?? true,
    );
  }

  /// Price display text
  String get priceText => '\u20B9${price.toStringAsFixed(0)}';

  /// Category display name
  String get categoryName {
    switch (category) {
      case 'special':
        return "Today's Specials";
      case 'breakfast':
        return 'Breakfast';
      case 'lunch':
        return 'Lunch';
      case 'dinner':
        return 'Dinner';
      case 'snacks':
        return 'Snacks';
      default:
        return category;
    }
  }
}
