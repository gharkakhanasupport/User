import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rxdart/rxdart.dart';
import '../utils/supabase_config.dart';

/// Service for placing and tracking orders.
/// Supports two modes based on AppConfigService:
///   - Split Kitchen (ON):  uses split_orders + split_order_items + place_split_order RPC
///   - Single Kitchen (OFF): uses the simple orders table with direct insert
/// Order history ALWAYS merges both tables so past orders are never hidden.
class OrderService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ─────────────────────────────────────────────
  // SINGLE-KITCHEN ORDER (simple orders table)
  // ─────────────────────────────────────────────

  /// Place a single-kitchen order into the `orders` table.
  /// Handles wallet debit atomically via RPC if wallet payment.
  Future<Map<String, dynamic>> placeSingleOrder({
    required String cookId,
    required String customerName,
    required String customerPhone,
    required String deliveryAddress,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required String paymentMethod,
    double? pickupLat,
    double? pickupLng,
    double? deliveryLat,
    double? deliveryLng,
  }) async {
    final customerId = _supabase.auth.currentUser?.id;
    if (customerId == null) throw Exception('Not logged in');

    // If wallet payment, debit first via RPC
    if (paymentMethod == 'wallet') {
      try {
        await _supabase.rpc('debit_wallet', params: {
          'p_user_id': customerId,
          'p_amount': totalAmount,
          'p_description': 'Order payment',
        });
      } catch (e) {
        final msg = e.toString();
        if (msg.contains('INSUFFICIENT_FUNDS')) {
          throw Exception('INSUFFICIENT_FUNDS');
        } else if (msg.contains('WALLET_NOT_FOUND')) {
          throw Exception('WALLET_NOT_FOUND');
        }
        rethrow;
      }
    }

    final orderData = <String, dynamic>{
      'cook_id': cookId,
      'customer_id': customerId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'delivery_address': deliveryAddress,
      'items': items,
      'total_amount': totalAmount,
      'status': 'pending',
    };

    if (pickupLat != null) orderData['pickup_lat'] = pickupLat;
    if (pickupLng != null) orderData['pickup_lng'] = pickupLng;
    if (deliveryLat != null) orderData['delivery_lat'] = deliveryLat;
    if (deliveryLng != null) orderData['delivery_lng'] = deliveryLng;

    // Write to User DB (primary)
    final result = await _supabase
        .from('orders')
        .insert(orderData)
        .select()
        .single();

    // Sync to Kitchen DB so cook sees it
    try {
      await KitchenDbConfig.client.from('orders').upsert(result);
    } catch (e) {
      debugPrint('OrderService: Kitchen DB sync failed: $e');
    }

    return result;
  }

  // ─────────────────────────────────────────────
  // SPLIT-KITCHEN ORDER (existing RPC flow)
  // ─────────────────────────────────────────────

  /// Place a new order (legacy single insert — kept for backward compatibility).
  Future<Map<String, dynamic>> placeOrder({
    required String cookId,
    required String customerName,
    required String customerPhone,
    required String deliveryAddress,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    double? pickupLat,
    double? pickupLng,
    double? deliveryLat,
    double? deliveryLng,
  }) async {
    final customerId = _supabase.auth.currentUser?.id;

    final orderData = <String, dynamic>{
      'cook_id': cookId,
      'customer_id': customerId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'delivery_address': deliveryAddress,
      'items': items,
      'total_amount': totalAmount,
      'status': 'pending',
    };

    if (pickupLat != null) orderData['pickup_lat'] = pickupLat;
    if (pickupLng != null) orderData['pickup_lng'] = pickupLng;
    if (deliveryLat != null) orderData['delivery_lat'] = deliveryLat;
    if (deliveryLng != null) orderData['delivery_lng'] = deliveryLng;

    final result = await _supabase
        .from('orders')
        .insert(orderData)
        .select()
        .single();

    try {
      await KitchenDbConfig.client.from('orders').upsert(result);
    } catch (e) {
      debugPrint('OrderService: Kitchen DB sync failed: $e');
    }

    return result;
  }

  // ─────────────────────────────────────────────
  // STREAMS — ALWAYS merges both tables so ALL
  // past orders are visible regardless of toggle
  // ─────────────────────────────────────────────

  /// Real-time stream of current user's orders.
  /// Merges BOTH split_orders and orders tables so all past orders
  /// are always visible regardless of the current toggle state.
  Stream<List<Map<String, dynamic>>> getMyOrdersStream() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return const Stream.empty();

    // Stream from split_orders
    final splitStream = _supabase
        .from('split_orders')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map((row) => <String, dynamic>{
          ...row,
          'customer_id': row['user_id'],
          'total_amount': row['total'],
          '_source': 'split',
        }).toList());

    // Stream from simple orders
    final ordersStream = _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('customer_id', userId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map((row) => <String, dynamic>{
          ...row,
          '_source': 'single',
        }).toList());

    // Merge both streams, sort by created_at descending
    return CombineLatestStream.combine2<List<Map<String, dynamic>>, List<Map<String, dynamic>>, List<Map<String, dynamic>>>(
      splitStream,
      ordersStream,
      (splitRows, orderRows) {
        final all = <Map<String, dynamic>>[...splitRows, ...orderRows];
        all.sort((a, b) {
          final aTime = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(2000);
          final bTime = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(2000);
          return bTime.compareTo(aTime);
        });
        return all;
      },
    );
  }

  /// Get all orders for current user with items (one-time fetch).
  /// Merges both tables.
  Future<List<Map<String, dynamic>>> getMyOrders() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final allOrders = <Map<String, dynamic>>[];

      // Fetch from split_orders
      try {
        final raw = await _supabase
            .from('split_orders')
            .select('*, split_order_items(*)')
            .eq('user_id', userId)
            .order('created_at', ascending: false);

        for (final o in raw) {
          allOrders.add(<String, dynamic>{
            ...o,
            'customer_id': o['user_id'],
            'total_amount': o['total'],
            '_source': 'split',
            'items': (o['split_order_items'] as List?)?.map((i) => <String, dynamic>{
              ...i,
              'name': i['dish_name'],
              'price': i['price_at_order'],
            }).toList(),
          });
        }
      } catch (e) {
        debugPrint('OrderService: split_orders fetch error: $e');
      }

      // Fetch from simple orders
      try {
        final raw = await _supabase
            .from('orders')
            .select()
            .eq('customer_id', userId)
            .order('created_at', ascending: false);

        for (final o in raw) {
          allOrders.add(<String, dynamic>{
            ...o,
            '_source': 'single',
          });
        }
      } catch (e) {
        debugPrint('OrderService: orders fetch error: $e');
      }

      // Sort merged results
      allOrders.sort((a, b) {
        final aTime = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(2000);
        final bTime = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });
      return allOrders;
    } catch (e) {
      debugPrint('OrderService.getMyOrders error: $e');
      return [];
    }
  }

  /// Get a specific order by ID.
  Stream<List<Map<String, dynamic>>> getOrderStream(String orderId) {
    return getOrderTrackingStream(orderId);
  }

  /// Combination stream for order tracking.
  /// Tries both split_orders AND orders tables to find the order,
  /// then overlays Kitchen DB status for real-time tracking.
  Stream<List<Map<String, dynamic>>> getOrderTrackingStream(String orderId) {
    // Try split_orders
    final splitStream = _supabase
        .from('split_orders')
        .stream(primaryKey: ['id'])
        .eq('id', orderId);

    // Also try simple orders
    final ordersStream = _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('id', orderId);

    // Kitchen DB always has the real-time status
    final kitchenDbStream = KitchenDbConfig.client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('id', orderId);

    return CombineLatestStream.combine3<List<Map<String, dynamic>>, List<Map<String, dynamic>>, List<Map<String, dynamic>>, List<Map<String, dynamic>>>(
      splitStream,
      ordersStream,
      kitchenDbStream,
      (splitRows, orderRows, kitchenRows) {
        Map<String, dynamic>? baseRow;

        // Determine which table has this order
        if (splitRows.isNotEmpty) {
          baseRow = Map<String, dynamic>.from(splitRows.first);
          baseRow['customer_id'] = baseRow['user_id'];
          baseRow['total_amount'] = baseRow['total'];
          baseRow['_source'] = 'split';
        } else if (orderRows.isNotEmpty) {
          baseRow = Map<String, dynamic>.from(orderRows.first);
          baseRow['_source'] = 'single';
        }

        if (baseRow == null) return <Map<String, dynamic>>[];

        // Overlay kitchen DB real-time data
        if (kitchenRows.isNotEmpty) {
          final kitchenRow = kitchenRows.first;
          baseRow['status'] = kitchenRow['status'];
          if (kitchenRow['current_location'] != null) baseRow['current_location'] = kitchenRow['current_location'];
          if (kitchenRow['delivery_partner_name'] != null) baseRow['delivery_partner_name'] = kitchenRow['delivery_partner_name'];
          if (kitchenRow['delivery_otp'] != null) baseRow['delivery_otp'] = kitchenRow['delivery_otp'];
          if (kitchenRow['pickup_lat'] != null) baseRow['pickup_lat'] = kitchenRow['pickup_lat'];
          if (kitchenRow['pickup_lng'] != null) baseRow['pickup_lng'] = kitchenRow['pickup_lng'];
          if (kitchenRow['delivery_lat'] != null) baseRow['delivery_lat'] = kitchenRow['delivery_lat'];
          if (kitchenRow['delivery_lng'] != null) baseRow['delivery_lng'] = kitchenRow['delivery_lng'];
        }

        return [baseRow];
      },
    );
  }

  /// Fetch items for a specific order.
  /// Tries split_order_items first, then falls back to orders JSONB.
  Future<List<Map<String, dynamic>>> getOrderItems(String orderId) async {
    try {
      // Try split_order_items first
      try {
        final items = await _supabase
            .from('split_order_items')
            .select()
            .eq('order_id', orderId);

        if (items.isNotEmpty) {
          return items.map((i) => <String, dynamic>{
            ...i,
            'name': i['dish_name'],
            'price': i['price_at_order'],
          }).toList();
        }
      } catch (_) {}

      // Fall back to orders JSONB column
      final rows = await _supabase
          .from('orders')
          .select('items')
          .eq('id', orderId)
          .limit(1);

      if (rows.isNotEmpty && rows.first['items'] != null) {
        final itemsList = rows.first['items'] as List;
        return itemsList.map((i) => Map<String, dynamic>.from(i)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('OrderService.getOrderItems error: $e');
      return [];
    }
  }

  /// Get orders by status for current user (merges both tables).
  Future<List<Map<String, dynamic>>> getOrdersByStatus(String status) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final results = <Map<String, dynamic>>[];

    try {
      final split = await _supabase
          .from('split_orders')
          .select('*, split_order_items(*)')
          .eq('user_id', userId)
          .eq('status', status)
          .order('created_at', ascending: false);
      for (final o in split) {
        results.add(<String, dynamic>{...o, '_source': 'split'});
      }
    } catch (_) {}

    try {
      final simple = await _supabase
          .from('orders')
          .select()
          .eq('customer_id', userId)
          .eq('status', status)
          .order('created_at', ascending: false);
      for (final o in simple) {
        results.add(<String, dynamic>{...o, '_source': 'single'});
      }
    } catch (_) {}

    results.sort((a, b) {
      final aTime = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(2000);
      final bTime = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(2000);
      return bTime.compareTo(aTime);
    });
    return results;
  }

  /// Get active orders (merges both tables).
  Future<List<Map<String, dynamic>>> getActiveOrders() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final activeStatuses = ['pending', 'confirmed', 'preparing', 'out_for_delivery'];
    final results = <Map<String, dynamic>>[];

    try {
      final split = await _supabase
          .from('split_orders')
          .select()
          .eq('user_id', userId)
          .inFilter('status', activeStatuses)
          .order('created_at', ascending: false);
      for (final o in split) {
        results.add(<String, dynamic>{...o, '_source': 'split'});
      }
    } catch (_) {}

    try {
      final simple = await _supabase
          .from('orders')
          .select()
          .eq('customer_id', userId)
          .inFilter('status', activeStatuses)
          .order('created_at', ascending: false);
      for (final o in simple) {
        results.add(<String, dynamic>{...o, '_source': 'single'});
      }
    } catch (_) {}

    results.sort((a, b) {
      final aTime = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(2000);
      final bTime = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(2000);
      return bTime.compareTo(aTime);
    });
    return results;
  }

  /// Returns true if the current user has any active (undelivered) order.
  Future<bool> hasActiveOrder() async {
    final orders = await getActiveOrders();
    return orders.isNotEmpty;
  }

  /// Real-time stream of the most recent active order with items.
  /// Used by the persistent active-order banner.
  Stream<Map<String, dynamic>?> getActiveOrderDetailsStream() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return Stream.value(null);

    final activeStatuses = ['pending', 'confirmed', 'preparing', 'ready', 'out_for_delivery'];

    // Stream simple orders with active status
    final ordersStream = _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('customer_id', userId)
        .order('created_at', ascending: false)
        .map((rows) {
      final active = rows.where((r) => activeStatuses.contains(r['status'])).toList();
      if (active.isEmpty) return null;
      final row = Map<String, dynamic>.from(active.first);
      row['_source'] = 'single';
      return row;
    });

    return ordersStream;
  }

  // ─────────────────────────────────────────────
  // DEV / BETA TOOL — wipe all my orders
  // ─────────────────────────────────────────────

  /// Delete every order belonging to the currently logged-in customer.
  /// Removes from User DB (orders + split_orders + split_order_items) AND
  /// best-effort from Kitchen DB so the cook's list also clears.
  /// Returns total rows deleted from User DB.
  Future<int> clearAllMyOrders() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    int total = 0;

    // split_order_items first (FK child)
    try {
      final splitOrderIds = await _supabase
          .from('split_orders')
          .select('id')
          .eq('user_id', userId);
      for (final row in splitOrderIds) {
        await _supabase.from('split_order_items').delete().eq('order_id', row['id']);
      }
    } catch (e) {
      debugPrint('clearAllMyOrders: split_order_items: $e');
    }

    try {
      final del = await _supabase
          .from('split_orders')
          .delete()
          .eq('user_id', userId)
          .select('id');
      total += (del as List).length;
    } catch (e) {
      debugPrint('clearAllMyOrders: split_orders: $e');
    }

    try {
      final del = await _supabase
          .from('orders')
          .delete()
          .eq('customer_id', userId)
          .select('id');
      final ids = (del as List).map((e) => e['id']).toList();
      total += ids.length;

      // Best-effort mirror delete in Kitchen DB
      if (ids.isNotEmpty) {
        try {
          await KitchenDbConfig.client.from('orders').delete().inFilter('id', ids);
        } catch (e) {
          debugPrint('clearAllMyOrders: Kitchen DB mirror delete failed: $e');
        }
      }
    } catch (e) {
      debugPrint('clearAllMyOrders: orders: $e');
    }

    return total;
  }
}
