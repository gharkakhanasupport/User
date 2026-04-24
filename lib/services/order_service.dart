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

  /// Place a single-kitchen order into the `orders` table.
  /// Handles wallet debit atomically via RPC if wallet payment.
  /// Synchronization to Kitchen DB is now handled by a database webhook.
  Future<Map<String, dynamic>> placeSingleOrder({
    required String cookId,
    required String customerName,
    required String customerPhone,
    required String deliveryAddress,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required String paymentMethod,
    String? kitchenName,
    double? pickupLat,
    double? pickupLng,
    double? deliveryLat,
    double? deliveryLng,
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

    final orderData = <String, dynamic>{
      'cook_id': cookId,
      'kitchen_name': kitchenName,
      'customer_id': customerId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'delivery_address': deliveryAddress,
      'items': items,
      'total_amount': totalAmount,
      'payment_method': paymentMethod,
      'user_email': _supabase.auth.currentUser?.email,
      'status': OrderStatus.pending,
    };

    if (pickupLat != null) orderData['pickup_lat'] = pickupLat;
    if (pickupLng != null) orderData['pickup_lng'] = pickupLng;
    if (deliveryLat != null) orderData['delivery_lat'] = deliveryLat;
    if (deliveryLng != null) orderData['delivery_lng'] = deliveryLng;

    Map<String, dynamic> result;
    try {
      result = await _supabase
          .from('orders')
          .insert(orderData)
          .select()
          .single();
      debugPrint('OrderService: Order placed in User DB (Webhook will sync to Kitchen).');
    } on PostgrestException catch (e) {
      debugPrint('OrderService: PostgrestException on order insert: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('OrderService: Unexpected error on order insert: $e');
      throw Exception('ORDER_INSERT_FAILED: $e');
    }

    // Log COD / Razorpay transactions
    if (paymentMethod == 'cod' || paymentMethod == 'razorpay') {
      try {
        var walletData = await _supabase
            .from('wallet')
            .select('id')
            .eq('user_id', customerId)
            .maybeSingle();

        if (walletData == null) {
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
  /// Relies on server-side sync to update 'status' from Kitchen/Delivery DBs.
  Stream<List<Map<String, dynamic>>> getMyOrdersStream() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return const Stream.empty();

    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('customer_id', userId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map((row) {
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
