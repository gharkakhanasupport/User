import 'package:flutter_test/flutter_test.dart';
import 'package:ghar_ka_khana/models/cart_item.dart';

void main() {
  group('CartItem Model', () {
    final sampleJson = {
      'id': 'cart-001',
      'dish_id': 'dish-123',
      'dish_name': 'Paneer Tikka',
      'price': 250.0,
      'quantity': 2,
      'cook_id': 'cook-456',
      'kitchen_name': 'Maa Ki Rasoi',
      'image_url': 'https://example.com/paneer.jpg',
      'added_at': '2026-04-29T10:00:00.000',
    };

    test('fromJson creates correct CartItem', () {
      final item = CartItem.fromJson(sampleJson);
      expect(item.id, 'cart-001');
      expect(item.dishId, 'dish-123');
      expect(item.dishName, 'Paneer Tikka');
      expect(item.price, 250.0);
      expect(item.quantity, 2);
      expect(item.cookId, 'cook-456');
      expect(item.kitchenName, 'Maa Ki Rasoi');
      expect(item.imageUrl, 'https://example.com/paneer.jpg');
    });

    test('toJson produces correct map', () {
      final item = CartItem.fromJson(sampleJson);
      final json = item.toJson();
      expect(json['dish_id'], 'dish-123');
      expect(json['dish_name'], 'Paneer Tikka');
      expect(json['price'], 250.0);
      expect(json['quantity'], 2);
      expect(json['cook_id'], 'cook-456');
      expect(json['kitchen_name'], 'Maa Ki Rasoi');
    });

    test('fromJson → toJson roundtrip preserves data', () {
      final item = CartItem.fromJson(sampleJson);
      final json = item.toJson();
      final restored = CartItem.fromJson(json);
      expect(restored.dishId, item.dishId);
      expect(restored.dishName, item.dishName);
      expect(restored.price, item.price);
      expect(restored.quantity, item.quantity);
      expect(restored.cookId, item.cookId);
    });

    test('lineTotal calculates correctly', () {
      final item = CartItem.fromJson(sampleJson);
      expect(item.lineTotal, 500.0); // 250 * 2
    });

    test('priceText formats correctly', () {
      final item = CartItem.fromJson(sampleJson);
      expect(item.priceText, '₹250');
    });

    test('copyWith only changes quantity', () {
      final item = CartItem.fromJson(sampleJson);
      final updated = item.copyWith(quantity: 5);
      expect(updated.quantity, 5);
      expect(updated.dishName, 'Paneer Tikka');
      expect(updated.price, 250.0);
      expect(updated.cookId, 'cook-456');
    });

    test('fromJson handles missing/null values gracefully', () {
      final minimal = <String, dynamic>{};
      final item = CartItem.fromJson(minimal);
      expect(item.id, '');
      expect(item.dishId, '');
      expect(item.dishName, '');
      expect(item.price, 0.0);
      expect(item.quantity, 1);
      expect(item.cookId, '');
      expect(item.kitchenName, '');
      expect(item.imageUrl, isNull);
    });

    test('fromJson handles integer price correctly', () {
      final json = {...sampleJson, 'price': 150};
      final item = CartItem.fromJson(json);
      expect(item.price, 150.0);
      // price should be parsed as double even from int input
      expect(item.price, isA<double>());
    });
  });

  group('KitchenCartGroup', () {
    test('subtotal sums all item lineTotals', () {
      final items = [
        CartItem.fromJson({
          'id': '1', 'dish_id': 'd1', 'dish_name': 'A',
          'price': 100.0, 'quantity': 2, 'cook_id': 'c1',
          'kitchen_name': 'K1', 'added_at': '2026-01-01T00:00:00',
        }),
        CartItem.fromJson({
          'id': '2', 'dish_id': 'd2', 'dish_name': 'B',
          'price': 50.0, 'quantity': 3, 'cook_id': 'c1',
          'kitchen_name': 'K1', 'added_at': '2026-01-01T00:00:00',
        }),
      ];

      final group = KitchenCartGroup(
        cookId: 'c1', kitchenName: 'K1', items: items,
      );

      expect(group.subtotal, 350.0); // (100*2) + (50*3)
      expect(group.itemCount, 5); // 2 + 3
    });

    test('empty group has zero subtotal and count', () {
      final group = KitchenCartGroup(
        cookId: 'c1', kitchenName: 'K1', items: [],
      );
      expect(group.subtotal, 0.0);
      expect(group.itemCount, 0);
    });
  });
}
