import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';

/// Service for placing and tracking orders.
/// Single Source of Truth: The app strictly interacts with the User DB.
/// Cross-DB synchronization (to Kitchen/Delivery) is handled server-side via Edge Functions.
class OrderService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ─────────────────────────────────────────────
  // SINGLE-KITCHEN ORDER (simple orders table)
  // ─────────────────────────────────────────────

  /// Place a draft single-kitchen order into the `orders` table.
  /// Status is initially set to 'payment_pending'.
  Future<Map<String, dynamic>> createDraftOrder({
    required String cookId,
    required String customerName,
    required String customerPhone,
    required String deliveryAddress,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    String? kitchenName,
    double? pickupLat,
    double? pickupLng,
    double? deliveryLat,
    double? deliveryLng,
  }) async {
    final customerId = _supabase.auth.currentUser?.id;
    if (customerId == null) throw Exception('Not logged in');

    final orderData = <String, dynamic>{
      'cook_id': cookId,
      'kitchen_name': kitchenName,
      'customer_id': customerId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'delivery_address': deliveryAddress,
      'items': items,
      'total_amount': totalAmount,
      'payment_method': 'pending', // Will be updated upon confirmation
      'user_email': _supabase.auth.currentUser?.email,
      'status': 'payment_pending',
    };

    if (pickupLat != null) orderData['pickup_lat'] = pickupLat;
    if (pickupLng != null) orderData['pickup_lng'] = pickupLng;
    if (deliveryLat != null) orderData['delivery_lat'] = deliveryLat;
    if (deliveryLng != null) orderData['delivery_lng'] = deliveryLng;

    try {
      final result = await _supabase
          .from('orders')
          .insert(orderData)
          .select()
          .single();
      debugPrint('OrderService: Draft order created (payment_pending).');
      return result;
    } on PostgrestException catch (e) {
      debugPrint('OrderService: PostgrestException on draft order insert: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('OrderService: Unexpected error on draft order insert: $e');
      throw Exception('DRAFT_ORDER_INSERT_FAILED: $e');
    }
  }

  /// Confirm a draft order after payment is successful.
  Future<void> confirmOrder({
    required String orderId,
    required String paymentMethod,
    required double totalAmount,
  }) async {
    final customerId = _supabase.auth.currentUser?.id;
    if (customerId == null) throw Exception('Not logged in');

    if (paymentMethod == 'wallet') {
      try {
        await _supabase.rpc('debit_wallet', params: {
          'p_user_id': customerId,
          'p_amount': totalAmount,
          'p_description': 'Order payment',
        });
      } catch (e) {
        debugPrint('OrderService: debit_wallet RPC failed: $e');
        final msg = e.toString();
        if (msg.contains('INSUFFICIENT_FUNDS')) {
          throw Exception('INSUFFICIENT_FUNDS');
        } else if (msg.contains('WALLET_NOT_FOUND')) {
          throw Exception('WALLET_NOT_FOUND');
        }
        throw Exception('WALLET_DEBIT_FAILED: $e');
      }
    }

    try {
      await _supabase.from('orders').update({
        'status': OrderStatus.pending, // which means 'placed'
        'payment_method': paymentMethod,
      }).eq('id', orderId);
      debugPrint('OrderService: Order $orderId confirmed.');
    } catch (e) {
      debugPrint('OrderService: Failed to update order status: $e');
      throw Exception('ORDER_UPDATE_FAILED: $e');
    }

    // Log payment into the unified payments table
    try {
      await _supabase.from('payments').insert({
        'user_id': customerId,
        'order_id': orderId,
        'amount': totalAmount,
        'currency': 'INR',
        'payment_method': paymentMethod,
        'payment_type': 'debit',
        'status': paymentMethod == 'cod' ? 'pending' : 'completed',
      });
    } catch (e) {
      debugPrint('OrderService: Payments table logging failed: $e');
    }
  }

  /// Cancel a draft order if the user backs out of payment.
  Future<void> cancelDraftOrder(String orderId) async {
    try {
      await _supabase.from('orders').update({
        'status': 'cancelled_draft',
      }).eq('id', orderId);
      debugPrint('OrderService: Draft order $orderId cancelled.');
    } catch (e) {
      debugPrint('OrderService: Failed to cancel draft order: $e');
    }
  }

  // ─────────────────────────────────────────────
  // STREAMS 
  // ─────────────────────────────────────────────

  /// Real-time stream of current user's orders.
  /// Relies on server-side sync to update 'status' from Kitchen/Delivery DBs.
  Stream<List<Map<String, dynamic>>> getMyOrdersStream() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return const Stream.empty();

    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('customer_id', userId)
        .order('created_at', ascending: false)
        .map((rows) => rows
            .where((row) => row['status'] != 'payment_pending' && row['status'] != 'cancelled_draft')
            .map((row) {
              final merged = <String, dynamic>{...row, '_source': 'single'};
              merged['status'] = _normalizeStatusCode(row['status']);
              return merged;
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
          .neq('status', 'payment_pending')
          .neq('status', 'cancelled_draft')
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
    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('id', orderId)
        .map((rows) => rows.map((row) {
          final merged = Map<String, dynamic>.from(row);
          merged['_source'] = 'single';
          merged['status'] = _normalizeStatusCode(row['status']);
          return merged;
        }).toList());
  }

  /// Combination stream for order tracking.
  /// Now simplified to a single stream because all data (partner info, status, OTP) 
  /// is synced into the User DB via Edge Functions.
  Stream<List<Map<String, dynamic>>> getOrderTrackingStream(String orderId) {
    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('id', orderId)
        .map((rows) {
          if (rows.isEmpty) return <Map<String, dynamic>>[];
          
          final row = rows.first;
          final merged = Map<String, dynamic>.from(row);
          merged['_source'] = 'single';
          merged['status'] = _normalizeStatusCode(row['status']);
          
          return [merged];
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

    final activeStatuses = [
      'pending', 'order_placed', 'order placed',
      'accepted', 'order_accepted', 'order accepted', 'confirmed', 'order_confirmed', 'order confirmed',
      'preparing', 'preparing_food', 'preparing food', 'cooking',
      'ready', 'ready_for_pickup', 'ready for pickup', 'ready_for_delivery', 'ready for delivery',
      'out_for_delivery', 'out for delivery', 'out_of_delivery', 'out of delivery', 'dispatched', 'shipped'
    ];
    
    try {
      final response = await _supabase
          .from('orders')
          .select('*')
          .eq('customer_id', userId)
          .inFilter('status', activeStatuses)
          .order('created_at', ascending: false);
      return (response as List).map((o) => <String, dynamic>{...o, '_source': 'single'}).toList();
    } catch (_) {
      return [];
    }
  }

  /// Returns true if the current user has any active (undelivered) order.
  Future<bool> hasActiveOrder() async {
    final orders = await getActiveOrders();
    return orders.isNotEmpty;
  }

  /// Real-time stream of all active orders.
  /// Simplified to a single User DB stream.
  Stream<List<Map<String, dynamic>>> getActiveOrderDetailsStream() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return Stream.value([]);

    bool isStatusActive(String? status) {
      if (status == null) return false;
      final s = _normalizeStatusCode(status);
      final active = {
        'pending', 'order_placed', 
        'accepted', 'confirmed', 'order_accepted', 'order_confirmed', 'confirment',
        'preparing', 'preparing_food', 'cooking',
        'ready', 'ready_for_pickup', 'ready_for_delivery',
        'out_for_delivery', 'out_of_delivery', 'on_the_way'
      };
      return active.contains(s);
    }

    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('customer_id', userId)
        .map((rows) {
          return rows.where((r) => isStatusActive(r['status']?.toString())).map((row) {
            final merged = Map<String, dynamic>.from(row);
            merged['status'] = _normalizeStatusCode(row['status']);
            return merged;
          }).toList();
        });
  }

  // ─────────────────────────────────────────────
  // DEV / BETA TOOL — wipe all my orders
  // ─────────────────────────────────────────────

  /// Delete every order belonging to the currently logged-in customer.
  /// Sync to Kitchen DB is now handled by server-side webhooks.
  Future<int> clearAllMyOrders() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    try {
      final del = await _supabase
          .from('orders')
          .delete()
          .eq('customer_id', userId)
          .select('id');
      return (del as List).length;
    } catch (e) {
      debugPrint('clearAllMyOrders error: $e');
      return 0;
    }
  }

  // ─────────────────────────────────────────────
  // DELIVERY OTP
  // ─────────────────────────────────────────────

  /// Generate a random 4-digit delivery OTP and store it in the User DB.
  /// Synchronization to Kitchen and Delivery DBs is handled by server-side webhooks.
  Future<String> generateDeliveryOtp(String orderId) async {
    final otp = (1000 + Random().nextInt(9000)).toString();

    try {
      await _supabase
          .from('orders')
          .update({'delivery_otp': otp})
          .eq('id', orderId);
      debugPrint('OrderService: OTP $otp generated and saved (Server will sync).');
    } catch (e) {
      debugPrint('OrderService: OTP generation failed: $e');
    }

    return otp;
  }

  /// Initiate a refund for an eligible order (cancelled/rejected/failed).
  /// Credits the amount to the user's GKK Wallet.
  Future<bool> initiateRefund(Map<String, dynamic> order) async {
    final orderId = order['id'];
    final amount = (order['total_amount'] ?? 0).toDouble();
    final status = order['status']?.toString().toLowerCase();

    // Basic client-side check
    if (status != 'cancelled' && status != 'rejected' && status != 'failed' && status != 'declined') {
      debugPrint('OrderService: Order $orderId is not eligible for refund (status: $status)');
      return false;
    }

    try {
      // We import WalletService here or use a locator, 
      // but for simplicity we'll just use a local instance.
      final walletService = _WalletServiceInternal(); 
      return await walletService.refund(
        amount: amount,
        orderId: orderId,
        reason: 'Refund for order #$orderId',
      );
    } catch (e) {
      debugPrint('OrderService.initiateRefund error: $e');
      return false;
    }
  }

  /// Internal status normalization.
  String _normalizeStatusCode(String? status) {
    if (status == null) return 'pending';
    final s = status.toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll('.', '_')
        .replaceAll('-', '_')
        .trim();
    
    if (s == 'payment_pending' || s == 'cancelled_draft') return s;

    if (s.contains('pending') || s.contains('placed')) return 'pending';
    if (s.contains('accept') || s.contains('confirm') || s == 'confirment') return 'accepted';
    if (s.contains('prepar') || s.contains('cook')) return 'preparing';
    if (s.contains('ready') || s == 'prepared' || s.contains('pickup')) return 'ready';
    if (s.contains('delivery') || s.contains('dispatch') || s.contains('ship') || s.contains('way')) {
      if (s.contains('out') || s.contains('on_the_way')) return 'out_for_delivery';
      if (s.contains('deliver')) {
        if (s.contains('out')) return 'out_for_delivery';
        return 'delivered';
      }
    }
    if (s.contains('deliver') || s.contains('complete') || s == 'finished') return 'delivered';
    if (s.contains('cancel') || s.contains('reject') || s.contains('decline')) return 'cancelled';
    return s;
  }
}

/// Internal helper to avoid circular dependency if WalletService is in same folder
class _WalletServiceInternal {
  final _supabase = Supabase.instance.client;
  Future<bool> refund({required double amount, required String orderId, required String reason}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;
    final res = await _supabase.rpc('process_order_refund', params: {
      'p_order_id': orderId,
      'p_user_id': userId,
      'p_amount': amount,
      'p_reason': reason,
    });
    return res != null && res['success'] == true;
  }
}
