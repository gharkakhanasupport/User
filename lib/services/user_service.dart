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
      final currentUser = _supabase.auth.currentUser;
      final data = <String, dynamic>{
        'id': id,
        if (name != null) 'name': name,
        if (phone != null) 'phone': phone,
        if (email != null || currentUser?.email != null)
          'email': email ?? currentUser?.email,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        if (address != null) 'address': address,
        'updated_at': DateTime.now().toIso8601String(),
      };
      debugPrint('UserService.updateProfile: upserting $data');
      await _supabase.from('users').upsert(data, onConflict: 'id');
      debugPrint('UserService.updateProfile: success');
      return true;
    } catch (e, stackTrace) {
      debugPrint('UserService.updateProfile error: $e');
      debugPrint('UserService.updateProfile stack: $stackTrace');
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
