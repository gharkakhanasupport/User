import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/kitchen.dart';
import '../utils/supabase_config.dart';

/// Service for fetching kitchen data with real-time updates.
///
/// ## Performance Note (Fix for 44K Kitchen DB request spike)
/// Previously every method tried User DB first, then fell back to Kitchen DB,
/// causing 2x queries per call (and always hitting Kitchen DB when User DB
/// tables hadn't been synced). Now Kitchen DB is the single source of truth
/// for kitchen profiles, menus, and pricing.
class KitchenService {
  final SupabaseClient _kitchenDb = KitchenDbConfig.client;
  final SupabaseClient _kitchenDbRealtime = KitchenDbConfig.realtimeClient;

  /// Get all available kitchens once (more stable than stream)
  Future<List<Kitchen>> getKitchens() async {
    try {
      final data = await _kitchenDb
          .from('kitchens')
          .select()
          .eq('is_available', true)
          .order('rating', ascending: false);

      return data.map((row) => Kitchen.fromMap(row)).toList();
    } catch (e) {
      debugPrint('Error fetching kitchens: $e');
      return [];
    }
  }

  /// Real-time stream of all available kitchens.
  /// Uses Kitchen DB as the source of truth.
  Stream<List<Kitchen>> getKitchensStream() {
    return _kitchenDbRealtime
        .from('kitchens')
        .stream(primaryKey: ['id'])
        .map((data) {
          final List<Kitchen> kitchens = [];
          for (final row in data) {
            try {
              final k = Kitchen.fromMap(row);
              if (k.isAvailable) kitchens.add(k);
            } catch (e, st) {
              debugPrint('Error parsing kitchen row in getKitchensStream: $row');
              debugPrint('Error: $e\n$st');
            }
          }
          kitchens.sort((a, b) => b.rating.compareTo(a.rating));
          return kitchens;
        });
  }

  /// Real-time stream of ALL kitchens (including unavailable).
  Stream<List<Kitchen>> getAllKitchensStream() {
    return _kitchenDbRealtime
        .from('kitchens')
        .stream(primaryKey: ['id'])
        .map((data) {
          final List<Kitchen> kitchens = [];
          for (final row in data) {
            try {
              kitchens.add(Kitchen.fromMap(row));
            } catch (e, st) {
              debugPrint('Error parsing kitchen row: $row');
              debugPrint('Error: $e\n$st');
            }
          }
          kitchens.sort((a, b) => b.rating.compareTo(a.rating));
          return kitchens;
        });
  }

  /// Get a single kitchen by cook ID.
  /// Kitchen DB is the source of truth for pricing and subscription data.
  Future<Kitchen?> getKitchenByCookId(String cookId) async {
    try {
      final data = await _kitchenDb
          .from('kitchens')
          .select()
          .eq('cook_id', cookId)
          .maybeSingle();

      return data != null ? Kitchen.fromMap(data) : null;
    } catch (e) {
      return null;
    }
  }

  /// Get a single kitchen by its ID.
  /// Kitchen DB is the source of truth for pricing and subscription data.
  Future<Kitchen?> getKitchenById(String kitchenId) async {
    try {
      final data = await _kitchenDb
          .from('kitchens')
          .select()
          .eq('id', kitchenId)
          .maybeSingle();

      return data != null ? Kitchen.fromMap(data) : null;
    } catch (e) {
      return null;
    }
  }

  /// Get a single kitchen by phone number.
  Future<Kitchen?> getKitchenByPhone(String phone) async {
    try {
      final data = await _kitchenDb
          .from('kitchens')
          .select()
          .eq('phone', phone)
          .maybeSingle();

      return data != null ? Kitchen.fromMap(data) : null;
    } catch (e) {
      return null;
    }
  }

  /// Search kitchens by name.
  Future<List<Kitchen>> searchKitchens(String query) async {
    try {
      final data = await _kitchenDb
          .from('kitchens')
          .select()
          .ilike('kitchen_name', '%$query%')
          .eq('is_available', true)
          .order('rating', ascending: false);

      return data.map((row) => Kitchen.fromMap(row)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get vegetarian-only kitchens.
  Future<List<Kitchen>> getVegKitchens() async {
    try {
      final data = await _kitchenDb
          .from('kitchens')
          .select()
          .eq('is_vegetarian', true)
          .eq('is_available', true)
          .order('rating', ascending: false);

      return data.map((row) => Kitchen.fromMap(row)).toList();
    } catch (e) {
      return [];
    }
  }
}
