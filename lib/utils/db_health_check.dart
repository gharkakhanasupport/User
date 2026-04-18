import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cross-DB health check utility.
/// Pings each database (User, Kitchen, Admin) and verifies essential tables/RPCs.
class DbHealthCheck {
  /// Run all checks and return a report map.
  /// Keys: 'user_db', 'kitchen_db', 'admin_db', 'split_orders_table', 'rpc_callable'
  /// Values: { 'status': 'ok'|'error', 'message': '...' }
  static Future<Map<String, Map<String, String>>> runFullCheck() async {
    final report = <String, Map<String, String>>{};

    // 1. User DB (primary — already initialized via Supabase.instance.client)
    report['user_db'] = await _checkDb(
      label: 'User DB',
      client: Supabase.instance.client,
      testTable: 'users',
    );

    // 2. Kitchen DB
    try {
      final kitchenUrl = dotenv.env['KITCHEN_DB_URL'] ?? dotenv.env['KITCHEN_SUPABASE_URL'] ?? '';
      final kitchenKey = dotenv.env['KITCHEN_DB_ANON_KEY'] ?? dotenv.env['KITCHEN_SUPABASE_ANON_KEY'] ?? '';

      if (kitchenUrl.isEmpty || kitchenKey.isEmpty) {
        report['kitchen_db'] = {'status': 'error', 'message': 'Missing KITCHEN_DB_URL or KITCHEN_DB_ANON_KEY in .env'};
      } else {
        final kitchenClient = SupabaseClient(kitchenUrl, kitchenKey);
        report['kitchen_db'] = await _checkDb(
          label: 'Kitchen DB',
          client: kitchenClient,
          testTable: 'orders',
        );
      }
    } catch (e) {
      report['kitchen_db'] = {'status': 'error', 'message': e.toString()};
    }

    // 3. Admin DB
    try {
      final adminUrl = dotenv.env['ADMIN_DB_URL'] ?? '';
      final adminKey = dotenv.env['ADMIN_DB_ANON_KEY'] ?? '';

      if (adminUrl.isEmpty || adminKey.isEmpty) {
        report['admin_db'] = {'status': 'error', 'message': 'Missing ADMIN_DB_URL or ADMIN_DB_ANON_KEY in .env'};
      } else {
        final adminClient = SupabaseClient(adminUrl, adminKey);
        report['admin_db'] = await _checkDb(
          label: 'Admin DB',
          client: adminClient,
          testTable: 'users', // Admin DB likely has a users table
        );
      }
    } catch (e) {
      report['admin_db'] = {'status': 'error', 'message': e.toString()};
    }

    // 4. Check split_orders table exists
    report['split_orders_table'] = await _checkTable(
      client: Supabase.instance.client,
      tableName: 'split_orders',
    );

    // 5. Check menu_items table accessible
    report['menu_items_table'] = await _checkTable(
      client: Supabase.instance.client,
      tableName: 'menu_items',
    );

    // 6. Check place_split_order RPC is callable (dry call — will fail safely)
    report['rpc_callable'] = await _checkRpc(
      client: Supabase.instance.client,
      rpcName: 'place_split_order',
    );

    // Print summary
    debugPrint('╔══════════════════════════════════════╗');
    debugPrint('║      GKK DB HEALTH CHECK REPORT      ║');
    debugPrint('╠══════════════════════════════════════╣');
    for (final entry in report.entries) {
      final status = entry.value['status'] == 'ok' ? '✅' : '❌';
      debugPrint('║ $status ${entry.key.padRight(25)} ${entry.value['status']?.toUpperCase().padRight(8)} ║');
      if (entry.value['status'] != 'ok') {
        debugPrint('║   └─ ${entry.value['message']?.substring(0, (entry.value['message']?.length ?? 0).clamp(0, 30))} ║');
      }
    }
    debugPrint('╚══════════════════════════════════════╝');

    return report;
  }

  static Future<Map<String, String>> _checkDb({
    required String label,
    required SupabaseClient client,
    required String testTable,
  }) async {
    try {
      await client.from(testTable).select('id').limit(1);
      return {'status': 'ok', 'message': '$label connected'};
    } catch (e) {
      return {'status': 'error', 'message': '$label: ${e.toString().substring(0, e.toString().length.clamp(0, 100))}'};
    }
  }

  static Future<Map<String, String>> _checkTable({
    required SupabaseClient client,
    required String tableName,
  }) async {
    try {
      await client.from(tableName).select('id').limit(1);
      return {'status': 'ok', 'message': '$tableName exists and is accessible'};
    } catch (e) {
      return {'status': 'error', 'message': '$tableName: ${e.toString().substring(0, e.toString().length.clamp(0, 100))}'};
    }
  }

  static Future<Map<String, String>> _checkRpc({
    required SupabaseClient client,
    required String rpcName,
  }) async {
    try {
      // Attempt to call with empty data — should fail validation, but prove RPC exists
      await client.rpc(rpcName, params: {
        'p_user_id': '00000000-0000-0000-0000-000000000000',
        'p_delivery_address': {},
        'p_payment_method': 'test',
        'p_orders': [],
      });
      return {'status': 'ok', 'message': '$rpcName callable'};
    } catch (e) {
      final msg = e.toString();
      // If error is about empty array or data validation, the RPC exists
      if (msg.contains('cannot extract elements') ||
          msg.contains('permission denied') ||
          msg.contains('new row violates') ||
          msg.contains('null value')) {
        return {'status': 'ok', 'message': '$rpcName exists (validation error is expected)'};
      }
      return {'status': 'error', 'message': '$rpcName: ${msg.substring(0, msg.length.clamp(0, 100))}'};
    }
  }
}
