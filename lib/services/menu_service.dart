import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/menu_item.dart';
import '../models/daily_menu_item.dart';

/// Service for fetching menu data with real-time updates.
/// Reads from `menu_items` and `daily_menus` tables in User DB.
class MenuService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Real-time stream of all menu items for a kitchen.
  Stream<List<UserMenuItem>> getMenuStream(String cookId) {
    return _supabase
        .from('menu_items')
        .stream(primaryKey: ['id'])
        .eq('cook_id', cookId)
        .order('category')
        .map((data) => data.map((row) => UserMenuItem.fromMap(row)).toList());
  }

  /// Real-time stream of available menu items only.
  Stream<List<UserMenuItem>> getAvailableMenuStream(String cookId) {
    return _supabase
        .from('menu_items')
        .stream(primaryKey: ['id'])
        .eq('cook_id', cookId)
        .order('category')
        .map((data) => data
            .map((row) => UserMenuItem.fromMap(row))
            .where((item) => item.isAvailable)
            .toList());
  }

  /// Get menu items by category for a kitchen.
  Future<List<UserMenuItem>> getMenuByCategory(
    String cookId,
    String category,
  ) async {
    final data = await _supabase
        .from('menu_items')
        .select()
        .eq('cook_id', cookId)
        .eq('category', category)
        .eq('is_available', true)
        .order('name');

    return data.map((row) => UserMenuItem.fromMap(row)).toList();
  }

  /// Real-time stream of today's daily menu for a kitchen.
  Stream<List<UserDailyMenuItem>> getDailyMenuStream(
    String cookId,
    String date,
  ) {
    return _supabase
        .from('daily_menus')
        .stream(primaryKey: ['id'])
        .eq('cook_id', cookId)
        .order('category')
        .map((data) => data
            .map((row) => UserDailyMenuItem.fromMap(row))
            .where((item) => item.date == date)
            .toList());
  }

  /// Get today's daily menu (one-time fetch).
  Future<List<UserDailyMenuItem>> getTodaysDailyMenu(String cookId) async {
    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final data = await _supabase
        .from('daily_menus')
        .select()
        .eq('cook_id', cookId)
        .eq('date', dateStr)
        .eq('is_available', true)
        .order('category');

    return data.map((row) => UserDailyMenuItem.fromMap(row)).toList();
  }

  /// Search menu items across all kitchens.
  Future<List<UserMenuItem>> searchMenuItems(String query) async {
    final data = await _supabase
        .from('menu_items')
        .select()
        .ilike('name', '%$query%')
        .eq('is_available', true)
        .order('price');

    return data.map((row) => UserMenuItem.fromMap(row)).toList();
  }

  /// Get all menu items grouped by category for a kitchen.
  Future<Map<String, List<UserMenuItem>>> getGroupedMenu(String cookId) async {
    final data = await _supabase
        .from('menu_items')
        .select()
        .eq('cook_id', cookId)
        .eq('is_available', true)
        .order('category');

    final items = data.map((row) => UserMenuItem.fromMap(row)).toList();
    final grouped = <String, List<UserMenuItem>>{};

    for (final item in items) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }

    return grouped;
  }

  // ─── Global Daily Menu Methods (across all kitchens) ──────────────────

  /// Get today's date string in YYYY-MM-DD format.
  String get _todayStr {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Get ALL today's daily menu items from ALL kitchens.
  /// Returns available items for today, ordered by category.
  Future<List<UserDailyMenuItem>> getAllTodaysDailyMenuItems() async {
    try {
      final data = await _supabase
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
  /// Pass 'breakfast', 'lunch', 'dinner', 'snacks', or 'special'.
  Future<List<UserDailyMenuItem>> getTodaysDailyMenuByCategory(
    String category,
  ) async {
    try {
      final data = await _supabase
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

  /// Real-time stream of ALL today's daily menus across all kitchens.
  Stream<List<UserDailyMenuItem>> getAllTodaysDailyMenuStream() {
    return _supabase
        .from('daily_menus')
        .stream(primaryKey: ['id'])
        .order('category')
        .map((data) => data
            .map((row) => UserDailyMenuItem.fromMap(row))
            .where((item) => item.date == _todayStr && item.isAvailable)
            .toList());
  }
}

