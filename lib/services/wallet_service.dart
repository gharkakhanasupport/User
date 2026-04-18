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
  Future<bool> addMoney(double amount, String razorpayPaymentId) async {
    if (_userId == null) {
      debugPrint('WalletService: Cannot add money, userId is null');
      return false;
    }

    try {
      // 1. Ensure wallet row exists and get wallet_id
      final data = await _supabase
          .from('wallet')
          .select('id, balance')
          .eq('user_id', _userId!)
          .maybeSingle();

      String? walletId;
      double currentBalance = 0.0;

      if (data != null) {
        walletId = data['id'];
        currentBalance = (data['balance'] ?? 0).toDouble();
      } else {
        // Create wallet if missing
        final newData = await _supabase.from('wallet').insert({
          'user_id': _userId!,
          'balance': 0.0,
        }).select('id').single();
        walletId = newData['id'];
      }

      // 2. Update wallet balance
      await _supabase.from('wallet').update({
        'balance': currentBalance + amount,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', walletId!);

      // 3. Record transaction
      await _supabase.from('wallet_transactions').insert({
        'wallet_id': walletId,
        'amount': amount,
        'type': 'credit',
        'status': 'completed',
        'reference_id': razorpayPaymentId,
        'description': 'Added \u20B9${amount.toStringAsFixed(0)} via Razorpay',
      });

      debugPrint(
          'WalletService: Successfully added \u20B9$amount. New balance: ${currentBalance + amount}');
      return true;
    } catch (e) {
      debugPrint('WalletService.addMoney error: $e');
      return false;
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
        'type': 'credit',
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

  /// Get transaction history
  Future<List<Map<String, dynamic>>> getTransactions() async {
    if (_userId == null) return [];
    try {
      final walletData = await _supabase
          .from('wallet')
          .select('id')
          .eq('user_id', _userId!)
          .maybeSingle();
      if (walletData == null) return [];

      return await _supabase
          .from('wallet_transactions')
          .select()
          .eq('wallet_id', walletData['id'])
          .order('created_at', ascending: false)
          .limit(50);
    } catch (e) {
      debugPrint('WalletService.getTransactions error: $e');
      return [];
    }
  }

  /// Real-time stream of transactions
  Stream<List<Map<String, dynamic>>> getTransactionsStream() {
    if (_userId == null) return Stream.value([]);

    // Note: Stream doesn't support joins easily, so we might need a workaround
    // or just listen to all transactions for now if security allows or use a function
    return _supabase
        .from('wallet_transactions')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
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
