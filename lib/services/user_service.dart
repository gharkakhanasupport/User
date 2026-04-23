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
    String? profileImageUrl,
    String? preferredLanguage,
    String? defaultAddressId,
    String? primaryAddress,
  }) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      
      final data = <String, dynamic>{
        'id': id,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (name != null) data['name'] = name;
      if (phone != null) data['phone'] = phone;
      if (preferredLanguage != null) data['preferred_language'] = preferredLanguage;
      if (defaultAddressId != null) data['default_address_id'] = defaultAddressId;
      if (primaryAddress != null) data['primary_address'] = primaryAddress;
      
      final resolvedEmail = email ?? currentUser?.email;
      if (resolvedEmail != null) data['email'] = resolvedEmail;
      
      
      if (profileImageUrl != null) data['profile_image_url'] = profileImageUrl;

      // Update timestamps if fields are provided for cooldown enforcement
      if (name != null) {
        data['last_name_change'] = DateTime.now().toIso8601String();
      }
      if (phone != null) {
        data['last_phone_change'] = DateTime.now().toIso8601String();
      }
      if (profileImageUrl != null) {
        data['last_photo_change'] = DateTime.now().toIso8601String();
      }

      // Sync with Supabase Auth Metadata for immediate UI consistency
      final metadata = <String, dynamic>{};
      if (name != null) metadata['full_name'] = name;
      if (phone != null) metadata['phone'] = phone;
      if (profileImageUrl != null) metadata['avatar_url'] = profileImageUrl;

      if (metadata.isNotEmpty) {
        await _supabase.auth.updateUser(UserAttributes(data: metadata));
      }

      debugPrint('UserService.updateProfile: upserting to users table: $data');
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
