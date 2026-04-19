
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  await dotenv.load();
  final kitchenUrl = dotenv.env['KITCHEN_DB_URL'];
  final kitchenServiceKey = dotenv.env['KITCHEN_DB_SERVICE_KEY'];
  
  if (kitchenUrl == null || kitchenServiceKey == null) {
    debugPrint('Missing Kitchen DB configuration');
    return;
  }

  final client = SupabaseClient(kitchenUrl, kitchenServiceKey);
  
  try {
    // Try to fetch one row from kitchens to see columns
    final res = await client.from('kitchens').select().limit(1);
    debugPrint('Kitchen DB kitchens sample: $res');
    
    if (res.isNotEmpty) {
      final keys = (res.first as Map).keys.toList();
      debugPrint('Kitchen DB kitchens columns: $keys');
    }
  } catch (e) {
    debugPrint('Error accessing Kitchen DB kitchens: $e');
  }
}
