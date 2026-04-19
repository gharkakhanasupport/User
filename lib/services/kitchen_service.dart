import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/kitchen.dart';
import '../utils/supabase_config.dart';

/// Service for fetching kitchen data with real-time updates.
/// Tries User DB first, falls back to Kitchen DB.
class KitchenService {
  final SupabaseClient _userDb = Supabase.instance.client;
  final SupabaseClient _kitchenDb = KitchenDbConfig.client;

  /// Get all available kitchens once (more stable than stream)
  Future<List<Kitchen>> getKitchens() async {
    try {
      var data = await _userDb
          .from('kitchens')
          .select()
          .eq('is_available', true)
          .order('rating', ascending: false);

      if (data.isEmpty) {
        data = await _kitchenDb
            .from('kitchens')
            .select()
            .eq('is_available', true)
            .order('rating', ascending: false);
      }

      return data.map((row) => Kitchen.fromMap(row)).toList();
    } catch (e) {
      debugPrint('Error fetching kitchens: $e');
      return [];
    }
  }

  /// Real-time stream of all available kitchens.
  /// First, it tries the User DB. If the app uses Kitchen DB primarily, it will listen to Kitchen DB.
  /// Currently we'll merge them or use Kitchen DB if User DB yields empty.
  /// To keep it simple, we'll listen to Kitchen DB since that's the source of truth requested.
  Stream<List<Kitchen>> getKitchensStream() {
    // Listen to Kitchen DB stream as fallback if User DB stream is tricky to combine
    // We'll yield from Kitchen DB for accurate kitchen display as requested by user.
    return _kitchenDb
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
          // Sort after fetching, as stream() doesn't support order() well sometimes, but we can do it locally:
          kitchens.sort((a, b) => b.rating.compareTo(a.rating));
          return kitchens;
        });
  }

  /// Real-time stream of ALL kitchens (including unavailable).
  Stream<List<Kitchen>> getAllKitchensStream() {
    return _kitchenDb
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
  /// Kitchen DB is the source of truth (chef admin sets pricing there).
  Future<Kitchen?> getKitchenByCookId(String cookId) async {
    try {
      // Kitchen DB first — source of truth for subscription pricing, menu, etc.
      var data = await _kitchenDb
          .from('kitchens')
          .select()
          .eq('cook_id', cookId)
          .maybeSingle();

      // Fall back to User DB only if Kitchen DB has no data
      data ??= await _userDb
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
      // Kitchen DB first — source of truth for subscription pricing
      var data = await _kitchenDb
          .from('kitchens')
          .select()
          .eq('id', kitchenId)
          .maybeSingle();

      // Fall back to User DB
      data ??= await _userDb
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
      var data = await _userDb
          .from('kitchens')
          .select()
          .eq('phone', phone)
          .maybeSingle();

      data ??= await _kitchenDb
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
      var data = await _userDb
          .from('kitchens')
          .select()
          .ilike('kitchen_name', '%$query%')
          .eq('is_available', true)
          .order('rating', ascending: false);

      if (data.isEmpty) {
        data = await _kitchenDb
            .from('kitchens')
            .select()
            .ilike('kitchen_name', '%$query%')
            .eq('is_available', true)
            .order('rating', ascending: false);
      }

      return data.map((row) => Kitchen.fromMap(row)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get vegetarian-only kitchens.
  Future<List<Kitchen>> getVegKitchens() async {
    try {
      var data = await _userDb
          .from('kitchens')
          .select()
          .eq('is_vegetarian', true)
          .eq('is_available', true)
          .order('rating', ascending: false);

      if (data.isEmpty) {
        data = await _kitchenDb
            .from('kitchens')
            .select()
            .eq('is_vegetarian', true)
            .eq('is_available', true)
            .order('rating', ascending: false);
      }

      return data.map((row) => Kitchen.fromMap(row)).toList();
    } catch (e) {
      return [];
    }
  }
}

