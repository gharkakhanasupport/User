import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WalletService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? get _userId => _supabase.auth.currentUser?.id;

  /// Get current wallet balance
  Future<double> getBalance() async {
    if (_userId == null) return 0.0;
    try {
      final data = await _supabase
          .from('wallet')
          .select('balance')
          .eq('user_id', _userId!)
          .maybeSingle();
      if (data == null) return 0.0;
      return (data['balance'] ?? 0).toDouble();
    } catch (e) {
      debugPrint('WalletService.getBalance error: $e');
      return 0.0;
    }
  }

  /// Real-time stream of wallet balance
  Stream<double> getBalanceStream() {
    if (_userId == null) return Stream.value(0.0);
    return _supabase
        .from('wallet')
        .stream(primaryKey: ['id'])
        .eq('user_id', _userId!)
        .map((rows) {
      if (rows.isEmpty) return 0.0;
      return (rows.first['balance'] ?? 0).toDouble();
    });
  }

  /// Add money to wallet (after Razorpay payment success)
  /// Uses a secure RPC to ensure atomicity and bypass RLS restriction on balance updates.
  Future<bool> addMoney(double amount, String razorpayPaymentId) async {
    if (_userId == null) {
      debugPrint('WalletService: Cannot add money, userId is null');
      return false;
    }

    try {
      await _supabase.rpc('top_up_wallet', params: {
        'p_user_id': _userId!,
        'p_amount': amount,
        'p_reference_id': razorpayPaymentId,
        'p_description': 'Added \u20B9${amount.toStringAsFixed(0)} via Razorpay',
      });

      debugPrint('WalletService: Successfully added \u20B9$amount via RPC.');
      return true;
    } catch (e, stack) {
      debugPrint('WalletService.addMoney ERROR: $e');
      debugPrint('Stacktrace: $stack');
      return false;
    }
  }

  /// Get the wallet ID for the current user
  Future<String?> getWalletId() async {
    if (_userId == null) return null;
    try {
      final data = await _supabase
          .from('wallet')
          .select('id')
          .eq('user_id', _userId!)
          .maybeSingle();
      return data?['id'];
    } catch (e) {
      debugPrint('WalletService.getWalletId error: $e');
      return null;
    }
  }

  /// Pay from wallet using atomic RPC (prevents double-spending)
  /// Returns true if successful, false if insufficient balance or error
  Future<bool> payFromWallet(double amount, String orderId) async {
    if (_userId == null) return false;
    try {
      // Use the newly deployed process_wallet_payment RPC
      await _supabase.rpc('process_wallet_payment', params: {
        'p_user_id': _userId!,
        'p_amount': amount,
        'p_order_id': orderId,
      });
      debugPrint('WalletService: Paid \u20B9$amount for order $orderId');
      return true;
    } catch (e) {
      debugPrint('WalletService.payFromWallet error: $e');
      return false;
    }
  }

  /// Record a refund to wallet
  Future<bool> refund(double amount, String orderId) async {
    if (_userId == null) return false;
    try {
      final data = await _supabase
          .from('wallet')
          .select('id, balance')
          .eq('user_id', _userId!)
          .maybeSingle();

      if (data == null) return false;
      final walletId = data['id'];
      final current = (data['balance'] ?? 0).toDouble();

      await _supabase.from('wallet').update({
        'balance': current + amount,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', walletId);

      await _supabase.from('wallet_transactions').insert({
        'wallet_id': walletId,
        'amount': amount,
        'type': 'refund',
        'status': 'completed',
        'related_order_id': orderId,
        'description': 'Refund for cancelled order',
      });
      return true;
    } catch (e) {
      debugPrint('WalletService.refund error: $e');
      return false;
    }
  }

  /// Get transaction history (wallet + order-based payments merged)
  Future<List<Map<String, dynamic>>> getTransactions() async {
    if (_userId == null) return [];
    try {
      final walletData = await _supabase
          .from('wallet')
          .select('id')
          .eq('user_id', _userId!)
          .maybeSingle();

      List<Map<String, dynamic>> walletTxns = [];
      if (walletData != null) {
        final data = await _supabase
            .from('wallet_transactions')
            .select()
            .eq('wallet_id', walletData['id'])
            .order('created_at', ascending: false)
            .limit(50);
        walletTxns = data.map((t) => _mapTransaction(t)).toList();
      }

      // Also fetch COD and Online orders directly from orders table
      // This is a robust fallback in case wallet_transactions inserts failed
      List<Map<String, dynamic>> orderTxns = [];
      try {
        final orders = await _supabase
            .from('orders')
            .select('id, total_amount, payment_method, created_at, status, customer_name')
            .eq('customer_id', _userId!)
            .inFilter('payment_method', ['cod', 'razorpay'])
            .order('created_at', ascending: false)
            .limit(50);

        // Build a set of order IDs already tracked in wallet_transactions
        final trackedOrderIds = walletTxns
            .where((t) => t['related_order_id'] != null)
            .map((t) => t['related_order_id'].toString())
            .toSet();

        for (final o in orders) {
          final orderId = o['id'].toString();
          if (trackedOrderIds.contains(orderId)) continue; // already tracked

          final pm = o['payment_method']?.toString() ?? 'cod';
          final amount = (o['total_amount'] ?? 0).toDouble();
          orderTxns.add({
            'id': 'order_$orderId',
            'amount': amount,
            'transaction_type': pm == 'cod' ? 'cod_payment' : 'online_payment',
            'status': 'completed',
            'related_order_id': orderId,
            'created_at': o['created_at'],
            'description': pm == 'cod'
                ? 'Cash on Delivery - \u20B9${amount.toStringAsFixed(0)}'
                : 'Online payment via Razorpay - \u20B9${amount.toStringAsFixed(0)}',
          });
        }
      } catch (e) {
        debugPrint('WalletService: order-based txn fetch failed: $e');
      }

      // Merge and sort by created_at descending
      final all = [...walletTxns, ...orderTxns];
      all.sort((a, b) {
        final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(2000);
        final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });

      return all;
    } catch (e) {
      debugPrint('WalletService.getTransactions error: $e');
      return [];
    }
  }

  /// Real-time stream of transactions
  Stream<List<Map<String, dynamic>>> getTransactionsStream() async* {
    if (_userId == null) {
      yield [];
      return;
    }

    final walletData = await _supabase
        .from('wallet')
        .select('id')
        .eq('user_id', _userId!)
        .maybeSingle();
    
    if (walletData == null) {
      yield [];
      return;
    }

    yield* _supabase
        .from('wallet_transactions')
        .stream(primaryKey: ['id'])
        .eq('wallet_id', walletData['id'])
        .order('created_at', ascending: false)
        .map((rows) => rows.map((t) => _mapTransaction(t)).toList());
  }

  /// Map DB types to UI types
  Map<String, dynamic> _mapTransaction(Map<String, dynamic> t) {
    String uiType = t['type'] ?? '';
    // Map DB types to UI-friendly types
    if (uiType == 'credit') uiType = 'top_up';
    if (uiType == 'debit') uiType = 'order_payment';
    // cod_payment and online_payment pass through as-is

    return {
      ...t,
      'transaction_type': uiType, // Map back to UI legacy key
    };
  }

  /// Ensure wallet row exists for current user
  Future<void> ensureWalletExists() async {
    if (_userId == null) return;
    try {
      final data = await _supabase
          .from('wallet')
          .select('id')
          .eq('user_id', _userId!)
          .maybeSingle();
      if (data == null) {
        await _supabase.from('wallet').insert({
          'user_id': _userId!,
          'balance': 0.0,
        });
      }
    } catch (e) {
      debugPrint('WalletService.ensureWalletExists error: $e');
    }
  }
}
