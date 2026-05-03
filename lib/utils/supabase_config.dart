import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuration for accessing the Kitchen DB from the User App.
/// READS are done via anonKey. WRITES use the service role key for order sync.
class KitchenDbConfig {
  static String get url => dotenv.env['SUPABASE_URL'] ?? '';
  static String get anonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  static String? get serviceKey => dotenv.env['SUPABASE_SERVICE_ROLE_KEY'];
  static final SupabaseClient realtimeClient = Supabase.instance.client;
  static final SupabaseClient writeClient = Supabase.instance.client;
  static final SupabaseClient client = Supabase.instance.client;
}

/// Configuration for accessing the Delivery DB from the User App.
/// READS are done via anonKey.
class DeliveryDbConfig {
  static String get url => dotenv.env['SUPABASE_URL'] ?? '';
  static String get anonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  static String? get serviceKey => dotenv.env['SUPABASE_SERVICE_ROLE_KEY'];
  static final SupabaseClient client = Supabase.instance.client;
  static final SupabaseClient writeClient = Supabase.instance.client;
}
