import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/cart_item.dart';
import 'app_config_service.dart';

/// Persistent multi-seller cart service.
/// Singleton with ChangeNotifier for reactive UI updates.
/// Data persisted to SharedPreferences under key 'gkk_cart'.
class CartService extends ChangeNotifier {
  static const _cartKey = 'gkk_cart';
  static const _maxQtyPerItem = 10;
  static final CartService _instance = CartService._internal();
  static CartService get instance => _instance;

  final _uuid = const Uuid();
  List<CartItem> _items = [];
  bool _initialized = false;

  CartService._internal();

  /// Must be called once at app startup (e.g. in main.dart or SplashScreen)
  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cartKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        final List<dynamic> itemsList = decoded['items'] ?? [];
        _items = itemsList
            .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('CartService: failed to parse saved cart: $e');
        _items = [];
      }
    }
    _initialized = true;
    notifyListeners();
  }

  /// All items in the cart
  List<CartItem> get items => List.unmodifiable(_items);

  /// Total number of items (sum of quantities)
  int get totalItems => _items.fold(0, (sum, i) => sum + i.quantity);

  /// Total price across all items
  double get totalPrice => _items.fold(0.0, (sum, i) => sum + i.lineTotal);

  /// Number of distinct kitchens in cart
  int get kitchenCount {
    final ids = _items.map((i) => i.cookId).toSet();
    return ids.length;
  }

  /// Group items by kitchen (cook_id)
  Map<String, KitchenCartGroup> get cartByKitchen {
    final groups = <String, KitchenCartGroup>{};
    for (final item in _items) {
      if (!groups.containsKey(item.cookId)) {
        groups[item.cookId] = KitchenCartGroup(
          cookId: item.cookId,
          kitchenName: item.kitchenName,
          items: [],
        );
      }
      groups[item.cookId]!.items.add(item);
    }
    return groups;
  }

  /// Get quantity of a specific dish from a specific kitchen
  int getQuantity(String dishId, String cookId) {
    final item = _items.cast<CartItem?>().firstWhere(
          (i) => i!.dishId == dishId && i.cookId == cookId,
          orElse: () => null,
        );
    return item?.quantity ?? 0;
  }

  /// Add an item to the cart.
  /// If same dish_id + cook_id exists → increment quantity (max 10).
  /// Returns the action taken: 'added', 'incremented', or 'different_kitchen'
  /// 'different_kitchen' means split kitchen is off and cart has items from another kitchen.
  String addItem({
    required String dishId,
    required String dishName,
    required double price,
    required String cookId,
    required String kitchenName,
    String? imageUrl,
  }) {
    // Enforce single-kitchen when split kitchen is disabled
    if (!AppConfigService.instance.isSplitKitchenEnabled && _items.isNotEmpty) {
      final existingCookId = _items.first.cookId;
      if (existingCookId != cookId) {
        return 'different_kitchen';
      }
    }

    final existingIdx = _items.indexWhere(
      (i) => i.dishId == dishId && i.cookId == cookId,
    );

    String action;
    if (existingIdx >= 0) {
      final existing = _items[existingIdx];
      final newQty = (existing.quantity + 1).clamp(1, _maxQtyPerItem);
      _items[existingIdx] = existing.copyWith(quantity: newQty);
      action = 'incremented';
    } else {
      _items.add(CartItem(
        id: _uuid.v4(),
        dishId: dishId,
        dishName: dishName,
        price: price,
        cookId: cookId,
        kitchenName: kitchenName,
        imageUrl: imageUrl,
        quantity: 1,
        addedAt: DateTime.now(),
      ));
      action = 'added';
    }

    _persist();
    notifyListeners();
    return action;
  }

  /// Remove an item by its cart ID
  void removeItem(String cartItemId) {
    _items.removeWhere((i) => i.id == cartItemId);
    _persist();
    notifyListeners();
  }

  /// Remove an item by dish_id + cook_id
  void removeByDish(String dishId, String cookId) {
    _items.removeWhere((i) => i.dishId == dishId && i.cookId == cookId);
    _persist();
    notifyListeners();
  }

  /// Update quantity of an item. If qty <= 0 → remove.
  void updateQuantity(String cartItemId, int newQty) {
    if (newQty <= 0) {
      removeItem(cartItemId);
      return;
    }
    final idx = _items.indexWhere((i) => i.id == cartItemId);
    if (idx >= 0) {
      _items[idx] = _items[idx].copyWith(quantity: newQty.clamp(1, _maxQtyPerItem));
      _persist();
      notifyListeners();
    }
  }

  /// Increment/decrement by dish_id + cook_id. Returns new quantity (0 = removed).
  int adjustQuantity(String dishId, String cookId, int delta) {
    final idx = _items.indexWhere(
      (i) => i.dishId == dishId && i.cookId == cookId,
    );
    if (idx < 0) return 0;

    final newQty = (_items[idx].quantity + delta).clamp(0, _maxQtyPerItem);
    if (newQty <= 0) {
      _items.removeAt(idx);
      _persist();
      notifyListeners();
      return 0;
    }

    _items[idx] = _items[idx].copyWith(quantity: newQty);
    _persist();
    notifyListeners();
    return newQty;
  }

  /// Clear the entire cart
  void clearCart() {
    _items.clear();
    _persist();
    notifyListeners();
  }

  /// Clear items for a specific kitchen only
  void clearKitchen(String cookId) {
    _items.removeWhere((i) => i.cookId == cookId);
    _persist();
    notifyListeners();
  }

  /// Persist to SharedPreferences
  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode({
        'items': _items.map((i) => i.toJson()).toList(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      await prefs.setString(_cartKey, data);
    } catch (e) {
      debugPrint('CartService: persist error: $e');
    }
  }
}
