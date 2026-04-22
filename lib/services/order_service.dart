import 'dart:math';
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

    // Log COD / Razorpay transactions so they appear in wallet history
    if (paymentMethod == 'cod' || paymentMethod == 'razorpay') {
      try {
        // Ensure wallet row exists first
        var walletData = await _supabase
            .from('wallet')
            .select('id')
            .eq('user_id', customerId)
            .maybeSingle();

        if (walletData == null) {
          // Auto-create wallet if it doesn't exist
          final inserted = await _supabase.from('wallet').insert({
            'user_id': customerId,
            'balance': 0.0,
          }).select('id').single();
          walletData = inserted;
        }

        await _supabase.from('wallet_transactions').insert({
          'wallet_id': walletData['id'],
          'amount': totalAmount,
          'type': paymentMethod == 'cod' ? 'cod_payment' : 'online_payment',
          'status': 'completed',
          'related_order_id': result['id'],
          'description': paymentMethod == 'cod'
              ? 'Cash on Delivery - ₹${totalAmount.toStringAsFixed(0)}'
              : 'Online payment via Razorpay - ₹${totalAmount.toStringAsFixed(0)}',
        });
        debugPrint('OrderService: Logged $paymentMethod transaction');
      } catch (e) {
        debugPrint('OrderService: Transaction logging failed: $e');
      }
    }

    return result;
  }

  // ─────────────────────────────────────────────
  // STREAMS 
  // ─────────────────────────────────────────────

  /// Real-time stream of current user's orders.
  /// Overlays Kitchen DB status on each order for real-time tracking.
  Stream<List<Map<String, dynamic>>> getMyOrdersStream() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return const Stream.empty();

    // User DB stream — has the order list
    final userStream = _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('customer_id', userId)
        .order('created_at', ascending: false);

    // Kitchen DB stream — has the real-time status updates
    final kitchenStream = KitchenDbConfig.realtimeClient
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('customer_id', userId)
        .order('created_at', ascending: false);

    return CombineLatestStream.combine2<List<Map<String, dynamic>>, List<Map<String, dynamic>>, List<Map<String, dynamic>>>(
      userStream,
      kitchenStream,
      (userRows, kitchenRows) {
        // Build a lookup map from Kitchen DB rows by order id
        final kitchenMap = <String, Map<String, dynamic>>{};
        for (final kr in kitchenRows) {
          kitchenMap[kr['id'].toString()] = kr;
        }

        // Overlay Kitchen DB status onto each User DB order
        return userRows.map((row) {
          final merged = <String, dynamic>{...row, '_source': 'single'};
          final orderId = row['id'].toString();
          final kitchenRow = kitchenMap[orderId];
          if (kitchenRow != null) {
            merged['status'] = kitchenRow['status'] ?? row['status'];
            if (kitchenRow['delivery_partner_name'] != null) {
              merged['delivery_partner_name'] = kitchenRow['delivery_partner_name'];
            }
            if (kitchenRow['delivery_otp'] != null) {
              merged['delivery_otp'] = kitchenRow['delivery_otp'];
            }
          }
          return merged;
        }).toList();
      },
    ).distinct((a, b) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (a[i]['id'] != b[i]['id']) return false;
        if (a[i]['status'] != b[i]['status']) return false;
      }
      return true;
    });
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
    ).distinct((a, b) {
      if (a.length != b.length) return false;
      if (a.isEmpty) return true;
      return a.first['status'] == b.first['status']
          && a.first['delivery_partner_name'] == b.first['delivery_partner_name']
          && a.first['delivery_otp'] == b.first['delivery_otp'];
    });
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

  // ─────────────────────────────────────────────
  // DEV / BETA TOOL — wipe all my orders
  // ─────────────────────────────────────────────

  /// Delete every order belonging to the currently logged-in customer.
  /// Removes from User DB (orders) AND
  /// best-effort from Kitchen DB so the cook's list also clears.
  /// Returns total rows deleted from User DB.
  Future<int> clearAllMyOrders() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    int total = 0;



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

  // ─────────────────────────────────────────────
  // DELIVERY OTP
  // ─────────────────────────────────────────────

  /// Generate a random 4-digit delivery OTP and store it in both DBs.
  /// Returns the generated OTP string.
  Future<String> generateDeliveryOtp(String orderId) async {
    final otp = (1000 + Random().nextInt(9000)).toString(); // 1000–9999

    // Write OTP to Kitchen DB (source of truth for delivery)
    try {
      await KitchenDbConfig.client
          .from('orders')
          .update({'delivery_otp': otp})
          .eq('id', orderId);
      debugPrint('OrderService: OTP $otp written to Kitchen DB for order $orderId');
    } catch (e) {
      debugPrint('OrderService: Kitchen DB OTP write failed: $e');
    }

    // Also write to User DB for redundancy
    try {
      await _supabase
          .from('orders')
          .update({'delivery_otp': otp})
          .eq('id', orderId);
    } catch (e) {
      debugPrint('OrderService: User DB OTP write failed: $e');
    }

    return otp;
  }
}
