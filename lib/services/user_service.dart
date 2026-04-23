import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserService {
  final _supabase = Supabase.instance.client;

  /// Update user profile in database
  Future<bool> updateProfile({
    required String id,
    String? name,
    String? firstName,
    String? lastName,
    String? phone,
    String? email,
    String? avatarUrl,
    String? address,
  }) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      
      String? fName = firstName;
      String? lName = lastName;
      
      if (name != null && (fName == null || lName == null)) {
        final parts = name.trim().split(RegExp(r'\s+'));
        fName ??= parts.first;
        lName ??= parts.length > 1 ? parts.sublist(1).join(' ') : '';
      }

      final data = <String, dynamic>{
        'id': id,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (fName != null) data['first_name'] = fName;
      if (lName != null) data['last_name'] = lName;
      if (name != null) data['name'] = name;
      if (phone != null) data['phone'] = phone;
      
      final resolvedEmail = email ?? currentUser?.email;
      if (resolvedEmail != null) data['email'] = resolvedEmail;
      
      if (avatarUrl != null) data['avatar_url'] = avatarUrl;
      if (address != null) data['address'] = address;

      // Update timestamps if fields are provided for cooldown enforcement
      if ((fName ?? lName ?? name) != null) {
        data['last_name_change'] = DateTime.now().toIso8601String();
      }
      if (phone != null) {
        data['last_phone_change'] = DateTime.now().toIso8601String();
      }
      if (avatarUrl != null) {
        data['last_photo_change'] = DateTime.now().toIso8601String();
      }
      debugPrint('UserService.updateProfile: upserting $data');
      await _supabase.from('users').upsert(data, onConflict: 'id');
      debugPrint('UserService.updateProfile: success');
      return true;
    } on PostgrestException catch (e) {
      debugPrint('UserService.updateProfile PostgrestException:');
      debugPrint('  code: ${e.code}, message: ${e.message}');
      debugPrint('  hint: ${e.hint}, details: ${e.details}');
      return false;
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
