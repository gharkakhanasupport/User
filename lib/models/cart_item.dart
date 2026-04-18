
/// Model representing a single item in the persistent cart.
class CartItem {
  final String id; // unique client-generated ID per cart entry
  final String dishId; // menu_item_id from DB
  final String dishName;
  final double price; // price at time of add
  final int quantity;
  final String cookId; // kitchen identifier
  final String kitchenName;
  final String? imageUrl;
  final DateTime addedAt;

  CartItem({
    required this.id,
    required this.dishId,
    required this.dishName,
    required this.price,
    required this.quantity,
    required this.cookId,
    required this.kitchenName,
    this.imageUrl,
    required this.addedAt,
  });

  CartItem copyWith({int? quantity}) {
    return CartItem(
      id: id,
      dishId: dishId,
      dishName: dishName,
      price: price,
      quantity: quantity ?? this.quantity,
      cookId: cookId,
      kitchenName: kitchenName,
      imageUrl: imageUrl,
      addedAt: addedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'dish_id': dishId,
        'dish_name': dishName,
        'price': price,
        'quantity': quantity,
        'cook_id': cookId,
        'kitchen_name': kitchenName,
        'image_url': imageUrl,
        'added_at': addedAt.toIso8601String(),
      };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        id: json['id'] ?? '',
        dishId: json['dish_id'] ?? '',
        dishName: json['dish_name'] ?? '',
        price: (json['price'] ?? 0).toDouble(),
        quantity: json['quantity'] ?? 1,
        cookId: json['cook_id'] ?? '',
        kitchenName: json['kitchen_name'] ?? '',
        imageUrl: json['image_url'],
        addedAt: DateTime.tryParse(json['added_at'] ?? '') ?? DateTime.now(),
      );

  /// Line total for this item
  double get lineTotal => price * quantity;

  /// Display price text
  String get priceText => '\u20B9${price.toStringAsFixed(0)}';
}

/// A group of cart items belonging to a single kitchen.
class KitchenCartGroup {
  final String cookId;
  final String kitchenName;
  final List<CartItem> items;

  KitchenCartGroup({
    required this.cookId,
    required this.kitchenName,
    required this.items,
  });

  double get subtotal => items.fold(0.0, (sum, i) => sum + i.lineTotal);
  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);
}
