import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../core/localization.dart';

class CustomBottomNav extends StatefulWidget {
  final bool isVeg;
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNav({
    super.key, 
    this.isVeg = true,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<CustomBottomNav> createState() => _CustomBottomNavState();
}

class _CustomBottomNavState extends State<CustomBottomNav> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(5, (index) => AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    ));
    _controllers[widget.currentIndex].value = 1.0;
  }

  @override
  void didUpdateWidget(CustomBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _controllers[oldWidget.currentIndex].reverse();
      _controllers[widget.currentIndex].forward();
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color footerBg = widget.isVeg ? AppColors.footerGreen : AppColors.footerRed;
    final Color activeColor = widget.isVeg ? Colors.green.shade800 : Colors.red.shade800;
    final Color inactiveColor = activeColor.withValues(alpha: 0.5);
    
    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    final double navBarHeight = 75 + bottomPadding;

    return Container(
      color: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // Background Bar
          Container(
            width: double.infinity,
            height: navBarHeight,
            padding: EdgeInsets.only(bottom: bottomPadding),
            decoration: BoxDecoration(
              color: footerBg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(35),
                topRight: Radius.circular(35),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildNavItem(0, Icons.auto_awesome, 'ai'.tr(context), activeColor, inactiveColor),
                _buildNavItem(1, Icons.shopping_basket, 'basket'.tr(context), activeColor, inactiveColor),
                const SizedBox(width: 80), // Space for Home FAB
                _buildNavItem(3, Icons.verified, 'premium'.tr(context), activeColor, inactiveColor),
                _buildNavItem(4, Icons.account_balance_wallet, 'wallet'.tr(context), activeColor, inactiveColor),
              ],
            ),
          ),

          // Elevated Home Button (FAB)
          Positioned(
            bottom: bottomPadding + 20,
            child: _buildHomeButton(2, activeColor),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, Color activeColor, Color inactiveColor) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap(index);
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: double.infinity,
          alignment: Alignment.center,
          child: AnimatedBuilder(
            animation: _controllers[index],
            builder: (context, child) {
              final double value = Curves.easeOut.transform(_controllers[index].value);
              return Transform.translate(
                offset: Offset(0, -6 * value),
                child: Transform.scale(
                  scale: 1.0 + (0.05 * value),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        color: Color.lerp(inactiveColor, activeColor, value),
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: value > 0.5 ? FontWeight.bold : FontWeight.w500,
                          color: Color.lerp(inactiveColor, activeColor, value),
                        ),
                      ),
                      // Indicator Dot
                      Opacity(
                        opacity: value,
                        child: Container(
                          margin: const EdgeInsets.only(top: 2),
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: activeColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: activeColor.withValues(alpha: 0.5),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHomeButton(int index, Color activeColor) {
    final Color fabGradientStart = widget.isVeg ? Colors.limeAccent : const Color(0xFFFF8A80);
    final Color fabGradientEnd = widget.isVeg ? Colors.green : const Color(0xFFE53935);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap(index);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 80,
        alignment: Alignment.bottomCenter,
        child: AnimatedBuilder(
          animation: _controllers[index],
          builder: (context, child) {
            final double value = Curves.easeOut.transform(_controllers[index].value);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.translate(
                  offset: Offset(0, -12 * value),
                  child: Transform.scale(
                    scale: 1.0 + (0.08 * value),
                    child: Container(
                      width: 65,
                      height: 65,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [fabGradientStart, fabGradientEnd],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: fabGradientEnd.withValues(alpha: 0.4),
                            blurRadius: 15 + (10 * value),
                            spreadRadius: 2 + (2 * value),
                            offset: Offset(0, 4 * value),
                          ),
                        ],
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                          color: fabGradientEnd,
                        ),
                        child: const Icon(Icons.home_rounded, color: Colors.white, size: 32),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Transform.translate(
                  offset: Offset(0, -6 * value),
                  child: Text(
                    'home'.tr(context),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: activeColor,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
