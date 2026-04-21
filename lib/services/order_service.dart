import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rxdart/rxdart.dart';
import '../utils/supabase_config.dart';

/// Service for placing and tracking orders.
/// Single Kitchen: uses the simple orders table with direct insert
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
  // STREAMS 
  // ─────────────────────────────────────────────

  /// Real-time stream of current user's orders.
  Stream<List<Map<String, dynamic>>> getMyOrdersStream() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return const Stream.empty();

    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('customer_id', userId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map((row) => <String, dynamic>{
          ...row,
          '_source': 'single',
        }).toList());
  }

  /// Get all orders for current user with items (one-time fetch).
  Future<List<Map<String, dynamic>>> getMyOrders() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final raw = await _supabase
          .from('orders')
          .select()
          .eq('customer_id', userId)
          .order('created_at', ascending: false);

      return raw.map((o) => <String, dynamic>{
        ...o,
        '_source': 'single',
      }).toList();
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
  /// Uses orders table to find the order,
  /// then overlays Kitchen DB status for real-time tracking.
  Stream<List<Map<String, dynamic>>> getOrderTrackingStream(String orderId) {
    // Try simple orders
    final ordersStream = _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('id', orderId);

    // Kitchen DB always has the real-time status
    final kitchenDbStream = KitchenDbConfig.realtimeClient
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('id', orderId);

    return CombineLatestStream.combine2<List<Map<String, dynamic>>, List<Map<String, dynamic>>, List<Map<String, dynamic>>>(
      ordersStream,
      kitchenDbStream,
      (orderRows, kitchenRows) {
        if (orderRows.isEmpty) return <Map<String, dynamic>>[];
        
        Map<String, dynamic> baseRow = Map<String, dynamic>.from(orderRows.first);
        baseRow['_source'] = 'single';

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
  Future<List<Map<String, dynamic>>> getOrderItems(String orderId) async {
    try {
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

  /// Get orders by status for current user.
  Future<List<Map<String, dynamic>>> getOrdersByStatus(String status) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final simple = await _supabase
          .from('orders')
          .select()
          .eq('customer_id', userId)
          .eq('status', status)
          .order('created_at', ascending: false);
      return simple.map((o) => <String, dynamic>{...o, '_source': 'single'}).toList();
    } catch (_) {
      return [];
    }
  }

  /// Get active orders.
  Future<List<Map<String, dynamic>>> getActiveOrders() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final activeStatuses = ['pending', 'confirmed', 'preparing', 'out_for_delivery'];
    try {
      final simple = await _supabase
          .from('orders')
          .select()
          .eq('customer_id', userId)
          .inFilter('status', activeStatuses)
          .order('created_at', ascending: false);
      return simple.map((o) => <String, dynamic>{...o, '_source': 'single'}).toList();
    } catch (_) {
      return [];
    }
  }

  /// Returns true if the current user has any active (undelivered) order.
  Future<bool> hasActiveOrder() async {
    final orders = await getActiveOrders();
    return orders.isNotEmpty;
  }

  /// Real-time stream of the most recent active order with items.
  /// Used by the persistent active-order banner. Automatically reflects Kitchen DB updates.
  Stream<Map<String, dynamic>?> getActiveOrderDetailsStream() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return Stream.value(null);

    final activeStatuses = ['pending', 'confirmed', 'preparing', 'ready', 'out_for_delivery'];

    final userOrdersStream = _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('customer_id', userId);

    final kitchenOrdersStream = KitchenDbConfig.realtimeClient
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('customer_id', userId);

    return CombineLatestStream.combine2<List<Map<String, dynamic>>, List<Map<String, dynamic>>, Map<String, dynamic>?>(
      userOrdersStream,
      kitchenOrdersStream,
      (userRows, kitchenRows) {
        final now = DateTime.now();
        final active = userRows.where((r) {
          if (!activeStatuses.contains(r['status'])) return false;
          final created = DateTime.tryParse(r['created_at'].toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
          if (now.difference(created).inHours > 12) return false; // Ignore stale pseudo-active orders older than 12h
          return true;
        }).toList();
        
        if (active.isEmpty) return null;

        active.sort((a, b) {
          final aTime = DateTime.tryParse(a['created_at'].toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = DateTime.tryParse(b['created_at'].toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });

        final baseRow = Map<String, dynamic>.from(active.first);
        baseRow['_source'] = 'single';
        final orderId = baseRow['id'].toString();

        try {
          final kRow = kitchenRows.firstWhere((r) => r['id'].toString() == orderId);
          baseRow['status'] = kRow['status'];
          if (kRow['current_location'] != null) baseRow['current_location'] = kRow['current_location'];
          if (kRow['delivery_partner_name'] != null) baseRow['delivery_partner_name'] = kRow['delivery_partner_name'];
          if (kRow['delivery_otp'] != null) baseRow['delivery_otp'] = kRow['delivery_otp'];
        } catch (_) {
          // Fallback to user row if not found in kitchen db
        }
        
        if (!activeStatuses.contains(baseRow['status'])) {
          return null;
        }
        
        return baseRow;
      },
    );
  }
}
