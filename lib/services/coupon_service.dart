import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service to validate and apply coupons to cart
class CouponService {
  final _supabase = Supabase.instance.client;

  /// Validate and get coupon details
  /// Returns coupon data if valid, null if invalid
  /// Coupons are CASE-SENSITIVE
  Future<Map<String, dynamic>?> validateCoupon(String code) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      
      if (userId == null) {
        debugPrint('❌ Coupon validation failed: User not logged in');
        return null;
      }

      // Query coupon - case sensitive match
      final response = await _supabase
          .from('coupons')
          .select()
          .eq('code', code) // Case sensitive
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) {
        debugPrint('❌ Coupon not found or inactive: $code');
        return null;
      }

      // Check if it's a specific user coupon
      final couponType = response['coupon_type'] as String;
      final specificUserEmail = response['specific_user_email'] as String?;

      if (couponType == 'specific' && specificUserEmail != null) {
        final userEmail = _supabase.auth.currentUser?.email;
        if (userEmail == null || specificUserEmail != userEmail) {
          debugPrint('❌ Coupon is for a different user (Expected: $specificUserEmail, Got: $userEmail)');
          return null;
        }
      }

      // Check validity dates
      final validFrom = response['valid_from'] != null 
          ? DateTime.parse(response['valid_from']) 
          : null;
      final validUntil = response['valid_until'] != null 
          ? DateTime.parse(response['valid_until']) 
          : null;
      final now = DateTime.now();

      if (validFrom != null && now.isBefore(validFrom)) {
        debugPrint('❌ Coupon not yet valid');
        return null;
      }

      if (validUntil != null && now.isAfter(validUntil)) {
        debugPrint('❌ Coupon expired');
        return null;
      }

      // Check usage limit
      final usageLimit = response['usage_limit'] as int?;
      final timesUsed = response['times_used'] as int? ?? 0;

      if (usageLimit != null && timesUsed >= usageLimit) {
        debugPrint('❌ Coupon usage limit reached');
        return null;
      }

      debugPrint('✅ Coupon valid: $code - ${response['discount_percent']}% off');
      return response;
    } catch (e) {
      debugPrint('❌ Coupon validation error: $e');
      return null;
    }
  }

  /// Calculate discounted price
  double calculateDiscount(double originalPrice, int discountPercent) {
    return originalPrice * (discountPercent / 100);
  }

  /// Record coupon usage after order is placed
  Future<bool> recordCouponUsage({
    required String couponId,
    required String? orderId,
    required double discountAmount,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      // Insert usage record
      await _supabase.from('coupon_usage').insert({
        'coupon_id': couponId,
        'user_id': userId,
        'order_id': orderId,
        'discount_amount': discountAmount,
      });

      // Increment times_used counter
      await _supabase.rpc('increment_coupon_usage', params: {'coupon_id': couponId});

      debugPrint('✅ Coupon usage recorded');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to record coupon usage: $e');
      return false;
    }
  }
}
