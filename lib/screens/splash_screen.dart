import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import '../services/fcm_service.dart';
import '../theme/app_colors.dart';
import 'home_screen.dart';
import 'login_screen.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
    setState(() => _loadingText = 'NAVIGATING...');
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _initializeServices() async {
    try {
      setState(() => _loadingText = 'CONNECTING...');
      
      // Initialize Firebase first with timeout
      try {
        await Firebase.initializeApp().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint('⚠️ Firebase init timeout');
            throw Exception('Firebase timeout');
          },
        );
        debugPrint('✅ Firebase initialized');
      } catch (e) {
        debugPrint("Firebase Error: $e");
      }

      // Initialize Supabase with timeout
      try {
        await Supabase.initialize(
          url: dotenv.env['SUPABASE_URL'] ?? '',
          anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
          authOptions: const FlutterAuthClientOptions(
            authFlowType: AuthFlowType.pkce,
          ),
          debug: false, // Disable debug mode for release
        ).timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint('⚠️ Supabase init timeout');
            throw Exception('Supabase timeout');
          },
        );
        debugPrint('✅ Supabase initialized');
      } catch (e) {
        debugPrint("Supabase init error: $e");
      }

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

  void _checkAuthAndNavigate() {
    debugPrint('🔄 Checking auth and navigating...');
    
    try {
      final session = Supabase.instance.client.auth.currentSession;
      debugPrint('📱 Session: ${session != null ? "exists" : "null"}');
      
      if (session != null) {
        // User is logged in, go to Home
        debugPrint('➡️ Navigating to HomeScreen');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
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
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
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
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
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
                    color: Colors.white.withOpacity(0.9),
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
                      color: Colors.black.withOpacity(0.1),
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
                      color: Colors.white.withOpacity(0.6),
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
