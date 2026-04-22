import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rxdart/rxdart.dart';

class ConfigService {
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal();

  final _supabase = Supabase.instance.client;
  
  // BehaviorSubject to hold the latest config value
  final _otpEnabledSubject = BehaviorSubject<bool>.seeded(true);
  
  Stream<bool> get otpEnabledStream => _otpEnabledSubject.stream;
  bool get isOtpEnabled => _otpEnabledSubject.value;

  /// Initialize the service by fetching the initial config and setting up a realtime listener.
  Future<void> initialize() async {
    try {
      // 1. Fetch initial value
      final data = await _supabase
          .from('app_settings')
          .select('otp_verification_enabled')
          .limit(1)
          .maybeSingle();
      
      if (data != null) {
        _otpEnabledSubject.add(data['otp_verification_enabled'] == true);
      }

      // 2. Set up realtime listener for live updates
      _supabase
          .from('app_settings')
          .stream(primaryKey: ['id'])
          .listen((data) {
            if (data.isNotEmpty) {
              final val = data.first['otp_verification_enabled'] == true;
              if (_otpEnabledSubject.value != val) {
                _otpEnabledSubject.add(val);
                debugPrint('🔔 ConfigService: OTP Verification changed to $val');
              }
            }
          });
    } catch (e) {
      debugPrint('❌ ConfigService: Initialization error: $e');
      // If table doesn't exist yet, we default to true to not break the app
      _otpEnabledSubject.add(true);
    }
  }
}
