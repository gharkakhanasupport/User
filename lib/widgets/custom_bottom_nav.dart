import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

import '../screens/category_transition_screen.dart';

class CustomBottomNav extends StatelessWidget {
  const CustomBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100, // allocate space for the floating button
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            height: 80,
            decoration: const BoxDecoration(
              color: AppColors.footerGreen,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 20,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(context, Icons.verified, 'Premium'),
                const SizedBox(width: 48), // Space for FAB
                _buildNavItem(context, Icons.account_balance_wallet, 'Wallet'),
              ],
            ),
          ),
          
          Positioned(
            top: 0,
            child: Container(
              width: 64,
              height: 64,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Colors.limeAccent, Colors.green],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.footerGreen, width: 4),
                  gradient: const LinearGradient(
                    colors: [Colors.green, Colors.lime],
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
                 color: Colors.green[800],
               ),
             ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, IconData icon, String label) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CategoryTransitionScreen(categoryName: label),
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.grey[500], size: 28),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}
