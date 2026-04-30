import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Helper to safely read dotenv values
String? _env(String key) {
  try {
    return dotenv.env[key];
  } catch (_) {
    return null;
  }
}

/// Configuration for accessing the Kitchen DB from the User App.
/// READS are done via anonKey. WRITES use the service role key for order sync.
class KitchenDbConfig {
  static String get url =>
      _env('KITCHEN_DB_URL') ??
      'https://yvbjnuobnxekgibfqsmq.supabase.co';

  /// Anon key — used for Realtime subscriptions and reads.
  static String get anonKey =>
      _env('KITCHEN_DB_ANON_KEY') ??
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl2YmpudW9ibnhla2dpYmZxc21xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUzOTY1NzIsImV4cCI6MjA5MDk3MjU3Mn0.Hf5zPb8urWQq155fUxF7kQIGFb0NyWphdMyeRI83vgk';

  /// Service key — used for cross-DB writes (order sync to Kitchen).
  static String? get serviceKey => _env('KITCHEN_DB_SERVICE_KEY');

  /// Client for READS / Realtime streams — uses anon key.
  static SupabaseClient? _readClient;
  static SupabaseClient get realtimeClient {
    _readClient ??= SupabaseClient(url, anonKey);
    return _readClient!;
  }

  /// Client for WRITES — uses service role key (bypasses RLS).
  /// Returns null if the service key is not configured.
  static SupabaseClient? _writeClient;
  static SupabaseClient? get writeClient {
    if (serviceKey == null || serviceKey!.isEmpty) return null;
    _writeClient ??= SupabaseClient(url, serviceKey!);
    return _writeClient;
  }

  /// Default client for reads (backward-compatible).
  static SupabaseClient get client => realtimeClient;
}

/// Configuration for accessing the Delivery DB from the User App.
/// READS are done via anonKey.
class DeliveryDbConfig {
  static String get url =>
      _env('DELIVERY_DB_URL') ??
      'https://uinictqyoycnwrnggznz.supabase.co';

  static String get anonKey =>
      _env('DELIVERY_DB_ANON_KEY') ??
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVpbmljdHF5b3ljbndybmdnem56Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU5MDAxNzcsImV4cCI6MjA5MTQ3NjE3N30.1gnNgwbl71-7E4y7hBFTi4P0TV1E1QeFL0JWhLLcGbM';

  static SupabaseClient? _readClient;
  static SupabaseClient get realtimeClient {
    _readClient ??= SupabaseClient(url, anonKey);
    return _readClient!;
  }

  static SupabaseClient get client => realtimeClient;
}
