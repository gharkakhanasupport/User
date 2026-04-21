import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/supabase_config.dart';

/// Review/rating service. Dual-writes to User DB + Kitchen DB so both sides
/// see the review. Falls back gracefully if one side is down.
class ReviewService {
  final SupabaseClient _userDb = Supabase.instance.client;
  SupabaseClient get _kitchenDb => KitchenDbConfig.client;
  SupabaseClient get _kitchenDbRealtime => KitchenDbConfig.realtimeClient;

  /// Submit a review for a delivered order.
  /// Returns true on at least one successful write.
  Future<bool> submitReview({
    required String orderId,
    required String cookId,
    required int kitchenRating,
    int? deliveryRating,
    String? kitchenComment,
    String? deliveryComment,
    String? deliveryPartnerId,
  }) async {
    final userId = _userDb.auth.currentUser?.id;

    final params = {
      'p_order_id': orderId,
      'p_cook_id': cookId,
      'p_user_id': userId,
      'p_kitchen_rating': kitchenRating,
      'p_delivery_rating': deliveryRating,
      'p_kitchen_comment': kitchenComment,
      'p_delivery_comment': deliveryComment,
      'p_delivery_partner_id': deliveryPartnerId,
    };

    bool userOk = false;
    bool kitchenOk = false;

    try {
      final res = await _userDb.rpc('submit_review', params: params);
      userOk = res is Map && res['ok'] == true;
    } catch (e) {
      debugPrint('[ReviewService] user db submit failed: $e');
    }

    try {
      final res = await _kitchenDb.rpc('submit_review', params: params);
      kitchenOk = res is Map && res['ok'] == true;
    } catch (e) {
      debugPrint('[ReviewService] kitchen db submit failed: $e');
    }

    return userOk || kitchenOk;
  }

  /// Has this order already been reviewed by anyone?
  Future<bool> hasReview(String orderId) async {
    try {
      final rows = await _userDb
          .from('reviews')
          .select('id')
          .eq('order_id', orderId)
          .limit(1);
      return (rows as List).isNotEmpty;
    } catch (e) {
      debugPrint('[ReviewService] hasReview: $e');
      return false;
    }
  }

  /// Stream reviews for a given kitchen (used by Kitchen app reviews screen).
  Stream<List<Map<String, dynamic>>> streamKitchenReviews(String cookId) {
    return _kitchenDbRealtime
        .from('reviews')
        .stream(primaryKey: ['id'])
        .eq('cook_id', cookId)
        .order('created_at', ascending: false);
  }

  /// Fetch all reviews for a kitchen from the User DB (one-time).
  /// Returns list of reviews with user name, rating, comment, date.
  Future<List<Map<String, dynamic>>> getKitchenReviews(String cookId, {int limit = 20}) async {
    try {
      final rows = await _userDb
          .from('reviews')
          .select('id, kitchen_rating, kitchen_comment, created_at, user_id, users(name, avatar_url)')
          .eq('cook_id', cookId)
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (e) {
      debugPrint('[ReviewService] getKitchenReviews error: $e');
      // Fallback: try without join
      try {
        final rows = await _userDb
            .from('reviews')
            .select('id, kitchen_rating, kitchen_comment, created_at, user_id')
            .eq('cook_id', cookId)
            .order('created_at', ascending: false)
            .limit(limit);
        return List<Map<String, dynamic>>.from(rows as List);
      } catch (e2) {
        debugPrint('[ReviewService] getKitchenReviews fallback error: $e2');
        return [];
      }
    }
  }

  /// Get aggregate rating stats for a kitchen.
  /// Returns { 'average': double, 'count': int, 'breakdown': {5: n, 4: n, ...} }
  Future<Map<String, dynamic>> getKitchenRatingStats(String cookId) async {
    try {
      final rows = await _userDb
          .from('reviews')
          .select('kitchen_rating')
          .eq('cook_id', cookId);

      final ratings = (rows as List)
          .map((r) => (r['kitchen_rating'] as num?)?.toInt() ?? 0)
          .where((r) => r > 0)
          .toList();

      if (ratings.isEmpty) {
        return {'average': 0.0, 'count': 0, 'breakdown': <int, int>{}};
      }

      final sum = ratings.fold<int>(0, (a, b) => a + b);
      final avg = sum / ratings.length;
      final breakdown = <int, int>{};
      for (final r in ratings) {
        breakdown[r] = (breakdown[r] ?? 0) + 1;
      }

      return {
        'average': double.parse(avg.toStringAsFixed(1)),
        'count': ratings.length,
        'breakdown': breakdown,
      };
    } catch (e) {
      debugPrint('[ReviewService] getKitchenRatingStats error: $e');
      return {'average': 0.0, 'count': 0, 'breakdown': <int, int>{}};
    }
  }
}
