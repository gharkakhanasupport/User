import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        duration: const Duration(seconds: 2), vsync: this)..repeat(reverse: true);
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);

    // Check auth state and navigate
    Future.delayed(const Duration(seconds: 3), () {
      _checkAuthAndNavigate();
    });
  }

  void _checkAuthAndNavigate() {
    final session = Supabase.instance.client.auth.currentSession;
    
    if (session != null) {
      // User is logged in, go to Home
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      // User is not logged in, go to Login
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
                    'LOADING COMFORT...',
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
