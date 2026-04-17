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
          .from('wallets')
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
        .from('wallets')
        .stream(primaryKey: ['user_id'])
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
      // 1. Ensure wallet row exists and get current balance
      final data = await _supabase
          .from('wallets')
          .select('balance')
          .eq('user_id', _userId!)
          .maybeSingle();
      
      double currentBalance = 0.0;
      if (data != null) {
        currentBalance = (data['balance'] ?? 0).toDouble();
      }

      // 2. Upsert wallet balance
      await _supabase.from('wallets').upsert({
        'user_id': _userId!,
        'balance': currentBalance + amount,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      // 3. Record transaction
      await _supabase.from('wallet_transactions').insert({
        'user_id': _userId!,
        'amount': amount,
        'transaction_type': 'top_up',
        'status': 'completed',
        'razorpay_payment_id': razorpayPaymentId,
        'description': 'Added ₹${amount.toStringAsFixed(0)} via Razorpay',
      });

      debugPrint('WalletService: Successfully added ₹$amount. New balance: ${currentBalance + amount}');
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
      await _supabase.rpc('process_wallet_payment', params: {
        'p_user_id': _userId!,
        'p_amount': amount,
        'p_order_id': orderId,
      });
      debugPrint('WalletService: Paid \u20B9$amount for order $orderId');
      return true;
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      debugPrint('WalletService.payFromWallet error: $e');
      // Only fallback if the RPC function doesn't exist (not set up yet)
      if (errStr.contains('does not exist') ||
          errStr.contains('could not find the function') ||
          errStr.contains('404')) {
        debugPrint('WalletService: RPC not found, using manual fallback');
        return await _manualPayment(amount, orderId);
      }
      // Insufficient balance or other real errors — don't fallback
      return false;
    }
  }

  /// Fallback manual payment if RPC not set up yet
  Future<bool> _manualPayment(double amount, String orderId) async {
    try {
      final balance = await getBalance();
      if (balance < amount) return false;

      await _supabase.from('wallets').update({
        'balance': balance - amount,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('user_id', _userId!);

      // Re-read to verify balance didn't go negative (race guard)
      final newBalance = await getBalance();
      if (newBalance < 0) {
        // Revert — another transaction raced us
        await _supabase.from('wallets').update({
          'balance': newBalance + amount,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('user_id', _userId!);
        debugPrint('WalletService: Race detected, reverted payment');
        return false;
      }

      await _supabase.from('wallet_transactions').insert({
        'user_id': _userId!,
        'amount': amount,
        'transaction_type': 'order_payment',
        'status': 'completed',
        'order_id': orderId,
        'description': 'Payment for order',
      });

      return true;
    } catch (e) {
      debugPrint('WalletService._manualPayment error: $e');
      return false;
    }
  }

  /// Record a refund to wallet
  Future<bool> refund(double amount, String orderId) async {
    if (_userId == null) return false;
    try {
      final current = await getBalance();
      await _supabase.from('wallets').upsert({
        'user_id': _userId!,
        'balance': current + amount,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      await _supabase.from('wallet_transactions').insert({
        'user_id': _userId!,
        'amount': amount,
        'transaction_type': 'refund',
        'status': 'completed',
        'order_id': orderId,
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
      return await _supabase
          .from('wallet_transactions')
          .select()
          .eq('user_id', _userId!)
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
    return _supabase
        .from('wallet_transactions')
        .stream(primaryKey: ['id'])
        .eq('user_id', _userId!)
        .order('created_at', ascending: false);
  }

  /// Ensure wallet row exists for current user
  Future<void> ensureWalletExists() async {
    if (_userId == null) return;
    try {
      final data = await _supabase
          .from('wallets')
          .select('user_id')
          .eq('user_id', _userId!)
          .maybeSingle();
      if (data == null) {
        await _supabase.from('wallets').insert({
          'user_id': _userId!,
          'balance': 0.0,
        });
      }
    } catch (e) {
      debugPrint('WalletService.ensureWalletExists error: $e');
    }
  }
}
