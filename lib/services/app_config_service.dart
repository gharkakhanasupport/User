import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Realtime singleton that streams the `app_config` table.
/// Exposes [isSplitKitchenEnabled] which is kept in sync via
/// Supabase Realtime so changes reflect instantly without restart.
class AppConfigService extends ChangeNotifier {
  static final AppConfigService _instance = AppConfigService._internal();
  static AppConfigService get instance => _instance;

  final SupabaseClient _supabase = Supabase.instance.client;
  StreamSubscription? _subscription;

  bool _splitKitchenEnabled = true; // default: split enabled
  bool _initialized = false;

  AppConfigService._internal();

  bool get isSplitKitchenEnabled => _splitKitchenEnabled;
  bool get isInitialized => _initialized;

  /// Must be called once at app startup (e.g. in main.dart).
  Future<void> init() async {
    if (_initialized) return;

    // 1. Fetch current value
    try {
      final rows = await _supabase
          .from('app_config')
          .select()
          .eq('id', 'global')
          .limit(1);

      if (rows.isNotEmpty) {
        _splitKitchenEnabled = rows.first['split_kitchen_enabled'] ?? true;
      }
    } catch (e) {
      debugPrint('AppConfigService: initial fetch failed: $e');
      // Keep default (true)
    }

    // 2. Subscribe to realtime changes
    _supabase
        .channel('app_config_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'app_config',
          callback: (payload) {
            final newRecord = payload.newRecord;
            if (newRecord.containsKey('split_kitchen_enabled')) {
              final newValue = newRecord['split_kitchen_enabled'] as bool? ?? true;
              if (newValue != _splitKitchenEnabled) {
                _splitKitchenEnabled = newValue;
                debugPrint('AppConfigService: split_kitchen_enabled changed to $_splitKitchenEnabled');
                notifyListeners();
              }
            }
          },
        )
        .subscribe();

    _initialized = true;
    debugPrint('AppConfigService: initialized, splitKitchenEnabled=$_splitKitchenEnabled');
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _supabase.removeChannel(_supabase.channel('app_config_realtime'));
    super.dispose();
  }
}
