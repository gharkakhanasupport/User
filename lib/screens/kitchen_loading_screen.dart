import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'kitchen_detail_screen.dart';

class KitchenLoadingScreen extends StatefulWidget {
  final String kitchenName;
  final String kitchenSubtitle;
  final String rating;
  final String ratingCount;
  final String imageUrl;
  final String tag;
  final String time;

  const KitchenLoadingScreen({
    super.key,
    required this.kitchenName,
    required this.kitchenSubtitle,
    required this.rating,
    required this.ratingCount,
    required this.imageUrl,
    required this.tag,
    required this.time,
  });

  @override
  State<KitchenLoadingScreen> createState() => _KitchenLoadingScreenState();
}

class _KitchenLoadingScreenState extends State<KitchenLoadingScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late AnimationController _slideController;
  late AnimationController _shimmerController;
  
  late Animation<double> _pulseAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    
    // Pulse Animation for rings
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // Rotation for the cooker lid
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    
    // Slide up animation for content
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    
    _slideAnimation = Tween<double>(begin: 50, end: 0).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack),
    );
    
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeIn),
    );
    
    // Shimmer for text
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    
    _shimmerAnimation = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.linear),
    );

    // Navigate after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => KitchenDetailScreen(
              kitchenName: widget.kitchenName,
              kitchenSubtitle: widget.kitchenSubtitle,
              rating: widget.rating,
              ratingCount: widget.ratingCount,
              imageUrl: widget.imageUrl,
              tag: widget.tag,
              time: widget.time,
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.1),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
                  child: child,
                ),
              );
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    _slideController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF0FDF4), // Light mint
              Color(0xFFDCFCE7), // Soft green
              Color(0xFFBBF7D0), // Lighter green bottom
            ],
          ),
        ),
        child: Stack(
          children: [
            // Animated Background Particles
            ...List.generate(8, (index) => _buildFloatingParticle(index)),
            
            // Main Content
            Center(
              child: AnimatedBuilder(
                animation: _slideController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _slideAnimation.value),
                    child: Opacity(
                      opacity: _fadeAnimation.value,
                      child: child,
                    ),
                  );
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated Cooking Icon
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer pulse rings
                          ...List.generate(3, (index) => _buildPulseRing(index)),
                          
                          // Main Icon Container
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF16A34A).withOpacity(0.3),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                ),
                                const BoxShadow(
                                  color: Colors.white,
                                  blurRadius: 20,
                                  spreadRadius: -5,
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Cooker Base
                                const Icon(
                                  Icons.soup_kitchen,
                                  size: 56,
                                  color: Color(0xFF16A34A),
                                ),
                                // Animated Steam
                                Positioned(
                                  top: 20,
                                  child: AnimatedBuilder(
                                    animation: _rotateController,
                                    builder: (context, _) {
                                      return Transform.translate(
                                        offset: Offset(0, -_rotateController.value * 8),
                                        child: Opacity(
                                          opacity: 1 - _rotateController.value * 0.5,
                                          child: Icon(
                                            Icons.air,
                                            size: 20,
                                            color: Colors.grey.withOpacity(0.5),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 48),
                    
                    // Shimmer Text
                    AnimatedBuilder(
                      animation: _shimmerController,
                      builder: (context, _) {
                        return ShaderMask(
                          shaderCallback: (bounds) {
                            return LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: const [
                                Color(0xFF16A34A),
                                Color(0xFF22C55E),
                                Color(0xFFC2941B), // Golden shimmer
                                Color(0xFF22C55E),
                                Color(0xFF16A34A),
                              ],
                              stops: [
                                0.0,
                                _shimmerAnimation.value - 0.3,
                                _shimmerAnimation.value,
                                _shimmerAnimation.value + 0.3,
                                1.0,
                              ].map((s) => s.clamp(0.0, 1.0)).toList(),
                            ).createShader(bounds);
                          },
                          child: Text(
                            'Entering Kitchen',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Kitchen Name
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: const Color(0xFF16A34A).withOpacity(0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.restaurant, size: 18, color: Color(0xFFC2941B)),
                          const SizedBox(width: 8),
                          Text(
                            widget.kitchenName,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Loading Dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (index) => _buildLoadingDot(index)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPulseRing(int index) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final delay = index * 0.2;
        final animValue = ((_pulseController.value + delay) % 1.0);
        final scale = 0.8 + animValue * 0.8;
        final opacity = (1 - animValue).clamp(0.0, 0.4);
        
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF16A34A).withOpacity(opacity),
                width: 2,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingDot(int index) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final delay = index * 0.15;
        final animValue = ((_pulseController.value + delay) % 1.0);
        final scale = 0.5 + math.sin(animValue * math.pi) * 0.5;
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: const Color(0xFF16A34A).withOpacity(0.3 + scale * 0.7),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildFloatingParticle(int index) {
    final random = math.Random(index);
    final startX = random.nextDouble() * MediaQuery.of(context).size.width;
    final startY = random.nextDouble() * MediaQuery.of(context).size.height;
    final size = 4.0 + random.nextDouble() * 8;
    
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final offset = math.sin(_pulseController.value * math.pi * 2 + index) * 20;
        return Positioned(
          left: startX,
          top: startY + offset,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
