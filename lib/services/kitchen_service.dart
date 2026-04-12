import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/kitchen.dart';

/// Service for fetching kitchen data with real-time updates.
/// Reads from the `kitchens` table in User DB.
class KitchenService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Real-time stream of all available kitchens.
  /// Updates automatically when kitchen data changes.
  Stream<List<Kitchen>> getKitchensStream() {
    return _supabase
        .from('kitchens')
        .stream(primaryKey: ['id'])
        .order('rating', ascending: false)
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
          return kitchens;
        });
  }

  /// Real-time stream of ALL kitchens (including unavailable).
  Stream<List<Kitchen>> getAllKitchensStream() {
    return _supabase
        .from('kitchens')
        .stream(primaryKey: ['id'])
        .order('rating', ascending: false)
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
          return kitchens;
        });
  }

  /// Get a single kitchen by cook ID.
  Future<Kitchen?> getKitchenByCookId(String cookId) async {
    final data = await _supabase
        .from('kitchens')
        .select()
        .eq('cook_id', cookId)
        .maybeSingle();

    return data != null ? Kitchen.fromMap(data) : null;
  }

  /// Get a single kitchen by its ID.
  Future<Kitchen?> getKitchenById(String kitchenId) async {
    final data = await _supabase
        .from('kitchens')
        .select()
        .eq('id', kitchenId)
        .maybeSingle();

    return data != null ? Kitchen.fromMap(data) : null;
  }

  /// Get a single kitchen by phone number.
  Future<Kitchen?> getKitchenByPhone(String phone) async {
    final data = await _supabase
        .from('kitchens')
        .select()
        .eq('phone', phone)
        .maybeSingle();

    return data != null ? Kitchen.fromMap(data) : null;
  }

  /// Search kitchens by name.
  Future<List<Kitchen>> searchKitchens(String query) async {
    final data = await _supabase
        .from('kitchens')
        .select()
        .ilike('kitchen_name', '%$query%')
        .eq('is_available', true)
        .order('rating', ascending: false);

    return data.map((row) => Kitchen.fromMap(row)).toList();
  }

  /// Get vegetarian-only kitchens.
  Future<List<Kitchen>> getVegKitchens() async {
    final data = await _supabase
        .from('kitchens')
        .select()
        .eq('is_vegetarian', true)
        .eq('is_available', true)
        .order('rating', ascending: false);

    return data.map((row) => Kitchen.fromMap(row)).toList();
  }
}
