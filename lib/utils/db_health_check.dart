import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cross-DB health check utility.
/// Verifies that the configured Supabase connections can read basic tables.
class DbHealthCheck {
  static Future<Map<String, Map<String, String>>> runFullCheck() async {
    final report = <String, Map<String, String>>{};

    report['user_db'] = await _checkTable(
      label: 'User DB',
      client: Supabase.instance.client,
      tableName: 'users',
    );

    report['kitchen_db'] = await _checkConfiguredClient(
      envUrlKey: 'KITCHEN_DB_URL',
      envKeyKey: 'KITCHEN_DB_ANON_KEY',
      label: 'Kitchen DB',
      testTable: 'orders',
    );

    report['admin_db'] = await _checkConfiguredClient(
      envUrlKey: 'ADMIN_DB_URL',
      envKeyKey: 'ADMIN_DB_ANON_KEY',
      label: 'Admin DB',
      testTable: 'users',
    );

    report['orders_table'] = await _checkTable(
      label: 'orders table',
      client: Supabase.instance.client,
      tableName: 'orders',
    );

    report['menu_items_table'] = await _checkTable(
      label: 'menu_items table',
      client: Supabase.instance.client,
      tableName: 'menu_items',
    );

    debugPrint('╔══════════════════════════════════════╗');
    debugPrint('║      GKK DB HEALTH CHECK REPORT      ║');
    debugPrint('╠══════════════════════════════════════╣');
    for (final entry in report.entries) {
      final status = entry.value['status'] == 'ok' ? '✅' : '❌';
      debugPrint('║ $status ${entry.key.padRight(25)} ${entry.value['status']?.toUpperCase().padRight(8)} ║');
      final message = entry.value['message'];
      if (message != null && message.isNotEmpty && entry.value['status'] != 'ok') {
        debugPrint('║   └─ ${_truncate(message, 30)} ║');
      }
    }
    debugPrint('╚══════════════════════════════════════╝');

    return report;
  }

  static Future<Map<String, String>> _checkConfiguredClient({
    required String envUrlKey,
    required String envKeyKey,
    required String label,
    required String testTable,
  }) async {
    final dbUrl = dotenv.env[envUrlKey] ?? '';
    final dbKey = dotenv.env[envKeyKey] ?? '';

    if (dbUrl.isEmpty || dbKey.isEmpty) {
      return {
        'status': 'error',
        'message': 'Missing $envUrlKey or $envKeyKey in .env',
      };
    }

    final client = SupabaseClient(dbUrl, dbKey);
    return _checkTable(
      label: label,
      client: client,
      tableName: testTable,
    );
  }

  static Future<Map<String, String>> _checkTable({
    required String label,
    required SupabaseClient client,
    required String tableName,
  }) async {
    try {
      await client.from(tableName).select('*').limit(1);
      return {'status': 'ok', 'message': '$label accessible'};
    } catch (e) {
      return {'status': 'error', 'message': '$label: ${_truncate(e.toString(), 100)}'};
    }
  }

  static String _truncate(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    return value.substring(0, maxLength);
  }
}
