import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/fcm_service.dart';
import '../services/cart_service.dart';
import '../services/config_service.dart';
import '../theme/app_colors.dart';
import 'main_layout.dart';
import 'login_screen.dart';
import 'phone_verification_screen.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  String _loadingText = 'LOADING COMFORT...';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        duration: const Duration(seconds: 2), vsync: this)..repeat(reverse: true);
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);

    _startAppInitialization();
  }

  Future<void> _checkForUpdate() async {
    if (!Platform.isAndroid) return;
    
    try {
      // 1. Manual check against Supabase (Reliable fallback)
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
      
      final minVersion = ConfigService().minVersion;
      final latestVersion = ConfigService().latestVersion;

      debugPrint('📦 App Version: ${packageInfo.version}+${packageInfo.buildNumber}');
      debugPrint('📦 Remote Config: min=$minVersion, latest=$latestVersion');

      if (currentBuild < minVersion && minVersion > 0) {
        debugPrint('⛔ Critical update required!');
        _showUpdateDialog(isForced: true);
        return;
      }

      // 2. Standard In-App Update (Automated flow)
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        if (info.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
        } else if (info.flexibleUpdateAllowed) {
          await InAppUpdate.startFlexibleUpdate();
          await InAppUpdate.completeFlexibleUpdate();
        }
      } else if (currentBuild < latestVersion && latestVersion > 0) {
        // Fallback: If Play Store says no update, but our DB says there is one
        debugPrint('💡 Manual update recommended');
        _showUpdateDialog(isForced: false);
      }
    } catch (e) {
      debugPrint('Update check failed: $e');
    }
  }

  void _showUpdateDialog({required bool isForced}) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: !isForced,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isForced ? 'Update Required 🚀' : 'New Update Available! ✨',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        content: Text(isForced 
          ? 'A critical update is required to continue using the app. Please update now for the best experience.'
          : 'A new version of Ghar Ka Khana is available with new features and improvements.'),
        actions: [
          if (!isForced)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later'),
            ),
          ElevatedButton(
            onPressed: () async {
              try {
                // Try In-App Update first
                final result = await InAppUpdate.performImmediateUpdate();
                if (result == AppUpdateResult.success) return;
                
                // Fallback to Play Store URL if In-App Update fails or isn't available
                final url = Uri.parse('https://play.google.com/store/apps/details?id=com.gharkakhana.user');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              } catch (e) {
                debugPrint('Update attempt failed: $e');
                // Last resort fallback
                final url = Uri.parse('https://play.google.com/store/apps/details?id=com.gharkakhana.user');
                launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }

  Future<void> _startAppInitialization() async {
    debugPrint('🚀 Starting app initialization...');
    
    // Set up a safety timeout - navigate after 10 seconds no matter what
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _loadingText != 'NAVIGATING...') {
        debugPrint('⏰ Safety timeout reached - forcing navigation');
        _forceNavigate();
      }
    });
    
    try {
      final minSplashTime = Future.delayed(const Duration(seconds: 3));
      final initTask = _initializeServices().timeout(
        const Duration(seconds: 8),
        onTimeout: () => debugPrint('⚠️ Init services timeout'),
      );

      // Wait for both timer and initialization
      await Future.wait([minSplashTime, initTask]);
      
      // 3. Check for updates (Now that ConfigService is ready)
      await _checkForUpdate();
      
      debugPrint('✅ Initialization complete');
    } catch (e) {
      debugPrint("Initialization part failed: $e");
    }

    if (mounted) {
      _requestPermissionsAndNavigate();
    }
  }

  void _forceNavigate() {
    setState(() => _loadingText = 'NAVIGATING...');
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _initializeServices() async {
    try {
      setState(() => _loadingText = 'CONNECTING...');
      
      // Supabase and Firebase are already initialized in main.dart
      // No need to re-initialize here.

      // Initialize global config (feature flags)
      await ConfigService().initialize();
      debugPrint('✅ Config service initialized');

      // Initialize FCM in background - don't wait for it
      // This prevents the app from getting stuck if FCM has issues
      FCMService().initialize().timeout(
        const Duration(seconds: 3),
        onTimeout: () => debugPrint('⚠️ FCM init timeout - continuing anyway'),
      ).then((_) {
        debugPrint('✅ FCM Service initialized');
      }).catchError((e) {
        debugPrint("FCM Error: $e");
      });

      // Initialize persistent cart
      try {
        await CartService.instance.init();
        debugPrint('✅ Cart service initialized');
      } catch (e) {
        debugPrint('⚠️ Cart init error: $e');
      }
      
      debugPrint('✅ Core services initialized');
    } catch (e) {
      debugPrint("Service Init Error: $e");
    }
  }

  Future<void> _requestPermissionsAndNavigate() async {
    if (!mounted) return;
    
    setState(() => _loadingText = 'ALMOST READY...');
    
    // Request permissions with timeout - don't block on this
    try {
      await [
        Permission.notification,
        Permission.location,
      ].request().timeout(const Duration(seconds: 3));
      debugPrint('✅ Permissions requested');
    } catch (e) {
      debugPrint("Permission request error/timeout: $e");
    }
    
    // Always navigate regardless of permission result
    if (mounted) {
      _checkAuthAndNavigate();
    }
  }

  void _checkAuthAndNavigate() async {
    debugPrint('🔄 Checking auth and navigating...');
    
    try {
      final session = Supabase.instance.client.auth.currentSession;
      debugPrint('📱 Session: ${session != null ? "exists" : "null"}');
      
      if (session != null) {
        // User is logged in — check if phone is verified
        try {
          final userId = Supabase.instance.client.auth.currentUser?.id;
          if (userId != null) {
            final userData = await Supabase.instance.client
                .from('users')
                .select('phone_verified')
                .eq('id', userId)
                .maybeSingle();

            final phoneVerified = userData?['phone_verified'] == true;
            final isOtpEnabled = ConfigService().isOtpEnabled;

            if (mounted) {
              if (phoneVerified || !isOtpEnabled) {
                debugPrint('➡️ Navigating to MainLayout (verified: $phoneVerified, otpEnabled: $isOtpEnabled)');
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const MainLayout()),
                );
              } else {
                debugPrint('➡️ Navigating to PhoneVerificationScreen');
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const PhoneVerificationScreen()),
                );
              }
            }
          } else {
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const MainLayout()),
              );
            }
          }
        } catch (e) {
          debugPrint('⚠️ Phone verification check failed: $e - going to Main');
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const MainLayout()),
            );
          }
        }
      } else {
        // User is not logged in, go to Login
        debugPrint('➡️ Navigating to LoginScreen');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } catch (e) {
      debugPrint('❌ Auth check error: $e - navigating to Login');
      // If anything fails, go to Login
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.splashGradient,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background Pattern (Placeholder)
            Positioned.fill(
              child: Opacity(
                opacity: 0.1,
                child: Image.network(
                  'https://www.transparenttextures.com/patterns/cubes.png',
                  repeat: ImageRepeat.repeat,
                  errorBuilder: (context, error, stackTrace) => const SizedBox(),
                ),
              ),
            ),
            
            // Main Content
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo Container
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 32,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.soup_kitchen,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                // Title
                Text(
                  'Ghar Ka Khana',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 32,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                // Subtitle
                Text(
                  'Home-style food, delivered with love',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            
            // Loading Indicator
            Positioned(
              bottom: 48,
              child: Column(
                children: [
                  Container(
                    width: 200,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: AnimatedBuilder(
                        animation: _animation,
                        builder: (context, child) {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: 200 * _animation.value, // Simple linear progress simulation
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                    Text(
                      _loadingText,
                      style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withValues(alpha: 0.6),
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
