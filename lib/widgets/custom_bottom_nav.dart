import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

import '../screens/category_transition_screen.dart';
import '../screens/my_orders_screen.dart';
import '../screens/ai_chat_screen.dart';

class CustomBottomNav extends StatelessWidget {
  final bool isVeg;

  const CustomBottomNav({super.key, this.isVeg = true});

  @override
  Widget build(BuildContext context) {
    final Color footerBg = isVeg ? AppColors.footerGreen : AppColors.footerRed;
    final Color fabGradientStart =
        isVeg ? Colors.limeAccent : const Color(0xFFFF8A80);
    final Color fabGradientEnd =
        isVeg ? Colors.green : const Color(0xFFE53935);
    final Color fabGlow = isVeg ? Colors.green : const Color(0xFFE53935);
    final Color fabBorder = footerBg;
    final Color fabIconHighlight =
        isVeg ? Colors.green.shade800 : Colors.red.shade800;
    final Color labelColor =
        isVeg ? Colors.green.shade800 : Colors.red.shade800;

    return SizedBox(
      height: 100,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // Bottom bar
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            height: 80,
            decoration: BoxDecoration(
              color: footerBg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 20,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(context, Icons.auto_awesome, 'AI', labelColor, _onAiTap),
                _buildNavItem(context, Icons.receipt_long, 'Orders', labelColor, _onOrdersTap),
                const SizedBox(width: 56), // Space for center FAB
                _buildNavItem(context, Icons.verified, 'Premium', labelColor, _onCategoryTap),
                _buildNavItem(context, Icons.account_balance_wallet, 'Wallet', labelColor, _onCategoryTap),
              ],
            ),
          ),

          // Center FAB
          Positioned(
            top: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              width: 64,
              height: 64,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [fabGradientStart, fabGradientEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: fabGlow.withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: fabBorder, width: 4),
                  gradient: LinearGradient(
                    colors: [fabGradientEnd, fabGradientStart],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.home, color: Colors.white, size: 32),
              ),
            ),
          ),
          Positioned(
            top: 68,
            child: Text(
              'Home',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: fabIconHighlight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onAiTap(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AiChatScreen()),
    );
  }

  void _onOrdersTap(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MyOrdersScreen()),
    );
  }

  void _onCategoryTap(BuildContext context, String label) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryTransitionScreen(categoryName: label),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    IconData icon,
    String label,
    Color activeHintColor,
    Function onTap,
  ) {
    return GestureDetector(
      onTap: () {
        if (label == 'Premium' || label == 'Wallet') {
          _onCategoryTap(context, label);
        } else {
          onTap(context);
        }
      },
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: activeHintColor.withOpacity(0.6), size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: activeHintColor.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
