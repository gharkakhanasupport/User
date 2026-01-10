import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class OfferData {
  final String tag;
  final String title;
  final String subtitle;
  final String imageUrl;
  final Color badgeColor;

  OfferData({
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    this.badgeColor = AppColors.secondaryGold,
  });
}

class HeroBanner extends StatefulWidget {
  final bool isVeg;

  const HeroBanner({super.key, required this.isVeg});

  @override
  State<HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<HeroBanner> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  final List<OfferData> _offers = [
    OfferData(
      tag: 'LIMITED OFFER',
      title: 'Flat 20% off\non Lunch Thali',
      subtitle: 'Mom\'s Special • Healthy & Fresh',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuDbZxs_Cg6fVR4wxAmMbBFpss3m3g8kWNEQaDUP8Oq8cPti0k8cqvcbS9FRAYYz8_pC-41FyJXzJJRGFSMEXBVsapyhZhErDCbvDEFaczJhtNclACePGGptJPdqc7hMcWJAzdJdMlCQrlKDNYGEmQHnAVF02jfhoLDX0w-6QKcNPgwDyXqcxEhXRnx5_I-ITT0l4LIiBodUdzs9gZD6MX9-D4-p-qmO7BJosXEXalpI0BwGmnSJn9PKedWsMq3Y6tvgNfOS7sfJB9-x',
    ),
    OfferData(
      tag: 'NEW YEAR BASH',
      title: 'Free Gulab Jamun\nwith every order',
      subtitle: 'Sweet start to 2026 • Limited Time',
      badgeColor: Colors.pinkAccent,
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAKeai1aQcCxJF6PiIxo9YICjQKgnQ6ONfpY8OEu1JQ2yNrvdx1DEfBs-R8rPr_8-1sGe40VF2wCCf99JVU6nTukN-m5BaO04HbSgxLMmCGXXZbvdAnDe29v-YOWjC0Tn7ndct6j2AYPjb8rH_SunK23vSeVA37kwOsE4KwF5Agje6Rqh2YiV05AfCL9RORQE3aGRCEpEn60uAk4EPd6_ZJFoeVvlrOxUYo8bBdTEDUEokmkFQASpvsG_GaX0GU8-4ObHUGKE_TRQj_', 
    ),
    OfferData(
      tag: 'WEEKEND SPECIAL',
      title: 'Flat ₹100 Cashback\non Dinner',
      subtitle: 'Order above ₹400 • Use Code: WEEKEND100',
      badgeColor: Colors.orangeAccent,
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuBgRI_BJa7g7D6iYGRDARjUQU2PKdEykXLQo3nnbCvbW5SP8MSDgk-pd1bHYAJZoayBmFkb-si1DSAR3W4xIW95ZXE70e1zEfmmYwp4bQY-MzD9Q_tuUCYZEgthKp1u1wgU7nqkoNEqm9CL7Ogno5MdS_I1c2O3F2Izq1xz_xJqRwJwiXdjumD1S5CAhf3CAzsxrGqgqULINYVKeHYRseMVWDZ66cNKDiT3WQg-x1NlKGZdbRuYWgZ-wPhCSdA0fv84IFxglkThGL7U',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_currentPage < _offers.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }

      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: _offers.length,
            itemBuilder: (context, index) {
              return _buildOfferCard(_offers[index]);
            },
          ),
        ),
        const SizedBox(height: 12),
        // Pagination Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_offers.length, (index) {
            bool isActive = _currentPage == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 24 : 8,
              height: 6,
              decoration: BoxDecoration(
                color: isActive 
                    ? (widget.isVeg ? AppColors.primary : AppColors.primaryRed) 
                    : Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildOfferCard(OfferData offer) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: widget.isVeg ? AppColors.heroGradient : AppColors.heroGradientRed,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (widget.isVeg ? const Color(0xFF4CAF50) : const Color(0xFFE53935))
                .withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background Pattern
          Positioned.fill(
             child: Opacity(
               opacity: 0.1,
               child: CustomPaint(
                 painter: _PatternPainter(),
               ),
             ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    offer.tag,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  offer.title,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  offer.subtitle,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Decorative Images
          Positioned(
            right: -20,
            bottom: -20,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.2), width: 4),
                boxShadow: [
                   BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                  )
                ],
              ),
              child: ClipOval(
                child: Image.network(
                  offer.imageUrl,
                  fit: BoxFit.cover,
                )
              ),
            ),
          ),
          
          Positioned(
            top: 20,
            right: 80, 
            child: Transform.rotate(
              angle: 0.2, 
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: offer.badgeColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'LIMITED',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'OFFER',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Simple painter to simulate a subtle pattern
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
