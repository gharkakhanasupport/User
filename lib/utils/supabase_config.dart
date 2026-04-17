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
class KitchenDbConfig {
  static String get url =>
      _env('KITCHEN_SUPABASE_URL') ?? 'https://yvbjnuobnxekgibfqsmq.supabase.co';
  static String get anonKey =>
      _env('KITCHEN_SUPABASE_ANON_KEY') ??
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl2YmpudW9ibnhla2dpYmZxc21xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUzOTY1NzIsImV4cCI6MjA5MDk3MjU3Mn0.Hf5zPb8urWQq155fUxF7kQIGFb0NyWphdMyeRI83vgk';

  static SupabaseClient? _client;
  static SupabaseClient get client {
    _client ??= SupabaseClient(url, anonKey);
    return _client!;
  }
}
