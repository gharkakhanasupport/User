import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserService {
  final _supabase = Supabase.instance.client;

  /// Update user profile in database
  Future<bool> updateProfile({
    required String id,
    String? name,
    String? phone,
    String? email,
    String? avatarUrl,
    String? address,
  }) async {
    try {
      await _supabase.from('users').upsert({
        'id': id,
        if (name != null) 'name': name,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        if (address != null) 'address': address,
        'updated_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('UserService.updateProfile error: $e');
      return false;
    }
  }

  /// Get user data from database
  Future<Map<String, dynamic>?> getUserData(String id) async {
    try {
      return await _supabase
          .from('users')
          .select()
          .eq('id', id)
          .maybeSingle();
    } catch (e) {
      debugPrint('UserService.getUserData error: $e');
      return null;
    }
  }
}
