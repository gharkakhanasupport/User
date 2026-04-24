import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LogService {
  /// Log a critical integration error (e.g. Schema Mismatch, Permission Denied)
  /// Use this when User, Kitchen, or Delivery apps have communication issues.
  static void logIntegrationError(String appSource, String message, dynamic error) {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🔴 CRITICAL INTEGRATION ERROR');
    debugPrint('SOURCE: $appSource');
    debugPrint('MESSAGE: $message');
    if (error != null) {
      debugPrint('DETAILS: $error');
      if (error is PostgrestException) {
        debugPrint('DB CODE: ${error.code}');
        debugPrint('DB HINT: ${error.hint}');
      }
    }
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    
    // Future expansion: 
    // You can send these logs to a 'system_logs' table in Supabase 
    // so teammates can monitor breaking changes in real-time.
  }

  static void logInfo(String message) {
    debugPrint('ℹ️ [GKK INFO]: $message');
  }
}
