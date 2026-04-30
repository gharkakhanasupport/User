import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/menu_item.dart';
import '../models/daily_menu_item.dart';
import '../utils/supabase_config.dart';

/// Service for fetching menu data.
///
/// ## Performance Note (Fix for 44K Kitchen DB request spike)
/// Previously every method tried User DB first, then fell back to Kitchen DB
/// if empty, plus had a catch-block fallback — up to 3 Kitchen DB queries
/// per method call. Now Kitchen DB is the single source of truth (1 query).
/// User DB is only used for data that originates there.
class MenuService {
  final SupabaseClient _kitchenDb = KitchenDbConfig.client;

  /// Get menu items for a kitchen (one-time fetch).
  /// Kitchen DB is the source of truth for menu data.
  Future<List<UserMenuItem>> getAvailableMenuItems(String cookId) async {
    try {
      debugPrint('MenuService: fetching menu_items for cook_id=$cookId');

      final data = await _kitchenDb
          .from('menu_items')
          .select()
          .eq('cook_id', cookId)
          .order('category');

      debugPrint('MenuService: got ${data.length} menu_items');
      return data.map((row) => UserMenuItem.fromMap(row)).toList();
    } catch (e) {
      debugPrint('MenuService error (menu_items): $e');
      return [];
    }
  }

  /// Get daily menu for a kitchen (one-time fetch).
  /// Gets today's menu first. If empty, gets the most recent day's menu.
  Future<List<UserDailyMenuItem>> getTodaysDailyMenu(String cookId) async {
    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    try {
      debugPrint('MenuService: fetching daily_menus for cook_id=$cookId, date=$dateStr');

      // Kitchen DB — source of truth for menus
      var data = await _kitchenDb
          .from('daily_menus')
          .select()
          .eq('cook_id', cookId)
          .eq('date', dateStr)
          .order('category');

      // If no menu for today, get the MOST RECENT day's menu
      if (data.isEmpty) {
        debugPrint('MenuService: no daily_menus for today, getting most recent...');
        data = await _kitchenDb
            .from('daily_menus')
            .select()
            .eq('cook_id', cookId)
            .order('date', ascending: false)
            .limit(20);

        // Filter to only the most recent date
        if (data.isNotEmpty) {
          final latestDate = data.first['date'];
          data = data.where((row) => row['date'] == latestDate).toList();
          debugPrint('MenuService: showing menu from date=$latestDate (${data.length} items)');
        }
      }

      debugPrint('MenuService: got ${data.length} daily_menus');
      return data.map((row) => UserDailyMenuItem.fromMap(row)).toList();
    } catch (e) {
      debugPrint('MenuService error (daily_menus): $e');
      return [];
    }
  }

  /// Get menu items by category for a kitchen.
  Future<List<UserMenuItem>> getMenuByCategory(
    String cookId,
    String category,
  ) async {
    try {
      final data = await _kitchenDb
          .from('menu_items')
          .select()
          .eq('cook_id', cookId)
          .eq('category', category)
          .eq('is_available', true)
          .order('name');

      return data.map((row) => UserMenuItem.fromMap(row)).toList();
    } catch (e) {
      debugPrint('MenuService.getMenuByCategory error: $e');
      return [];
    }
  }

  /// Search menu items across all kitchens.
  Future<List<UserMenuItem>> searchMenuItems(String query) async {
    try {
      final data = await _kitchenDb
          .from('menu_items')
          .select()
          .ilike('name', '%$query%')
          .eq('is_available', true)
          .order('price');

      return data.map((row) => UserMenuItem.fromMap(row)).toList();
    } catch (e) {
      debugPrint('MenuService.searchMenuItems error: $e');
      return [];
    }
  }

  /// Get all menu items grouped by category for a kitchen.
  Future<Map<String, List<UserMenuItem>>> getGroupedMenu(String cookId) async {
    final items = await getAvailableMenuItems(cookId);
    final grouped = <String, List<UserMenuItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }
    return grouped;
  }

  // ─── Global Daily Menu Methods (across all kitchens) ──────────────────

  String get _todayStr {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Get ALL today's daily menu items from ALL kitchens.
  Future<List<UserDailyMenuItem>> getAllTodaysDailyMenuItems() async {
    try {
      final data = await _kitchenDb
          .from('daily_menus')
          .select()
          .eq('date', _todayStr)
          .eq('is_available', true)
          .order('category');

      return data.map((row) => UserDailyMenuItem.fromMap(row)).toList();
    } catch (e) {
      debugPrint('MenuService.getAllTodaysDailyMenuItems error: $e');
      return [];
    }
  }

  /// Get today's daily menu items filtered by meal category across ALL kitchens.
  Future<List<UserDailyMenuItem>> getTodaysDailyMenuByCategory(
    String category,
  ) async {
    try {
      final data = await _kitchenDb
          .from('daily_menus')
          .select()
          .eq('date', _todayStr)
          .eq('category', category.toLowerCase())
          .eq('is_available', true)
          .order('name');

      return data.map((row) => UserDailyMenuItem.fromMap(row)).toList();
    } catch (e) {
      debugPrint('MenuService.getTodaysDailyMenuByCategory error: $e');
      return [];
    }
  }
}
