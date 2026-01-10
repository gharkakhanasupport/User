import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class CategorySelector extends StatelessWidget {
  final String selectedCategory;
  final Function(String) onCategorySelected;

  const CategorySelector({
    super.key,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              _buildCategoryCard('Lunch', Icons.wb_sunny),
              const SizedBox(width: 12),
              _buildCategoryCard('Breakfast', Icons.bakery_dining),
              const SizedBox(width: 12),
              _buildCategoryCard('Dinner', Icons.nights_stay),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(String title, IconData icon) {
    final bool isActive = selectedCategory == title;
    
    return Expanded(
      child: GestureDetector(
        onTap: () => onCategorySelected(title),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: isActive ? 110 : 96,
          decoration: BoxDecoration(
            gradient: isActive ? AppColors.categoryGradientActive : null,
            color: isActive ? null : Colors.white.withOpacity(0.5),
            borderRadius: BorderRadius.circular(24),
            border: isActive ? null : Border.all(color: const Color(0xFFAED581), style: BorderStyle.solid, width: 2), 
            boxShadow: isActive ? [
              BoxShadow(
                color: const Color(0xFFAED581).withOpacity(0.4),
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
                color: isActive ? Colors.white : AppColors.primaryDark,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: isActive ? Colors.white : AppColors.primaryDark,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  fontSize: isActive ? 14 : 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
