import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Helper to safely read dotenv values (returns null if dotenv isn't loaded)
String? _env(String key) {
  try {
    return dotenv.env[key];
  } catch (_) {
    return null;
  }
}

/// Configuration for accessing the Kitchen DB from the User App.
/// Used for dual-write when placing orders (so Kitchen App sees them).
///
/// Uses the **service role key** because this is a cross-project write:
/// the User App inserts rows into a *different* Supabase project's tables.
/// The anon key would be blocked by RLS policies on the Kitchen DB,
/// so the service role key is required to ensure reliable syncing.
class KitchenDbConfig {
  static String get url =>
      _env('KITCHEN_DB_URL') ??
      'https://yvbjnuobnxekgibfqsmq.supabase.co';

  /// Service role key — bypasses RLS for cross-project writes.
  /// For production at scale, move cross-DB writes to a Supabase Edge Function.
  static String get serviceKey =>
      _env('KITCHEN_DB_SERVICE_KEY') ??
      _env('KITCHEN_DB_ANON_KEY') ??
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl2YmpudW9ibnhla2dpYmZxc21xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUzOTY1NzIsImV4cCI6MjA5MDk3MjU3Mn0.Hf5zPb8urWQq155fUxF7kQIGFb0NyWphdMyeRI83vgk';

  /// Anon key — used only for Realtime subscriptions (read-only streams).
  /// Realtime requires the anon key; service role key doesn't work with it.
  static String get anonKey =>
      _env('KITCHEN_DB_ANON_KEY') ??
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl2YmpudW9ibnhla2dpYmZxc21xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUzOTY1NzIsImV4cCI6MjA5MDk3MjU3Mn0.Hf5zPb8urWQq155fUxF7kQIGFb0NyWphdMyeRI83vgk';

  /// Client for WRITES (upserts, inserts) — uses service role key.
  static SupabaseClient? _writeClient;
  static SupabaseClient get client {
    _writeClient ??= SupabaseClient(url, serviceKey);
    return _writeClient!;
  }

  /// Client for READS / Realtime streams — uses anon key.
  static SupabaseClient? _readClient;
  static SupabaseClient get realtimeClient {
    _readClient ??= SupabaseClient(url, anonKey);
    return _readClient!;
  }
}
