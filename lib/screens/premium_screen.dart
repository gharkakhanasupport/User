import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import 'manage_subscriptions_screen.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Sticky Header
            _buildHeader(context),
            
            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 100), // Space for sticky footer
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroSection(),
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
            'Ghar Ka Khana Premium',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF121712),
            ),
          ),
          const SizedBox(width: 48), // Spacer to balance back button
        ],
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
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          const Color(0xFFFFFCF2).withOpacity(0.9),
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
                      color: Colors.white.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.walletSecondary.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified, size: 16, color: AppColors.walletSecondary),
                        const SizedBox(width: 6),
                        Text(
                          'Premium Member',
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
                    'Experience Ghar Ka Khana Premium',
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
                    'Your daily dose of comfort, delivered fresh from trusted home kitchens. Unlock authentic flavors effortlessly.',
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
              'What You Get with Premium',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF121712),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildBenefitItem(
            icon: Icons.monetization_on,
            iconColor: AppColors.walletPrimary,
            title: 'Daily Token Credits',
            description: 'Tokens credited every day automatically, no hassle of recharging.',
          ),
          _buildBenefitItem(
            icon: Icons.soup_kitchen,
            iconColor: AppColors.walletSecondary,
            title: 'Exclusive Kitchen Access',
            description: 'Unlock special home kitchens & unique regional menus.',
          ),
          _buildBenefitItem(
            icon: Icons.edit_calendar,
            iconColor: AppColors.walletPrimary,
            title: 'Flexible Meal Adjustments',
            description: 'Easily pause or adjust your daily meals. Unused tokens roll over.',
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
              color: iconColor.withOpacity(0.1),
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
                  title: 'Choose Your Kitchen',
                  description: 'Browse and select a premium home kitchen. Pricing varies based on the kitchen\'s unique menu.',
                  isLast: false,
                ),
                _buildStep(
                  number: '2',
                  color: AppColors.walletSecondary,
                  title: 'Subscribe & Get Tokens',
                  description: 'Your subscription converts into daily tokens. These tokens are your currency for daily meals.',
                  isLast: false,
                ),
                _buildStep(
                  number: '3',
                  color: AppColors.walletPrimary,
                  title: 'Order Seamlessly',
                  description: 'Use tokens to order daily. Skip days or switch meals easily without losing value.',
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
                  border: Border.all(color: color.withOpacity(0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
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
                    color: color.withOpacity(0.2),
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
            color: Colors.black.withOpacity(0.03),
            offset: const Offset(0, -4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.walletPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
                shadowColor: AppColors.walletPrimary.withOpacity(0.3),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Subscribe Now',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
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
                border: Border.all(color: Colors.grey.shade200, style: BorderStyle.solid),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.code, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    'Unlocked (dev mode)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
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
