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
  Future<Map<String, dynamic>> placeOrder({
    required String cookId,
    required String customerName,
    required String customerPhone,
    required String deliveryAddress,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
  }) async {
    final customerId = _supabase.auth.currentUser?.id;

    final orderData = {
      'cook_id': cookId,
      'customer_id': customerId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'delivery_address': deliveryAddress,
      'items': items,
      'total_amount': totalAmount,
      'status': 'pending',
    };

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

  /// Real-time stream of current user's orders.
  Stream<List<Map<String, dynamic>>> getMyOrdersStream() {
    final customerId = _supabase.auth.currentUser?.id;
    if (customerId == null) return const Stream.empty();

    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('customer_id', customerId)
        .order('created_at', ascending: false);
  }

  /// Get all orders for current user (one-time fetch).
  Future<List<Map<String, dynamic>>> getMyOrders() async {
    final customerId = _supabase.auth.currentUser?.id;
    if (customerId == null) return [];

    return await _supabase
        .from('orders')
        .select()
        .eq('customer_id', customerId)
        .order('created_at', ascending: false);
  }

  /// Get a specific order by ID with real-time updates.
  Stream<List<Map<String, dynamic>>> getOrderStream(String orderId) {
    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('id', orderId);
  }

  /// Get orders by status for current user.
  Future<List<Map<String, dynamic>>> getOrdersByStatus(String status) async {
    final customerId = _supabase.auth.currentUser?.id;
    if (customerId == null) return [];

    return await _supabase
        .from('orders')
        .select()
        .eq('customer_id', customerId)
        .eq('status', status)
        .order('created_at', ascending: false);
  }

  /// Get active orders (pending, accepted, preparing, ready).
  Future<List<Map<String, dynamic>>> getActiveOrders() async {
    final customerId = _supabase.auth.currentUser?.id;
    if (customerId == null) return [];

    return await _supabase
        .from('orders')
        .select()
        .eq('customer_id', customerId)
        .inFilter('status', ['pending', 'accepted', 'preparing', 'ready'])
        .order('created_at', ascending: false);
  }
}
