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
///
/// ## Image Resolution
/// Kitchen images are stored in Supabase Storage under
/// `kitchen-photos/{cook_id}/logo/` but the DB columns (profile_image_url,
/// kitchen_photos) are often null. This service resolves images from storage
/// when DB values are missing.
class KitchenService {
  final SupabaseClient _kitchenDb = KitchenDbConfig.client;
  final SupabaseClient _kitchenDbRealtime = KitchenDbConfig.realtimeClient;

  /// Kitchen DB storage base URL for public files.
  static const String _storageBase =
      'https://yvbjnuobnxekgibfqsmq.supabase.co/storage/v1/object/public/kitchen-photos';

  /// Cache of cook_id -> resolved logo URL to avoid repeated storage lookups.
  static final Map<String, String?> _logoCache = {};

  /// Resolve the profile image for a kitchen from Supabase Storage.
  /// Looks for files in `kitchen-photos/{cookId}/logo/` and returns the
  /// public URL of the most recently uploaded logo.
  Future<String?> _resolveLogoUrl(String cookId) async {
    // Return cached value if available
    if (_logoCache.containsKey(cookId)) return _logoCache[cookId];

    try {
      final files = await _kitchenDb.storage
          .from('kitchen-photos')
          .list(path: '$cookId/logo');

      if (files.isNotEmpty) {
        // Sort by name descending (timestamp in filename → latest first)
        files.sort((a, b) => (b.name).compareTo(a.name));
        final latestFile = files.first;
        final url = '$_storageBase/$cookId/logo/${latestFile.name}';
        _logoCache[cookId] = url;
        return url;
      }
    } catch (e) {
      debugPrint('[KitchenService] Error resolving logo for $cookId: $e');
    }

    _logoCache[cookId] = null;
    return null;
  }

  /// Enrich a list of Kitchen objects by resolving missing images from storage.
  Future<List<Kitchen>> _enrichWithImages(List<Kitchen> kitchens) async {
    final futures = kitchens.map((k) async {
      if (k.profileImageUrl != null && k.profileImageUrl!.isNotEmpty) return k;

      final logoUrl = await _resolveLogoUrl(k.cookId);
      if (logoUrl != null) {
        // Return a new Kitchen with the resolved image
        return Kitchen(
          id: k.id,
          cookId: k.cookId,
          kitchenName: k.kitchenName,
          description: k.description,
          ownerName: k.ownerName,
          phone: k.phone,
          email: k.email,
          location: k.location,
          isVegetarian: k.isVegetarian,
          kitchenPhotos: k.kitchenPhotos,
          isAvailable: k.isAvailable,
          rating: k.rating,
          totalOrders: k.totalOrders,
          profileImageUrl: logoUrl,
          createdAt: k.createdAt,
          weeklyPlanPrice: k.weeklyPlanPrice,
          monthlyPlanPrice: k.monthlyPlanPrice,
          subscriptionMenu: k.subscriptionMenu,
          subscriptionBenefits: k.subscriptionBenefits,
        );
      }
      return k;
    });
    return Future.wait(futures);
  }

  /// Get all available kitchens once (more stable than stream)
  Future<List<Kitchen>> getKitchens() async {
    try {
      final data = await _kitchenDb
          .from('kitchens')
          .select()
          .eq('is_available', true)
          .order('rating', ascending: false);

      final kitchens = data.map((row) => Kitchen.fromMap(row)).toList();
      return _enrichWithImages(kitchens);
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
        .asyncMap((data) async {
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
          return _enrichWithImages(kitchens);
        });
  }

  /// Real-time stream of ALL kitchens (including unavailable).
  Stream<List<Kitchen>> getAllKitchensStream() {
    return _kitchenDbRealtime
        .from('kitchens')
        .stream(primaryKey: ['id'])
        .asyncMap((data) async {
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
          return _enrichWithImages(kitchens);
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

      if (data == null) return null;
      final kitchen = Kitchen.fromMap(data);
      final enriched = await _enrichWithImages([kitchen]);
      return enriched.first;
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

      if (data == null) return null;
      final kitchen = Kitchen.fromMap(data);
      final enriched = await _enrichWithImages([kitchen]);
      return enriched.first;
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

      if (data == null) return null;
      final kitchen = Kitchen.fromMap(data);
      final enriched = await _enrichWithImages([kitchen]);
      return enriched.first;
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

      final kitchens = data.map((row) => Kitchen.fromMap(row)).toList();
      return _enrichWithImages(kitchens);
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

      final kitchens = data.map((row) => Kitchen.fromMap(row)).toList();
      return _enrichWithImages(kitchens);
    } catch (e) {
      return [];
    }
  }
}

