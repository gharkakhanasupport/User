import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../services/subscription_service.dart';
import 'manage_subscriptions_screen.dart';
import 'basket_screen.dart';
import '../widgets/cart_toast.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  final _subscriptionService = SubscriptionService();
  int _activeCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionCount();
  }

  Future<void> _loadSubscriptionCount() async {
    try {
      final active = await _subscriptionService.getActiveSubscriptions();
      if (mounted) {
        setState(() {
          _activeCount = active.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Sticky Header
                _buildHeader(context),
                
                // Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeroSection(),
                        // Active Subscriptions Quick Summary
                        if (!_isLoading && _activeCount > 0) _buildActiveSubsBanner(),
                        _buildBenefitsSection(),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          child: Divider(color: Color(0xFFF0F0F0)),
                        ),
                        _buildHowItWorksSection(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: CartToast(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BasketScreen(initialTabIndex: 0),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildStickyFooter(context),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              child: const Icon(Icons.arrow_back, color: Color(0xFF121712)),
            ),
          ),
          Text(
            'Kitchen Subscriptions',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF121712),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildActiveSubsBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ManageSubscriptionsScreen()),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF2DA9A5), const Color(0xFF2DA9A5).withValues(alpha: 0.8)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2DA9A5).withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.card_membership, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_activeCount Active Subscription${_activeCount > 1 ? 's' : ''}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Tap to manage your subscriptions',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF0F0F0)),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF8E1), Color(0xFFE8F5E9)],
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Image Area
            SizedBox(
              height: 192,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    'https://lh3.googleusercontent.com/aida-public/AB6AXuBMdDL8_lnPLmMKEHSH41xoMyilXg6WMqHz-alC2EbrBB26xmjoQpdxwf5T1SrhssqqxuQ7GT6RjthIXPLfv5bN9ZtjP58bjgBhYa7q5FW7be87KeUA125x-AjDzUREkN2F_ri3tcX0OAnmsVJX3vX63Z28wl7CFqDirxy52FquUtrfDeDZYgDe5t6N3W7PxoUe2XtzzE0Hr4-zpRpqWur9O8rkzWbvjbIzZlFKaXmK5yshEITVqNOT34CeBZrrd3Uqq4CVc-fP0f0j',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: const Color(0xFFF0FDF4),
                      child: const Icon(Icons.restaurant, size: 64, color: Color(0xFF16A34A)),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          const Color(0xFFFFFCF2).withValues(alpha: 0.9),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Text Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.walletSecondary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified, size: 16, color: AppColors.walletSecondary),
                        const SizedBox(width: 6),
                        Text(
                          'Kitchen Subscriptions',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.walletSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Subscribe to Your Favourite Kitchens',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                      letterSpacing: -0.5,
                      color: const Color(0xFF121712),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Get daily home-cooked meals delivered fresh from trusted kitchens. Choose weekly or monthly plans that fit your schedule.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      height: 1.5,
                      color: const Color(0xFF556955),
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

  Widget _buildBenefitsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Why Subscribe?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF121712),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildBenefitItem(
            icon: Icons.local_shipping,
            iconColor: AppColors.walletPrimary,
            title: 'Free Delivery on All Meals',
            description: 'Enjoy free delivery for every meal included in your subscription plan.',
          ),
          _buildBenefitItem(
            icon: Icons.soup_kitchen,
            iconColor: AppColors.walletSecondary,
            title: 'Weekly & Monthly Plans',
            description: 'Choose 7-day or 30-day meal plans based on your preference and budget.',
          ),
          _buildBenefitItem(
            icon: Icons.pause_circle_outline,
            iconColor: AppColors.walletPrimary,
            title: 'Skip or Pause Anytime',
            description: 'Flexibility to skip days or pause your subscription without losing value.',
          ),
          _buildBenefitItem(
            icon: Icons.menu_book,
            iconColor: AppColors.walletSecondary,
            title: 'Fresh Menu Updates',
            description: 'Kitchens update their subscription menus regularly with seasonal dishes.',
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF121712),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    height: 1.4,
                    color: const Color(0xFF556955),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorksSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How It Works',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF121712),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.walletBgLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Column(
              children: [
                _buildStep(
                  number: '1',
                  color: AppColors.walletPrimary,
                  title: 'Browse Kitchens',
                  description: 'Explore home kitchens near you. Look for the subscription badge on kitchens offering meal plans.',
                  isLast: false,
                ),
                _buildStep(
                  number: '2',
                  color: AppColors.walletSecondary,
                  title: 'Choose a Plan',
                  description: 'Select a Weekly (7-day) or Monthly (30-day) plan. Each kitchen sets their own pricing.',
                  isLast: false,
                ),
                _buildStep(
                  number: '3',
                  color: AppColors.walletPrimary,
                  title: 'Pay & Enjoy',
                  description: 'Complete payment via UPI or Card. Your subscription starts immediately with daily meal delivery!',
                  isLast: true,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      'Secure Payment via UPI & Cards',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep({
    required String number,
    required Color color,
    required String title,
    required String description,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  number,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: color.withValues(alpha: 0.2),
                    margin: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF121712),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      height: 1.5,
                      color: const Color(0xFF556955),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            offset: const Offset(0, -4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Primary CTA — Explore Kitchens
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context), // Go back to home to browse kitchens
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.walletPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
                shadowColor: AppColors.walletPrimary.withValues(alpha: 0.3),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.explore, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Explore Kitchens',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Secondary CTA — Manage Subscriptions
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ManageSubscriptionsScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.card_membership, size: 14, color: Color(0xFF2DA9A5)),
                  const SizedBox(width: 6),
                  Text(
                    'Manage My Subscriptions',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2DA9A5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
