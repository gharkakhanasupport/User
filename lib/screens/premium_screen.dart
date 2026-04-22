import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';


class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Kitchen Subscriptions',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF121712),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
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
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          const Icon(Icons.rocket_launch, size: 48, color: Color(0xFF16A34A)),
                          const SizedBox(height: 16),
                          Text(
                            'Coming Soon!',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF121712),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
