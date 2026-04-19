import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/supabase_config.dart';

/// Service for placing and tracking orders.
/// Writes to both User DB and Kitchen DB (dual-write from user side).
/// Reads/streams from User DB.
class OrderService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Place a new order.
  /// Writes to User DB first, then syncs to Kitchen DB.
  /// Optional coordinates enable live delivery radar tracking.
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

    // Add coordinates only if provided (graceful degradation if columns absent)
    if (pickupLat != null) orderData['pickup_lat'] = pickupLat;
    if (pickupLng != null) orderData['pickup_lng'] = pickupLng;
    if (deliveryLat != null) orderData['delivery_lat'] = deliveryLat;
    if (deliveryLng != null) orderData['delivery_lng'] = deliveryLng;

    // Write to User DB (primary for user)
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

  /// Real-time stream of current user's orders (from split_orders).
  Stream<List<Map<String, dynamic>>> getMyOrdersStream() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return const Stream.empty();

    // Note: This stream only returns split_orders metadata.
    // UI will need to handle the absence of 'items' by showing kitchen name or similar summary.
    return _supabase
        .from('split_orders')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map((row) => {
          ...row,
          'customer_id': row['user_id'], // Map for legacy support
          'total_amount': row['total'],   // Map for legacy support
        }).toList());
  }

  /// Get all orders for current user with their items (one-time fetch).
  Future<List<Map<String, dynamic>>> getMyOrders() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final orders = await _supabase
          .from('split_orders')
          .select('*, split_order_items(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      
      return orders.map((o) => {
        ...o,
        'customer_id': o['user_id'],
        'total_amount': o['total'],
        'items': (o['split_order_items'] as List?)?.map((i) => {
          ...i,
          'name': i['dish_name'],           // Map to legacy 'name'
          'price': i['price_at_order'],     // Map to legacy 'price'
        }).toList(),
      }).toList();
    } catch (e) {
      debugPrint('OrderService.getMyOrders error: $e');
      return [];
    }
  }

  /// Get a specific order by ID with its items.
  Stream<List<Map<String, dynamic>>> getOrderStream(String orderId) {
    // Since stream() doesn't support joins well, we'll fetch metadata and items separately or use a combine helper.
    // For now, we return order metadata and let the UI fetch items if missing.
    return _supabase
        .from('split_orders')
        .stream(primaryKey: ['id'])
        .eq('id', orderId)
        .map((rows) => rows.map((row) => {
          ...row,
          'customer_id': row['user_id'],
          'total_amount': row['total'],
        }).toList());
  }

  /// Fetch items for a specific split_order.
  Future<List<Map<String, dynamic>>> getOrderItems(String orderId) async {
    try {
      final items = await _supabase
          .from('split_order_items')
          .select()
          .eq('order_id', orderId);
      
      return items.map((i) => {
        ...i,
        'name': i['dish_name'],
        'price': i['price_at_order'],
      }).toList();
    } catch (e) {
      debugPrint('OrderService.getOrderItems error: $e');
      return [];
    }
  }

  /// Get orders by status for current user.
  Future<List<Map<String, dynamic>>> getOrdersByStatus(String status) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    return await _supabase
        .from('split_orders')
        .select('*, split_order_items(*)')
        .eq('user_id', userId)
        .eq('status', status)
        .order('created_at', ascending: false);
  }

  /// Get active orders (pending, confirmed, preparing, out_for_delivery).
  Future<List<Map<String, dynamic>>> getActiveOrders() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    return await _supabase
        .from('split_orders')
        .select()
        .eq('user_id', userId)
        .inFilter('status', ['pending', 'confirmed', 'preparing', 'out_for_delivery'])
        .order('created_at', ascending: false);
  }
}
