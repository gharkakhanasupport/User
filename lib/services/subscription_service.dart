import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for managing tiffin subscription plans.
/// Handles creating subscriptions, checking active plans,
/// and interacting with the Supabase `subscriptions` table.
class SubscriptionService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Create a new subscription after successful payment.
  Future<Map<String, dynamic>> createSubscription({
    required String planName,
    required int days,
    required double price,
    required double perMealPrice,
    required String paymentId,
    String? kitchenId,
    String? kitchenName,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    final startDate = DateTime.now();
    final endDate = startDate.add(Duration(days: days));

    final data = {
      'user_id': userId,
      'plan_name': planName,
      'days': days,
      'total_price': price,
      'per_meal_price': perMealPrice,
      'meal_count': days, // 1 meal per day
      'meals_remaining': days,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'status': 'active',
      'payment_id': paymentId,
      'kitchen_id': kitchenId,
      'kitchen_name': kitchenName,
    };

    try {
      final result = await _supabase
          .from('subscriptions')
          .insert(data)
          .select()
          .single();
      debugPrint('SubscriptionService: Subscription created — ${result['id']}');
      return result;
    } catch (e) {
      debugPrint('SubscriptionService: Failed to create subscription: $e');
      rethrow;
    }
  }

  /// Fetch all subscriptions for the current user.
  Future<List<Map<String, dynamic>>> getMySubscriptions() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final result = await _supabase
          .from('subscriptions')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      debugPrint('SubscriptionService: Failed to fetch subscriptions: $e');
      return [];
    }
  }

  /// Fetch only active subscriptions.
  Future<List<Map<String, dynamic>>> getActiveSubscriptions() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final result = await _supabase
          .from('subscriptions')
          .select()
          .eq('user_id', userId)
          .eq('status', 'active')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      debugPrint('SubscriptionService: Failed to fetch active subs: $e');
      return [];
    }
  }

  /// Check if user has an active subscription.
  Future<bool> hasActiveSubscription() async {
    final subs = await getActiveSubscriptions();
    return subs.isNotEmpty;
  }

  /// Cancel a subscription.
  Future<bool> cancelSubscription(String subscriptionId) async {
    try {
      await _supabase
          .from('subscriptions')
          .update({'status': 'cancelled'})
          .eq('id', subscriptionId);
      debugPrint('SubscriptionService: Subscription $subscriptionId cancelled');
      return true;
    } catch (e) {
      debugPrint('SubscriptionService: Failed to cancel: $e');
      return false;
    }
  }

  /// Toggle auto-renewal for a subscription.
  Future<bool> toggleAutoRenew(String subscriptionId, bool autoRenew) async {
    try {
      await _supabase
          .from('subscriptions')
          .update({'auto_renewal': autoRenew})
          .eq('id', subscriptionId);
      debugPrint('SubscriptionService: Auto-renew set to $autoRenew for $subscriptionId');
      return true;
    } catch (e) {
      debugPrint('SubscriptionService: Failed to toggle auto-renew: $e');
      return false;
    }
  }
}
