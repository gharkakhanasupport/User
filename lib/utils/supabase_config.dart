import 'package:supabase_flutter/supabase_flutter.dart';

/// Configuration for accessing the Kitchen DB from the User App.
/// Used for dual-write when placing orders (so Kitchen App sees them).
class KitchenDbConfig {
  static const String url = 'https://yvbjnuobnxekgibfqsmq.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl2YmpudW9ibnhla2dpYmZxc21xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUzOTY1NzIsImV4cCI6MjA5MDk3MjU3Mn0.Hf5zPb8urWQq155fUxF7kQIGFb0NyWphdMyeRI83vgk';

  static SupabaseClient? _client;
  static SupabaseClient get client {
    _client ??= SupabaseClient(url, anonKey);
    return _client!;
  }
}
