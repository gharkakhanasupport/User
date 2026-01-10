import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import 'kitchen_subscription_screen.dart';
import 'cart_screen.dart';

// Data models
class MenuItemData {
  final String title;
  final String description;
  final String price;
  final String imageUrl;

  MenuItemData(this.title, this.description, this.price, this.imageUrl);
}

class ReviewData {
  final String name;
  final String initial;
  final String rating;
  final String text;
  final Color accentColor;

  ReviewData(this.name, this.initial, this.rating, this.text, this.accentColor);
}

class ComboData {
  final String title;
  final String subtitle;
  final String price;
  final String originalPrice;
  final String imageUrl;
  final String badgeText;

  ComboData(this.title, this.subtitle, this.price, this.originalPrice, this.imageUrl, this.badgeText);
}

class KitchenDetailScreen extends StatefulWidget {
  final String kitchenName;
  final String kitchenSubtitle;
  final String rating;
  final String ratingCount;
  final String imageUrl;
  final String tag;
  final String time;

  const KitchenDetailScreen({
    super.key,
    required this.kitchenName,
    required this.kitchenSubtitle,
    required this.rating,
    required this.ratingCount,
    required this.imageUrl,
    required this.tag,
    required this.time,
  });

  @override
  State<KitchenDetailScreen> createState() => _KitchenDetailScreenState();
}

class _KitchenDetailScreenState extends State<KitchenDetailScreen> {
  String _selectedDay = 'Wed';
  final List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  
  // Dynamic Data
  late MenuItemData _todaySpecial;
  late List<ComboData> _combos;
  late List<MenuItemData> _menuItems;
  late List<ReviewData> _reviews;
  
  // Cart State (Detailed)
  final Map<String, int> _cartQuantities = {};

  int get _cartItemCount => _cartQuantities.values.fold(0, (sum, qty) => sum + qty);
  
  int get _cartTotal {
    int total = 0;
    _cartQuantities.forEach((name, qty) {
      if (qty > 0) {
        // Find price for item name (Simplified lookup)
        int price = 0;
        if (_todaySpecial.title == name) {
           price = int.tryParse(_todaySpecial.price.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        } else {
           // check combos
           final combo = _combos.firstWhere((c) => c.title == name, orElse: () => ComboData('', '', '0', '', '', ''));
           if (combo.title.isNotEmpty) {
             price = int.tryParse(combo.price.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
           } else {
             // check menu
             final item = _menuItems.firstWhere((i) => i.title == name, orElse: () => MenuItemData('', '', '0', ''));
             if (item.title.isNotEmpty) {
                price = int.tryParse(item.price.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
             }
           }
        }
        total += price * qty;
      }
    });
    return total;
  }

  int _getQuantity(String itemName) {
    return _cartQuantities[itemName] ?? 0;
  }

  void _updateQuantity(String itemName, int delta) {
    setState(() {
      final currentQty = _cartQuantities[itemName] ?? 0;
      final newQty = currentQty + delta;
      if (newQty <= 0) {
        _cartQuantities.remove(itemName);
      } else {
        _cartQuantities[itemName] = newQty;
      }
    });
  }

  // Simplified Map collection for Cart Screen
  Map<String, int> _getItemPrices() {
     Map<String, int> prices = {};
     // Add special
     prices[_todaySpecial.title] = int.tryParse(_todaySpecial.price.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
     // Add combos
     for (var c in _combos) {
       prices[c.title] = int.tryParse(c.price.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
     }
     // Add menu
     for (var m in _menuItems) {
       prices[m.title] = int.tryParse(m.price.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
     }
     return prices;
  }

  Map<String, String> _getItemImages() {
     Map<String, String> images = {};
     images[_todaySpecial.title] = _todaySpecial.imageUrl;
     for (var c in _combos) images[c.title] = c.imageUrl;
     for (var m in _menuItems) images[m.title] = m.imageUrl;
     return images;
  }

  @override
  void initState() {
    super.initState();
    _generateRandomData();
  }

  void _generateRandomData() {
    final random = Random();
    
    // Fake Data Pools
    final foodImages = [
      'https://lh3.googleusercontent.com/aida-public/AB6AXuAINz9yhW5e5EMtBem-jy_W6jxcxVmfYI-tTW2lVfxUjvtQeDqCoRKrrc9-ZhsQvEGS6VZAe-1lvv0civlYYAyQgcYUI2uYKuAqYoWlkL1jZ9oFmgxjXSuSrIvIzbSFoXajZYREusuMR3VuPKeiNglVsjsc_nERyx--fDdplJgu-om70fKWPzOnGNm-Zgb1hYCvS-TtA67K8UClFmfpHnMYi2_DMz4qaW-z8-31DH-3DaP5UAj5tqpCY3dOZdz3usfFbA56s__xUS7-',
      'https://lh3.googleusercontent.com/aida-public/AB6AXuCKQijJc3dDzPLhsWGqrbs0so6OIkZuT_ysqZKOPwX66SksB2wHyOlLDFmxQfbBCuwWV0b-RQSfHDJ_G_VuIgSv9L1wfFQs9PoYjeDstyfgBn-IKQmLi_v2aP3VSlXM9vwZcMMUij81TbGtTMF_NrrRez997I1D_EEGz3m0z_fhiS6o2oX2XGBH3seL5akocJDaipAM4Z-euE-FyQW2UT3m5UY8VHZVq99mmlgw98BYLlMrBYCDyaYUaNfrVuFHFQkV4fX2kS6iuySG',
      'https://lh3.googleusercontent.com/aida-public/AB6AXuBMMHi-c_9-RO0EEx3jDczhxr_kYVtW0-AooSv0Qj_kOEDwJjY8Fg1DjItOCXKVZPocBMR2XnoAjLtcvhHIIQ-F2jV7vtMXuZhUq26Gn9O4tXlYZG-qX9oTgocgy3LdyI8YuiBNB8ka4OxyXvRk_Vo-D7TpEwsU6neD7ivTminm097tROThcy-ETT67S-z1l-Op05YVItVwCiS3rbusOL_Jqa1N1Qh8DjvykHbH32tMXtUCf0Nq1Bl8_-scYP5kPaM2gFUQOPPRODak',
      'https://lh3.googleusercontent.com/aida-public/AB6AXuCwWBXmKdotDf219CwSCjWGRodM7bpqqP_zDYhuJp_t77KhRbQctkY-lWuwBk0_bqVGhTR6vYIKTKhjvllPMLZeN8I75plC0ln31KtqJC5IueKLbc2mVPgbRAclwAW7IdFbuz_-MCMYnyd_HlCecDQYcQ_CWo7GwYWSUcV6ZdR1WgwLaMkTeK6DTcioHmoBHllUF40_9FPKBkSyFywWPwlYI4jOqBgx46dgEbFFkj6tJYy-nZwcO5pu7684cf9GHgY1MhCNJfE5eogX',
      'https://lh3.googleusercontent.com/aida-public/AB6AXuAtil5X99a99ttu4u9rvQrR6Jd_JkR9qAus-Go6oDFRS1eYg4o8uvS_H5T3rvijpPVsBjnDYdxJhAM3-9ey66UzkEaTSVes1O7RtQLBnB3UP88VJNcHqaCJCCcHvRge0sKG84zp30Rsuk9vQhPkDPCWYJm-52wjrA5sblLRWAtNuWKw0LRyMLxVgT_qnE3fktMyJAVpPWSXf2HqcKmegPX5x-wVcxRPhxZlcuViIo9OkSXCNyDrjstGc_xtt4kpbdjtyWyrElBb1Atj',
      'https://lh3.googleusercontent.com/aida-public/AB6AXuDz7dYX4K34K4J5OdZmna3I9A_uvAOgYhvvyIz2Erl1UoSVgXU5jzaREOptxlzBqdYFhJR9r4YUFfkzbHh1ptxQXpLks2-p3CUK9O3v6LxOp2Y3gaIg-WVBIXVeGgAYn9ZaQVawhj8WCByoP0-N09Io6_kNGjuItd_yvMTcLwKOh9_tUv_jIxYQLqkA-IGfZsRvvRnboSSQWKU_b4SOC5mNt205p6UwCkx4mKwoq37ZT0JJR9tUZHkBKsG0j9Pw_1AGSd_nZxcwFvYO',
    ];

    final specialTitles = ['$_selectedDay Special Thali', 'Maharaja Thali', 'Mini Veg Meal', 'Deluxe Feast'];
    final comboTitles = ['Combo Delight', 'Family Pack', 'Budget Meal', 'Picnic Basket'];
    final menuTitles = ['Paneer Butter Masala', 'Aloo Gobi', 'Chole Bhature', 'Malai Kofta', 'Dal Makhani', 'Kadai Veg'];

     _todaySpecial = MenuItemData(
      specialTitles[random.nextInt(specialTitles.length)],
      'Includes Roti, Rice, two sabzis, salad and a sweet dish. Perfect for lunch!',
      '₹${100 + random.nextInt(100)}',
      foodImages[random.nextInt(foodImages.length)],
    );

    _combos = List.generate(3, (index) => ComboData(
      comboTitles[random.nextInt(comboTitles.length)],
      'Perfect for sharing',
      '₹${200 + random.nextInt(200)}',
      '₹${450 + random.nextInt(100)}',
      foodImages[random.nextInt(foodImages.length)],
      random.nextBool() ? 'BEST VALUE' : '15% OFF',
    ));

    _menuItems = List.generate(5, (index) => MenuItemData(
      menuTitles[random.nextInt(menuTitles.length)],
      'Freshly prepared with home-made spices.',
      '₹${80 + random.nextInt(150)}',
      foodImages[random.nextInt(foodImages.length)],
    ));

    final reviewNames = ['Rahul', 'Priya', 'Amit', 'Sneha', 'Vikram'];
    final reviewTexts = [
      'Amazing food! Tasted just like home.',
      'Great quantity for the price.',
      'Loved the packaging. Very neat.',
      'A bit spicy but very tasty.',
      'Will definitely order again!'
    ];

    _reviews = List.generate(3, (index) => ReviewData(
      reviewNames[random.nextInt(reviewNames.length)],
      reviewNames[random.nextInt(reviewNames.length)][0],
      (3.5 + random.nextDouble() * 1.5).toStringAsFixed(1),
      reviewTexts[random.nextInt(reviewTexts.length)],
      Colors.primaries[random.nextInt(Colors.primaries.length)],
    ));
  }
  
  void _onDaySelected(String day) {
    setState(() {
      _selectedDay = day;
      _generateRandomData(); // Refresh content
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
          // Sticky Top App Bar
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF334155)),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              widget.kitchenName,
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF0F172A),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              // Veg Toggle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9), // slate-100
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle),
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                              color: Color(0xFF16A34A), // green-600
                              shape: BoxShape.circle),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Veg',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF475569), // slate-600
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Profile Icon
              IconButton(
                icon: const Icon(Icons.account_circle, color: Color(0xFF334155)),
                onPressed: () {},
              ),
              const SizedBox(width: 4),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1.0),
              child: Container(color: const Color(0xFFF1F5F9), height: 1.0),
            ),
          ),

          // Hero Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                children: [
                   // Profile Image with Verification
                  Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4), 
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 48,
                          backgroundImage: NetworkImage(widget.imageUrl),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFF1F5F9)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                              )
                            ]
                          ),
                          child: const Icon(Icons.verified, color: Color(0xFF16A34A), size: 20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Kitchen Details
                  Text(
                    widget.kitchenName,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.kitchenSubtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Tags Row
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildTag(Icons.star, widget.rating, widget.ratingCount, const Color(0xFFC2941B), const Color(0xFFF8F9FA)),

                      _buildTag(Icons.schedule, widget.time, '', const Color(0xFFC2941B), const Color(0xFFF8F9FA)),

                      _buildTag(Icons.home_work, widget.tag, '', const Color(0xFF166534), const Color(0xFFF0FDF4), fgColor: const Color(0xFF166534)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Subscription Button
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => KitchenSubscriptionScreen(
                        kitchenName: widget.kitchenName,
                        imageUrl: widget.imageUrl,
                        price: '₹3,500', // Example fixed price for now
                        rating: widget.rating,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFDCFCE7), Color(0xFFF0FDF4)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.card_membership, color: Color(0xFF16A34A)),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Subscribe & Save',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF14532D),
                                ),
                              ),
                              Text(
                                'Plans starting at ₹850/week',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: const Color(0xFF166534),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF166534)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Weekly Availability
          SliverToBoxAdapter(
            child: StickyHeader(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month, size: 20, color: Color(0xFFC2941B)),
                        const SizedBox(width: 8),
                        Text(
                          'Available Days',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: _days.map((day) => GestureDetector(
                        onTap: () => _onDaySelected(day),
                        child: _buildDayChip(day, day == _selectedDay),
                      )).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Today's Special
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_selectedDay\'s Special Thali',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFDCFCE7)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  image: DecorationImage(
                                    image: NetworkImage(_todaySpecial.imageUrl),
                                    fit: BoxFit.cover,
                                  ),
                                  boxShadow: [
                                     BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                    ),
                                  ]
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _todaySpecial.title,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _todaySpecial.description,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: const Color(0xFF475569),
                                        height: 1.5,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _todaySpecial.price,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF0F172A),
                                            ),
                                          ),
                                          _buildAddButton(_todaySpecial.title, _todaySpecial.price),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: const BoxDecoration(
                              color: Color(0xFFC2941B),
                              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(8)),
                            ),
                            child: Text(
                              'BEST VALUE',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // Combo Cards
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Combo Meals',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    child: Row(
                      children: _combos.map((combo) => Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: _buildComboCard(combo),
                      )).toList(),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          
          // Food Menu List with Sticky Header
          SliverPersistentHeader(
            pinned: true,
            delegate: _MenuHeaderDelegate(),
          ),
          
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = _menuItems[index];
                return _buildMenuItem(item);
              },
              childCount: _menuItems.length,
            ),
          ),

          // Reviews Section
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF8F9FA),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Column(
                children: [
                   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'What Neighbours Say',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'View all',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    child: Row(
                      children: _reviews.map((review) => Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: _buildReviewCard(review),
                      )).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Rate Input
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                         BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rate your experience',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (index) => const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(Icons.star, color: Color(0xFFCBD5E1), size: 32),
                          )),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Text('Write a review...', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8))),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF16A34A),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(color: const Color(0xFF16A34A).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
                                ]
                              ),
                              child: const Icon(Icons.send, color: Colors.white, size: 20),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 48), // Padding for bottom
                ],
              ),
            ),
          ),
        ],
      ),
          // Cart Popup
          if (_cartItemCount > 0)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF16A34A).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$_cartItemCount ITEMS',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                            Text(
                              '₹$_cartTotal',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
              GestureDetector(
                onTap: () {
                   Navigator.push(
                     context,
                     MaterialPageRoute(builder: (context) => CartScreen(
                       cartItems: _cartQuantities,
                       itemPrices: _getItemPrices(),
                       itemImages: _getItemImages(),
                       kitchenName: widget.kitchenName,
                     )),
                   );
                },
                child: Row(
                  children: [
                    Text(
                      'View Cart',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_right_alt, color: Colors.white),
                  ],
                ),
              ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTag(IconData icon, String label, String sub, Color iconColor, Color bgColor, {Color? fgColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: fgColor ?? const Color(0xFF1E293B),
            ),
          ),
          if (sub.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(
              sub,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
            ),
          ]
        ],
      ),
    );
  }
  
  Widget _buildDayChip(String day, bool isActive) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF16A34A) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(24),
        border: isActive ? null : Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: isActive ? [
           BoxShadow(
            color: const Color(0xFF16A34A).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ] : null,
      ),
      child: Text(
        day,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
          color: isActive ? Colors.white : const Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildComboCard(ComboData combo) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
           BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                height: 128,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: NetworkImage(combo.imageUrl),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_offer, size: 12, color: Color(0xFFC2941B)),
                      const SizedBox(width: 4),
                      Text(
                        combo.badgeText,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFC2941B),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            combo.title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            combo.subtitle,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    combo.price,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    combo.originalPrice,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      decoration: TextDecoration.lineThrough,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              _buildAddButton(combo.title, combo.price, isSmall: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(MenuItemData item) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF8FAFC))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 4, right: 8),
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF16A34A)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.circle, size: 8, color: Color(0xFF16A34A)),
                    ),
                    Expanded(
                      child: Text(
                        item.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Text(
                    item.description,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: const Color(0xFF64748B),
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Text(
                    item.price,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                   borderRadius: BorderRadius.circular(12),
                   image: DecorationImage(image: NetworkImage(item.imageUrl), fit: BoxFit.cover),
                   color: const Color(0xFFF1F5F9),
                ),
              ),
              Positioned(
                bottom: -12,
                left: 0,
                right: 0,
                child: Center(
                  child: _buildAddButton(item.title, item.price, isPill: true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(ReviewData review) {
    return Container(
      width: 256,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
           BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: review.accentColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  review.initial,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    color: review.accentColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                review.name,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              const Icon(Icons.star, size: 14, color: Color(0xFFC2941B)),
              const SizedBox(width: 4),
              Text(
                review.rating,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF334155),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            review.text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: const Color(0xFF475569),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildAddButton(String title, String priceStr, {bool isSmall = false, bool isPill = false}) {
    final qty = _getQuantity(title);
    
    if (qty > 0) {
      if (isSmall) {
        // Just the circle for small combo card? No, combo card small add button usually expands or becomes a small pill
        // Let's make it a small pill for consistency in small spaces
        return Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF16A34A),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
               InkWell(onTap: () => _updateQuantity(title, -1), child: const Icon(Icons.remove, size: 16, color: Colors.white)),
               const SizedBox(width: 4),
               Text('$qty', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
               const SizedBox(width: 4),
               InkWell(onTap: () => _updateQuantity(title, 1), child: const Icon(Icons.add, size: 16, color: Colors.white)),
            ],
          ),
        );
      }
      
      return Container(
        height: isPill ? 36 : 40,
        padding: const EdgeInsets.symmetric(horizontal: 4), // Reduced padding
        decoration: BoxDecoration(
          color: const Color(0xFF16A34A),
          borderRadius: BorderRadius.circular( isPill ? 18 : 20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF16A34A).withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 3)
            )
          ]
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => _updateQuantity(title, -1),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Icon(Icons.remove, size: 18, color: Colors.white),
              ),
            ),
            Container(
              constraints: const BoxConstraints(minWidth: 16), // Reduced min width
              alignment: Alignment.center,
              child: Text(
                '$qty',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
             InkWell(
              onTap: () => _updateQuantity(title, 1),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Icon(Icons.add, size: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    // Default ADD State
    if (isSmall) {
      return GestureDetector(
        onTap: () => _updateQuantity(title, 1),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
             color: Colors.white,
             shape: BoxShape.circle,
             border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Icon(Icons.add, size: 20, color: Color(0xFF16A34A)),
        ),
      );
    }
    
    return ElevatedButton(
      onPressed: () => _updateQuantity(title, 1),
      style: ElevatedButton.styleFrom(
        backgroundColor: isPill ? Colors.white : const Color(0xFF16A34A),
        foregroundColor: isPill ? const Color(0xFF16A34A) : Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: isPill ? const BorderSide(color: Color(0xFFE2E8F0)) : BorderSide.none
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
        elevation: isPill ? 2 : 2,
        minimumSize: Size(0, isPill ? 36 : 40),
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text('ADD'),
          SizedBox(width: 4),
          Icon(Icons.add, size: 18),
        ],
      ),
    );
  }
}

class _MenuHeaderDelegate extends SliverPersistentHeaderDelegate {
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      alignment: Alignment.centerLeft,
      child: Text(
        'Food Menu',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF0F172A),
        ),
      ),
    );
  }

  @override
  double get maxExtent => 52;

  @override
  double get minExtent => 52;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => false;
}

// Add StickyHeader helper
class StickyHeader extends StatelessWidget {
  final Widget child;
  const StickyHeader({super.key, required this.child});
  
  @override
  Widget build(BuildContext context) {
    // Basic wrapper, real sticky behavior needs SliverPersistentHeader or specific pkg
    return Container(
       color: Colors.white,
       child: child,
    );
  }
}
