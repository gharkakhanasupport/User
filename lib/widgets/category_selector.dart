import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class CategorySelector extends StatelessWidget {
  final String selectedCategory;
  final Function(String) onCategorySelected;
  final bool isVeg;

  const CategorySelector({
    super.key,
    required this.selectedCategory,
    required this.onCategorySelected,
    this.isVeg = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCategoryCard('All', Icons.restaurant_menu),
                const SizedBox(width: 12),
                _buildCategoryCard('Lunch', Icons.wb_sunny),
                const SizedBox(width: 12),
                _buildCategoryCard('Breakfast', Icons.bakery_dining),
                const SizedBox(width: 12),
                _buildCategoryCard('Dinner', Icons.nights_stay),
                const SizedBox(width: 12),
                _buildCategoryCard('Snacks', Icons.icecream),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(String title, IconData icon) {
    final bool isActive = selectedCategory == title;
    
    LinearGradient activeGradient;
    switch (title) {
      case 'Breakfast':
        activeGradient = AppColors.bgGradientYellow;
        break;
      case 'Lunch':
        activeGradient = AppColors.bgGradientOrange;
        break;
      case 'Dinner':
        activeGradient = AppColors.bgGradientBlue;
        break;
      case 'Snacks':
        activeGradient = AppColors.bgGradientPurple;
        break;
      default:
        activeGradient = AppColors.categoryGradientActive;
    }

    final Color borderColor = isVeg ? const Color(0xFFAED581) : const Color(0xFFEF9A9A);
    final Color shadowColor = isVeg ? const Color(0xFFAED581) : const Color(0xFFEF9A9A);
    final Color inactiveTextColor = isVeg ? AppColors.primaryDark : AppColors.primaryRedDark;

    return GestureDetector(
      onTap: () => onCategorySelected(title),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: isActive ? 100 : 86,
        height: isActive ? 110 : 96,
        decoration: BoxDecoration(
          gradient: isActive ? activeGradient : null,
          color: isActive ? null : Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(24),
          border: isActive
              ? null
              : Border.all(color: borderColor, style: BorderStyle.solid, width: 2),
          boxShadow: isActive ? [
            BoxShadow(
              color: shadowColor.withValues(alpha: 0.4),
              blurRadius: 15,
              offset: const Offset(0, 4),
            )
          ] : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: isActive ? 32 : 28,
              color: isActive ? (title == 'Breakfast' || title == 'Lunch' ? Colors.brown[800] : Colors.white) : inactiveTextColor,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: GoogleFonts.poppins(
                color: isActive ? (title == 'Breakfast' || title == 'Lunch' ? Colors.brown[800] : Colors.white) : inactiveTextColor,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                fontSize: isActive ? 14 : 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
