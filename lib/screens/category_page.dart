import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class CategoryPage extends StatelessWidget {
  final String categoryName;

  const CategoryPage({super.key, required this.categoryName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Ghar ka Khana',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: AppColors.textMain,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: AppColors.textMain),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              categoryName,
              style: GoogleFonts.poppins(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Menu Coming Soon',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: AppColors.textSub,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
