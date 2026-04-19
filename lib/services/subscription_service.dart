import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/subscription.dart';
import '../services/kitchen_service.dart';

/// Service for managing user subscriptions.
/// Uses the User DB `subscriptions` table for CRUD operations.
class SubscriptionService {
  final SupabaseClient _userDb = Supabase.instance.client;
  final KitchenService _kitchenService = KitchenService();

  /// Create a new subscription after successful payment.
  Future<UserSubscription?> subscribeToKitchen({
    required String kitchenId,
    required String kitchenName,
    required String planType, // 'weekly' or 'monthly'
    required double price,
    required int mealCount,
    String? paymentId,
    String? mealPreferences,
    String? specialInstructions,
  }) async {
    final user = _userDb.auth.currentUser;
    if (user == null) return null;

    try {
      final now = DateTime.now();
      final duration = planType == 'weekly' ? 7 : 30;
      final endDate = now.add(Duration(days: duration));
      final nextBilling = endDate;

      final data = {
        'user_id': user.id,
        'kitchen_id': kitchenId,
        'plan_name': '$kitchenName ${planType == 'weekly' ? 'Weekly' : 'Monthly'} Plan',
        'plan_type': planType,
        'monthly_price': price,
        'meal_count': mealCount,
        'status': 'active',
        'start_date': now.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'next_billing_date': nextBilling.toIso8601String(),
        'last_payment_id': paymentId,
        'auto_renewal': true,
        'meal_preferences': mealPreferences,
        'special_instructions': specialInstructions,
      };

      final response = await _userDb
          .from('subscriptions')
          .insert(data)
          .select()
          .single();

      return UserSubscription.fromMap(response);
    } catch (e) {
      debugPrint('Error creating subscription: $e');
      return null;
    }
  }

  /// Get all subscriptions for the current user.
  Future<List<UserSubscription>> getUserSubscriptions() async {
    final user = _userDb.auth.currentUser;
    if (user == null) return [];

    try {
      final response = await _userDb
          .from('subscriptions')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      final subs = (response as List)
          .map((row) => UserSubscription.fromMap(row))
          .toList();

      // Enrich with kitchen data
      for (int i = 0; i < subs.length; i++) {
        try {
          final kitchen = await _kitchenService.getKitchenById(subs[i].kitchenId);
          if (kitchen != null) {
            subs[i] = UserSubscription(
              id: subs[i].id,
              userId: subs[i].userId,
              kitchenId: subs[i].kitchenId,
              planName: subs[i].planName,
              planType: subs[i].planType,
              monthlyPrice: subs[i].monthlyPrice,
              mealCount: subs[i].mealCount,
              status: subs[i].status,
              startDate: subs[i].startDate,
              endDate: subs[i].endDate,
              nextBillingDate: subs[i].nextBillingDate,
              lastPaymentId: subs[i].lastPaymentId,
              autoRenewal: subs[i].autoRenewal,
              mealPreferences: subs[i].mealPreferences,
              specialInstructions: subs[i].specialInstructions,
              createdAt: subs[i].createdAt,
              updatedAt: subs[i].updatedAt,
              cancelledAt: subs[i].cancelledAt,
              kitchenName: kitchen.kitchenName,
              kitchenImageUrl: kitchen.displayImage,
              kitchenRating: kitchen.ratingText,
            );
          }
        } catch (e) {
          debugPrint('Error enriching subscription with kitchen data: $e');
        }
      }

      return subs;
    } catch (e) {
      debugPrint('Error fetching subscriptions: $e');
      return [];
    }
  }

  /// Get only active subscriptions for the current user.
  Future<List<UserSubscription>> getActiveSubscriptions() async {
    final all = await getUserSubscriptions();
    return all.where((s) => s.isActive).toList();
  }

  /// Get past (expired/cancelled) subscriptions for the current user.
  Future<List<UserSubscription>> getPastSubscriptions() async {
    final all = await getUserSubscriptions();
    return all.where((s) => !s.isActive).toList();
  }

  /// Check if user is already subscribed to a specific kitchen.
  Future<bool> isSubscribedToKitchen(String kitchenId) async {
    final user = _userDb.auth.currentUser;
    if (user == null) return false;

    try {
      final response = await _userDb
          .from('subscriptions')
          .select('id')
          .eq('user_id', user.id)
          .eq('kitchen_id', kitchenId)
          .eq('status', 'active');

      return (response as List).isNotEmpty;
    } catch (e) {
      debugPrint('Error checking subscription status: $e');
      return false;
    }
  }

  /// Cancel a subscription.
  Future<bool> cancelSubscription(String subscriptionId) async {
    try {
      await _userDb
          .from('subscriptions')
          .update({
        'status': 'cancelled',
        'cancelled_at': DateTime.now().toIso8601String(),
        'auto_renewal': false,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', subscriptionId);

      return true;
    } catch (e) {
      debugPrint('Error cancelling subscription: $e');
      return false;
    }
  }

  /// Toggle auto-renewal for a subscription.
  Future<bool> toggleAutoRenew(String subscriptionId, bool enable) async {
    try {
      await _userDb
          .from('subscriptions')
          .update({
        'auto_renewal': enable,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', subscriptionId);

      return true;
    } catch (e) {
      debugPrint('Error toggling auto-renew: $e');
      return false;
    }
  }
}
