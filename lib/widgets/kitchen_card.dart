import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../screens/kitchen_detail_screen.dart';
import '../screens/kitchen_loading_screen.dart';

class KitchenCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imageUrl;
  final String rating;
  final String price;
  final String time;
  final bool isVeg;
  final String? tag;
  final Color? tagColor;
  final String? secondaryTag;
  final Color? secondaryTagColor;
  final bool isClosed;

  const KitchenCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.rating,
    required this.price,
    required this.time,
    this.isVeg = true,
    this.tag,
    this.tagColor,
    this.secondaryTag,
    this.secondaryTagColor,
    this.isClosed = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => KitchenLoadingScreen(
            kitchenName: title,
            kitchenSubtitle: subtitle,
            rating: rating,
            ratingCount: '(124)', 
            imageUrl: imageUrl,
            tag: tag ?? 'Home-style',
            time: time,
          )),
        );
      },
      child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardLight,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000), // ~5% opacity
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Section
          SizedBox(
            width: 112,
            height: 112,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ColorFiltered(
                    colorFilter: isClosed 
                        ? const ColorFilter.mode(Colors.grey, BlendMode.saturation) 
                        : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                    child: Image.network(
                      imageUrl,
                      width: 112,
                      height: 112,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                if (!isClosed) Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.yellow[400],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star, size: 10, color: Colors.black),
                        const SizedBox(width: 2),
                        Text(
                          rating,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isClosed) Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                    ),
                    child: Text(
                      'CLOSED',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Info Section
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isClosed ? Colors.grey : AppColors.textMain,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.green),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.circle, color: Colors.green, size: 8),
                    ),
                  ],
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textSub,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (tag != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (tagColor ?? Colors.green).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tag!,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: tagColor ?? Colors.green[700],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (secondaryTag != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (secondaryTagColor ?? Colors.orange).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          secondaryTag!,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: secondaryTagColor ?? Colors.orange[700],
                          ),
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Divider
                Container(
                  height: 1,
                  color: Colors.grey[200], // Dashed border simulated with light grey line
                ),
                
                const SizedBox(height: 8),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: price,
                            style: GoogleFonts.poppins(
                              color: isClosed ? Colors.grey[400] : Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          // Optional "for Thali" text could be passed or hardcoded for specific instance
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 12, color: AppColors.textSub),
                        const SizedBox(width: 4),
                        Text(
                          time,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.textSub,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }
}
