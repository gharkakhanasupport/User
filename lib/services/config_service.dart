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
  final _minVersionSubject = BehaviorSubject<int>.seeded(0);
  final _latestVersionSubject = BehaviorSubject<int>.seeded(0);
  
  Stream<bool> get otpEnabledStream => _otpEnabledSubject.stream;
  bool get isOtpEnabled => _otpEnabledSubject.value;
  
  int get minVersion => _minVersionSubject.value;
  int get latestVersion => _latestVersionSubject.value;

  /// Initialize the service by fetching the initial config and setting up a realtime listener.
  Future<void> initialize() async {
    try {
      // 1. Fetch initial value
      final data = await _supabase
          .from('app_settings')
          .select('otp_verification_enabled, min_app_version, latest_app_version')
          .limit(1)
          .maybeSingle();
      
      if (data != null) {
        _otpEnabledSubject.add(data['otp_verification_enabled'] == true);
        _minVersionSubject.add(data['min_app_version'] ?? 0);
        _latestVersionSubject.add(data['latest_app_version'] ?? 0);
      }

      // 2. Set up realtime listener for live updates
      _supabase
          .from('app_settings')
          .stream(primaryKey: ['id'])
          .listen((data) {
            if (data.isNotEmpty) {
              final first = data.first;
              final otpVal = first['otp_verification_enabled'] == true;
              if (_otpEnabledSubject.value != otpVal) {
                _otpEnabledSubject.add(otpVal);
                debugPrint('🔔 ConfigService: OTP Verification changed to $otpVal');
              }
              
              final minV = first['min_app_version'] ?? 0;
              if (_minVersionSubject.value != minV) {
                _minVersionSubject.add(minV);
              }
              
              final latestV = first['latest_app_version'] ?? 0;
              if (_latestVersionSubject.value != latestV) {
                _latestVersionSubject.add(latestV);
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
