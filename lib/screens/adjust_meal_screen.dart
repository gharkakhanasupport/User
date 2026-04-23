import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdjustMealScreen extends StatefulWidget {
  const AdjustMealScreen({super.key});

  @override
  State<AdjustMealScreen> createState() => _AdjustMealScreenState();
}

class _AdjustMealScreenState extends State<AdjustMealScreen> {

  @override
  Widget build(BuildContext context) {
    const Color customPrimary = Color(0xFF2DA931);
    const Color backgroundLight = Color(0xFFF6F8F6);
    const Color golden = Color(0xFFC2941B);
    const Color textMain = Color(0xFF121712);
    const Color textMuted = Color(0xFF678368);

    return Scaffold(
      backgroundColor: backgroundLight,
      appBar: AppBar(
        title: Text(
          'Adjust Today\'s Lunch',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textMain,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: textMain),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildDayItem('Tue', '19', false),
                _buildDayItem('Wed', '20', true, customPrimary),
                _buildDayItem('Thu', '21', false),
                _buildDayItem('Fri', '22', false),
                _buildDayItem('Sat', '23', false),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Context Title
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lunch for Wednesday, Nov 20',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textMain,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Changing your meal adjusts your token balance.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: textMuted,
                        ),
                      ),
                    ],
                  ),
                ),

                // Current Selection
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'YOUR CURRENT SELECTION',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: textMuted,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              'Scheduled',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: customPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: customPrimary.withOpacity(0.1), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          children: [
                            Positioned(
                              left: 0,
                              top: 0,
                              bottom: 0,
                              width: 4,
                              child: Container(color: customPrimary),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 96,
                                        height: 96,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(12),
                                          image: const DecorationImage(
                                            image: NetworkImage('https://lh3.googleusercontent.com/aida-public/AB6AXuCPXeocS3tjANg54968ZQr5dZBJ7NLhOAxJsySpH-EsCDGz3ED1nx3eEIB-nzvGnahjMk-6dLeq5zPcXeHnVXamtBxx9Rv1i5mBOMQLBRbmi3-Zkwo1cJTIGmWBRyxkxm6j3LrLhORLH6bL60TljeP0i7-Ne5akSJmND8RrFuF4HQLLyaqDNyY9KZ7-zLx-Kw0T7VrPCkCGYwug3uO2FUHlLvUBFcWShRSqMCaTKEzbINqnZo2jU2gfqxmvwsPez_XIw682wUYNk3BA'),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                _buildDietIcon(true, customPrimary),
                                                const Spacer(),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade100,
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    '70 Tokens',
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: textMain,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Rajma Chawal with Salad',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: textMain,
                                                height: 1.1,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Homestyle kidney beans curry with basmati rice and fresh salad.',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 14,
                                                color: textMuted,
                                                height: 1.4,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const Divider(height: 1, color: Color(0xFFF3F4F6)),
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: customPrimary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.check_circle, size: 18, color: customPrimary),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Keep this Meal',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: customPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
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

                const Divider(height: 1, thickness: 8, color: Color(0xFFF3F4F6)),

                // Alternatives
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose an Alternative',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textMain,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('All Options', true, customPrimary),
                            const SizedBox(width: 8),
                            _buildFilterChip('Lite Meals', false, customPrimary),
                            const SizedBox(width: 8),
                            _buildFilterChip('Roti Special', false, customPrimary),
                            const SizedBox(width: 8),
                            _buildFilterChip('High Protein', false, customPrimary),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // List of Cards
                      _buildAlternativeCard(
                        title: 'Aloo Gobi with Roti',
                        desc: 'Classic spiced cauliflower & potato fry.',
                        tokens: '65',
                        image: 'https://lh3.googleusercontent.com/aida-public/AB6AXuC_zg7mAKPka5uVFeQgM0MHa0EX3agVXb-f_W3QjEKzVfBazB7NUIDiGyAYguspIOOSRF_uGUl0KGtsbdzMRNXHQaX4A0280CgR3RXgyzxGmXCIns7LM25Le0d597SP3Hr_6FqvDsAflTLmsZZiNw3-fEPf2ubSAaaRwHi7H5UqurQhCFVe3jErVGTQs0ghsCFMc7DNkNkwq_WwnfcoZDuYQQi6zIiPAwItRE8b3B0OXhfDEbUFKbicdvrfGk1Dgg32bykMdiMf6NLs',
                        isVeg: true,
                        tag: 'Save 5 Tokens',
                        tagColor: customPrimary,
                        customPrimary: customPrimary,
                      ),
                      const SizedBox(height: 16),
                      _buildAlternativeCard(
                        title: 'Home-style Chicken Curry',
                        desc: 'Tender chicken in spiced gravy w/ rice.',
                        tokens: '90',
                        image: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAP17K9F8crlq93rkAes3tJwJyAIv2Tcef1fXaocs-E003cat99ZPzVnTMaxbzsIryLCDBTQQ1ND-QjwKOu-Pu0psObsQRC5ZGmqXRYGoeeqbgjGg3K03BARzf_sptLuQuYe_rORkqHoJa223hRCgKzkHqaz2WhtSh722tLoRKXfgcUdTi5zutyNPf5lRBQEEZImdBrpXvbKQ8ce_r0f4KnM6lDsgs5_VBUa0sNOvpAl_yqCok8muuTl2DjsPiH_vETfkPHwFRJgLsE',
                        isVeg: false,
                        tag: 'Premium',
                        tagColor: golden,
                        customPrimary: customPrimary,
                      ),
                      const SizedBox(height: 16),
                      _buildAlternativeCard(
                        title: 'Palak Paneer & Naan',
                        desc: 'Cottage cheese in spinach gravy.',
                        tokens: '80',
                        image: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCAYCDq1dmfF2wkbewZcfZaAJbeRCryMJmq7z3KTkZ-qUb1wY30QgM96aPvD88HWLhGAGrHbHgJaJfxk47wRp0irEwS6_4PWqUaBN5VB84gPV-aTtaOaTdZloeCRZPLekHe4fBz9cFagPdEXr_VRhacKmjeqGoLXPJLFGBb_wD0_XnwJjF9G7RgTzf0BF4QLMYj7c9HNVGxxZYG4g5oLWaYjh9dC-v96aEZAU8uVqklAmHQd9qkBfhQyFaoECd8ovlUtkAkXbrmzHZb',
                        isVeg: true,
                        isSoldOut: true,
                        customPrimary: customPrimary,
                      ),
                      const SizedBox(height: 16),
                      _buildAlternativeCard(
                        title: 'Moong Dal Sprout Salad',
                        desc: 'Fresh sprouts, pomegranate, lemon.',
                        tokens: '60',
                        image: 'https://lh3.googleusercontent.com/aida-public/AB6AXuD02361Od6QDa5TVcvaAgszva3t397vFS9S56NbYCBK-AS_XLTksxy6ffo9KPPrktlh4XT9YT3VP7dhQGOXnMwca7i8y1-_9zlG_Gjlb7EUpR_KE1HyO-nlN6hEDPSmqac7jU2ofGGl23IATyXtSylCUecaZC1oXLqUChQVhDDnm4iwgx3Cu5iLuBwJN_euvWaZb_5g5GB5viIhECv0PDfYtX1DsfCwWLNqkU3oKhBV0e1W69451nijWfao37-fw3F6IR8TZ4ZbqfT5',
                        isVeg: true,
                        tag: 'Lite Option',
                        tagColor: customPrimary,
                        customPrimary: customPrimary,
                      ),
                      const SizedBox(height: 32),
                      Center(
                        child: Text(
                          'Showing all available meals for today',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Sticky Bottom Actions
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade100)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), offset: const Offset(0, -4), blurRadius: 10),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Current Balance',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: textMuted,
                        ),
                      ),
                      Text(
                        '70 Tokens',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textMain,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: customPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                        shadowColor: customPrimary.withOpacity(0.3),
                      ),
                      child: Text(
                        'Confirm Adjustment',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayItem(String day, String date, bool isSelected, [Color? activeColor]) {
    return Container(
      width: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? activeColor : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isSelected ? [BoxShadow(color: activeColor!.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            day,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isSelected ? Colors.white : const Color(0xFF678368).withOpacity(0.6),
            ),
          ),
          Text(
            date,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : const Color(0xFF678368).withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDietIcon(bool isVeg, [Color? color]) {
    final Color iconColor = isVeg ? (color ?? Colors.green) : Colors.red;
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        border: Border.all(color: iconColor),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: iconColor,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, Color activeColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF121712) : Colors.white,
        borderRadius: BorderRadius.circular(99),
        border: isSelected ? null : Border.all(color: Colors.grey.shade200),
        boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))] : null,
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isSelected ? Colors.white : const Color(0xFF121712),
        ),
      ),
    );
  }

  Widget _buildAlternativeCard({
    required String title,
    required String desc,
    required String tokens,
    required String image,
    required bool isVeg,
    String? tag,
    Color? tagColor,
    bool isSoldOut = false,
    required Color customPrimary,
  }) {
    return Opacity(
      opacity: isSoldOut ? 0.6 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4),
          ],
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: NetworkImage(image),
                      fit: BoxFit.cover,
                      colorFilter: isSoldOut ? const ColorFilter.mode(Colors.grey, BlendMode.saturation) : null,
                    ),
                  ),
                ),
                if (isSoldOut)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Sold Out',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildDietIcon(isVeg, customPrimary),
                      if (tag != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: tagColor!.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            tag,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: tagColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF121712),
                    ),
                  ),
                  Text(
                    desc,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: const Color(0xFF678368),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$tokens Tokens',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF121712),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isSoldOut ? Colors.grey.shade300 : customPrimary.withOpacity(1),
                          ),
                          borderRadius: BorderRadius.circular(8),
                          color: isSoldOut ? Colors.transparent : customPrimary.withOpacity(0),
                        ),
                        child: Text(
                          'Select',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSoldOut ? Colors.grey.shade400 : customPrimary,
                          ),
                        ),
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
