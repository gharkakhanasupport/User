/// Model representing a Kitchen visible to users.
/// Maps to the `kitchens` table in User DB.
class Kitchen {
  final String id;
  final String cookId;
  final String kitchenName;
  final String? description;
  final String ownerName;
  final String? phone;
  final String? email;
  final String? location;
  final bool isVegetarian;
  final List<String> kitchenPhotos;
  final bool isAvailable;
  final double rating;
  final int totalOrders;
  final String? profileImageUrl;
  final DateTime createdAt;

  Kitchen({
    required this.id,
    required this.cookId,
    required this.kitchenName,
    this.description,
    required this.ownerName,
    this.phone,
    this.email,
    this.location,
    this.isVegetarian = false,
    this.kitchenPhotos = const [],
    this.isAvailable = true,
    this.rating = 0,
    this.totalOrders = 0,
    this.profileImageUrl,
    required this.createdAt,
  });

  factory Kitchen.fromMap(Map<String, dynamic> map) {
    List<String> photos = [];
    if (map['kitchen_photos'] is List) {
      photos = (map['kitchen_photos'] as List)
          .where((e) => e != null)
          .map((e) => e.toString())
          .toList();
    }

    double parsedRating = 0.0;
    if (map['rating'] != null) {
      parsedRating = double.tryParse(map['rating'].toString()) ?? 0.0;
    }

    int parsedTotalOrders = 0;
    if (map['total_orders'] != null) {
      parsedTotalOrders = int.tryParse(map['total_orders'].toString()) ?? 0;
    }

    return Kitchen(
      id: (map['id'] ?? '').toString(),
      cookId: (map['cook_id'] ?? map['id'] ?? '').toString(),
      kitchenName: map['kitchen_name'] ?? '',
      description: map['description'],
      ownerName: map['owner_name'] ?? '',
      phone: map['phone'],
      email: map['email'],
      location: map['location'],
      isVegetarian: map['is_vegetarian'] ?? false,
      kitchenPhotos: photos,
      isAvailable: map['is_available'] ?? true,
      rating: parsedRating,
      totalOrders: parsedTotalOrders,
      profileImageUrl: map['profile_image_url'] ??
          (photos.isNotEmpty ? photos.first : null),
      createdAt: DateTime.parse(
        map['created_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  /// Get display image (profile image or first kitchen photo)
  String? get displayImage => profileImageUrl ??
      (kitchenPhotos.isNotEmpty ? kitchenPhotos.first : null);

  /// Get rating display text
  String get ratingText => rating.toStringAsFixed(1);

  /// Get short description for cards
  String get subtitle => description ?? (isVegetarian ? 'Pure Veg' : 'Multi-Cuisine');
}
