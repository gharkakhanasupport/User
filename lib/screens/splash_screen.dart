import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/fcm_service.dart';
import '../services/cart_service.dart';
import '../services/config_service.dart';
import '../services/in_app_update_service.dart';
import '../theme/app_colors.dart';
import 'main_layout.dart';
import 'login_screen.dart';
import 'phone_verification_screen.dart';

import 'package:permission_handler/permission_handler.dart';
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  double _targetProgress = 0.0;
  String _loadingText = 'STARTING UP...';

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _progressAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeOut),
    );

    _startAppInitialization();
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

      debugPrint('✅ Initialization complete');
    } catch (e) {
      debugPrint("Initialization part failed: $e");
    }

    if (mounted) {
      _requestPermissionsAndNavigate();
    }
  }

  void _forceNavigate() {
    _setProgress(1.0, 'NAVIGATING...');
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  /// Smoothly advance the progress bar to a target value (0.0 – 1.0)
  void _setProgress(double value, String text) {
    if (!mounted) return;
    final oldProgress = _targetProgress;
    _targetProgress = value;
    _progressAnimation = Tween<double>(begin: oldProgress, end: value).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeOut),
    );
    _progressController.forward(from: 0);
    setState(() => _loadingText = text);
  }

  Future<void> _initializeServices() async {
    try {
      _setProgress(0.15, 'CONNECTING...');

      // Initialize global config (feature flags)
      await ConfigService().initialize();
      debugPrint('✅ Config service initialized');
      _setProgress(0.40, 'LOADING CONFIG...');

      // Fire-and-forget: check for updates in background (non-blocking)
      InAppUpdateService.instance.checkForUpdate();

      // Initialize FCM in background — don't wait too long
      FCMService().initialize().timeout(
        const Duration(seconds: 3),
        onTimeout: () => debugPrint('⚠️ FCM init timeout - continuing anyway'),
      ).then((_) {
        debugPrint('✅ FCM Service initialized');
      }).catchError((e) {
        debugPrint("FCM Error: $e");
      });
      _setProgress(0.55, 'PREPARING KITCHEN...');

      // Initialize persistent cart
      try {
        await CartService.instance.init();
        debugPrint('✅ Cart service initialized');
      } catch (e) {
        debugPrint('⚠️ Cart init error: $e');
      }
      _setProgress(0.70, 'SETTING THE TABLE...');

      debugPrint('✅ Core services initialized');
    } catch (e) {
      debugPrint("Service Init Error: $e");
    }
  }

  Future<void> _requestPermissionsAndNavigate() async {
    if (!mounted) return;

    _setProgress(0.80, 'ALMOST READY...');
    
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
      _setProgress(0.90, 'CHECKING ACCOUNT...');
      _checkAuthAndNavigate();
    }
  }

  void _checkAuthAndNavigate() async {
    debugPrint('🔄 Checking auth and navigating...');
    _setProgress(0.95, 'WELCOME BACK...');
    
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
    _progressController.dispose();
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
                        animation: _progressAnimation,
                        builder: (context, child) {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: 200 * _progressAnimation.value,
                              height: 6,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Colors.white, Color(0xFFFFD54F)],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    blurRadius: 6,
                                  ),
                                ],
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
