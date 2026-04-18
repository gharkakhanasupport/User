import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import 'category_page.dart';
import 'wallet_screen.dart';
import 'premium_screen.dart';

class CategoryTransitionScreen extends StatefulWidget {
  final String categoryName;

  const CategoryTransitionScreen({super.key, required this.categoryName});

  // Track which transitions have been shown in this session
  static final Set<String> _shownTransitions = {};

  /// Check if the transition for this category should be shown (once per session)
  static bool shouldAnimate(String category) {
    const sessionCategories = ['Premium', 'Wallet', 'Lunch', 'Breakfast', 'Dinner'];
    if (!sessionCategories.contains(category)) return true;
    return !_shownTransitions.contains(category);
  }

  /// Get the target screen for a category without showing the transition
  static Widget getTargetScreen(String category) {
    if (category == 'Wallet') return const WalletScreen();
    if (category == 'Premium') return const PremiumScreen();
    return CategoryPage(categoryName: category);
  }

  /// Mark a category as shown (called automatically by the transition screen)
  static void markAsShown(String category) {
    _shownTransitions.add(category);
  }

  @override
  State<CategoryTransitionScreen> createState() => _CategoryTransitionScreenState();
}

class _CategoryTransitionScreenState extends State<CategoryTransitionScreen> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    final bool alreadyShown = !CategoryTransitionScreen.shouldAnimate(widget.categoryName);
    
    _mainController = AnimationController(
        duration: Duration(milliseconds: alreadyShown ? 0 : 2000), vsync: this)..forward();
    
    _fadeAnimation = Tween<double>(begin: alreadyShown ? 1.0 : 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(begin: alreadyShown ? Offset.zero : const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.easeOutCubic),
    );

    // Navigate after 3 seconds (or immediately if already shown)
    Future.delayed(Duration(milliseconds: alreadyShown ? 0 : 3000), () {
      if (!mounted) return;
      
      if (!alreadyShown) {
        CategoryTransitionScreen.markAsShown(widget.categoryName);
      }

      if (widget.categoryName == 'Wallet') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const WalletScreen()),
        );
      } else if (widget.categoryName == 'Premium') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PremiumScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => CategoryPage(categoryName: widget.categoryName),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: _getBackgroundGradient(),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Atmospheric Background Elements
            if (widget.categoryName == 'Breakfast') _buildSunriseAnimation(),
            if (widget.categoryName == 'Dinner') _buildStarryNightAnimation(),
             if (widget.categoryName == 'Lunch') _buildDayAnimation(),
             if (widget.categoryName == 'Wallet') _buildWalletAnimation(),
             if (widget.categoryName == 'Premium') _buildPremiumAnimation(),

            // Text Content
            FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _getIcon(),
                      size: 80,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      widget.categoryName,
                      style: GoogleFonts.poppins(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                        shadows: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ]
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getTagline(),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
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

  LinearGradient _getBackgroundGradient() {
    switch (widget.categoryName) {
      case 'Breakfast':
        return const LinearGradient(
           begin: Alignment.topCenter,
           end: Alignment.bottomCenter,
           colors: [Color(0xFFFFB74D), Color(0xFFFFCC80)], 
        );
      case 'Dinner':
         return const LinearGradient(
           begin: Alignment.topCenter,
           end: Alignment.bottomCenter,
           colors: [Color(0xFF1A237E), Color(0xFF0D47A1)], 
        );
      case 'Wallet':
        return AppColors.bgGradientWallet;
      case 'Premium':
        return AppColors.bgGradientPremium;
      default: // Lunch
         return const LinearGradient(
           begin: Alignment.topCenter,
           end: Alignment.bottomCenter,
           colors: [Color(0xFF42A5F5), Color(0xFF90CAF9)], 
        );
    }
  }

  IconData _getIcon() {
    switch (widget.categoryName) {
      case 'Breakfast': return Icons.wb_twilight;
      case 'Dinner': return Icons.nights_stay;
      case 'Wallet': return Icons.account_balance_wallet;
      case 'Premium': return Icons.verified;
      default: return Icons.wb_sunny;
    }
  }

  String _getTagline() {
    switch (widget.categoryName) {
      case 'Breakfast': return 'Good Morning!';
      case 'Dinner': return 'Sweet Dreams & Tasty Food';
      case 'Wallet': return 'Managing your Finances...';
      case 'Premium': return 'Experience Luxury Dining';
      default: return 'Enjoy your Meal!';
    }
  }

  Widget _buildSunriseAnimation() {
    return Positioned(
      bottom: 0,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 100, end: -50),
        duration: const Duration(seconds: 3),
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, value),
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Colors.yellow.withValues(alpha: 0.6), Colors.transparent],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDayAnimation() {
       return Positioned(
        top: 100,
        right: -50,
        child: Container(
          width: 200,
          height: 200,
           decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
      );
  }

  Widget _buildStarryNightAnimation() {
    return Stack(
      children: List.generate(20, (index) {
        final random = math.Random();
        return Positioned(
          left: random.nextDouble() * 400,
          top: random.nextDouble() * 400,
          child: _TwinklingStar(),
        );
      }),
    );
  }

  Widget _buildWalletAnimation() {
    return Stack(
      children: List.generate(15, (index) {
        final random = math.Random();
        return Positioned(
          left: random.nextDouble() * 350,
          top: -50,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: -50, end: 800),
            duration: Duration(milliseconds: 1500 + random.nextInt(1500)),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, value),
                child: Icon(
                  Icons.currency_rupee,
                  color: Colors.green[800]!.withValues(alpha: 0.4),
                  size: 20 + random.nextDouble() * 20,
                ),
              );
            },
          ),
        );
      }),
    );
  }

  Widget _buildPremiumAnimation() {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 2 * math.pi),
        duration: const Duration(seconds: 4),
        builder: (context, value, child) {
          return Transform.rotate(
            angle: value,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                gradient: SweepGradient(
                  colors: [
                    Colors.transparent, 
                    Colors.white.withValues(alpha: 0.2), 
                    Colors.transparent
                  ],
                  stops: const [0.0, 0.5, 1.0],
                  transform: GradientRotation(value),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TwinklingStar extends StatefulWidget {
  @override
  State<_TwinklingStar> createState() => _TwinklingStarState();
}

class _TwinklingStarState extends State<_TwinklingStar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 1000 + math.Random().nextInt(1000)),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: const Icon(Icons.star, color: Colors.white, size: 8),
    );
  }
}
