import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ManageSubscriptionsScreen extends StatelessWidget {
  final bool hideAppBar;
  const ManageSubscriptionsScreen({super.key, this.hideAppBar = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F8),
      appBar: hideAppBar
          ? null
          : AppBar(
              backgroundColor: const Color(0xFFF6F8F8).withValues(alpha: 0.95),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'My Subscriptions',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              centerTitle: true,
            ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Coming Soon Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF2DA9A5).withValues(alpha: 0.15),
                      const Color(0xFF16A34A).withValues(alpha: 0.15),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.card_membership_rounded,
                  size: 48,
                  color: Color(0xFF2DA9A5),
                ),
              ),

              const SizedBox(height: 28),

              Text(
                'Coming Soon!',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Meal subscription management is coming soon.\nYou\'ll be able to view, pause, and manage all your kitchen subscriptions here.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    height: 1.6,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Features Preview
              _buildFeature(Icons.visibility_rounded, 'View all plans'),
              const SizedBox(height: 10),
              _buildFeature(Icons.pause_circle_rounded, 'Pause or cancel anytime'),
              const SizedBox(height: 10),
              _buildFeature(Icons.history_rounded, 'Track subscription history'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeature(IconData icon, String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF2DA9A5)),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF475569),
          ),
        ),
      ],
    );
  }
}
