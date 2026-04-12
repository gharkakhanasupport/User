import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'kitchen_subscription_screen.dart';
import 'cart_screen.dart';
import '../services/menu_service.dart';
import '../models/menu_item.dart';
import '../models/daily_menu_item.dart';

class KitchenDetailScreen extends StatefulWidget {
  final String kitchenName;
  final String kitchenSubtitle;
  final String rating;
  final String ratingCount;
  final String imageUrl;
  final String tag;
  final String time;
  final String? cookId;
  final bool isVeg;
  final List<String> kitchenPhotos;

  const KitchenDetailScreen({
    super.key,
    required this.kitchenName,
    required this.kitchenSubtitle,
    required this.rating,
    required this.ratingCount,
    required this.imageUrl,
    required this.tag,
    required this.time,
    required this.isVeg,
    this.cookId,
    this.kitchenPhotos = const [],
  });

  @override
  State<KitchenDetailScreen> createState() => _KitchenDetailScreenState();
}

class _KitchenDetailScreenState extends State<KitchenDetailScreen> {
  final MenuService _menuService = MenuService();
  final PageController _photoController = PageController();
  int _currentPhotoIndex = 0;

  // Meal category filter for daily menu
  String _selectedMealFilter = 'all';

  // Cart State
  final Map<String, int> _cartQuantities = {};
  final Map<String, double> _cartPrices = {};
  final Map<String, String> _cartImages = {};

  int get _cartItemCount => _cartQuantities.values.fold(0, (sum, qty) => sum + qty);

  double get _cartTotal {
    double total = 0;
    _cartQuantities.forEach((id, qty) {
      total += (_cartPrices[id] ?? 0) * qty;
    });
    return total;
  }

  int _getQuantity(String id) => _cartQuantities[id] ?? 0;

  void _updateQuantity(String id, String name, double price, String? imageUrl, int delta) {
    setState(() {
      final newQty = (_cartQuantities[id] ?? 0) + delta;
      if (newQty <= 0) {
        _cartQuantities.remove(id);
        _cartPrices.remove(id);
        _cartImages.remove(id);
      } else {
        _cartQuantities[id] = newQty;
        _cartPrices[id] = price;
        if (imageUrl != null) _cartImages[id] = imageUrl;
      }
    });
  }

  String get _todayDateStr {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _photoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveCookId = (widget.cookId != null && widget.cookId!.isNotEmpty) ? widget.cookId! : '';
    final hasCookId = effectiveCookId.isNotEmpty;
    debugPrint('KitchenDetailScreen: cookId="${widget.cookId}", effectiveCookId="$effectiveCookId", hasCookId=$hasCookId');

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // App Bar
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
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: Container(
                              width: 12, height: 12,
                              decoration: BoxDecoration(
                                color: widget.isVeg ? const Color(0xFF16A34A) : Colors.red, 
                                shape: BoxShape.circle
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(widget.isVeg ? 'Veg' : 'Non-Veg', style: GoogleFonts.plusJakartaSans(
                            fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF475569),
                          )),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(1.0),
                  child: Container(color: const Color(0xFFF1F5F9), height: 1.0),
                ),
              ),

              // Kitchen Photos Gallery
              if (widget.kitchenPhotos.isNotEmpty)
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      SizedBox(
                        height: 200,
                        child: PageView.builder(
                          controller: _photoController,
                          itemCount: widget.kitchenPhotos.length,
                          onPageChanged: (i) => setState(() => _currentPhotoIndex = i),
                          itemBuilder: (context, index) {
                            return Image.network(
                              widget.kitchenPhotos[index],
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (_, __, ___) => Container(
                                color: const Color(0xFFF1F5F9),
                                child: const Icon(Icons.restaurant, size: 48, color: Color(0xFF94A3B8)),
                              ),
                            );
                          },
                        ),
                      ),
                      if (widget.kitchenPhotos.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(widget.kitchenPhotos.length, (i) => Container(
                              width: i == _currentPhotoIndex ? 20 : 6,
                              height: 6,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                color: i == _currentPhotoIndex ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            )),
                          ),
                        ),
                    ],
                  ),
                ),

              // Hero Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  child: Column(
                    children: [
                      if (widget.kitchenPhotos.isEmpty) ...[
                        Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white, shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 4))],
                              ),
                              child: CircleAvatar(radius: 48, backgroundImage: NetworkImage(widget.imageUrl)),
                            ),
                            Positioned(
                              bottom: 0, right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white, shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFFF1F5F9)),
                                ),
                                child: const Icon(Icons.verified, color: Color(0xFF16A34A), size: 20),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      Text(widget.kitchenName, style: GoogleFonts.plusJakartaSans(
                        fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A),
                      )),
                      const SizedBox(height: 4),
                      Text(widget.kitchenSubtitle, style: GoogleFonts.plusJakartaSans(
                        fontSize: 14, fontWeight: FontWeight.w500, color: const Color(0xFF64748B),
                      )),
                      const SizedBox(height: 24),

                      Wrap(
                        alignment: WrapAlignment.center, spacing: 12, runSpacing: 12,
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
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => KitchenSubscriptionScreen(
                          kitchenName: widget.kitchenName, imageUrl: widget.imageUrl,
                          price: '\u20B93,500', rating: widget.rating,
                        ),
                      ));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFDCFCE7), Color(0xFFF0FDF4)]),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                        boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              child: const Icon(Icons.card_membership, color: Color(0xFF16A34A)),
                            ),
                            const SizedBox(width: 12),
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Subscribe & Save', style: GoogleFonts.plusJakartaSans(
                                fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF14532D),
                              )),
                              Text('Plans starting at \u20B9850/week', style: GoogleFonts.plusJakartaSans(
                                fontSize: 12, color: const Color(0xFF166534),
                              )),
                            ]),
                          ]),
                          const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF166534)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ─── Today's Daily Menu (Real-time) ───────────────────────
              if (hasCookId)
                StreamBuilder<List<UserDailyMenuItem>>(
                  stream: _menuService.getDailyMenuStream(effectiveCookId, _todayDateStr),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      debugPrint('Daily menu stream error: ${snapshot.error}');
                      return const SliverToBoxAdapter(child: SizedBox.shrink());
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator(color: Color(0xFF16A34A), strokeWidth: 2)),
                        ),
                      );
                    }

                    final dailyItems = snapshot.data ?? [];
                    if (dailyItems.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: _buildEmptySection('No daily specials today', Icons.restaurant_menu),
                        ),
                      );
                    }

                    final specials = dailyItems.where((d) => d.category == 'special' && d.isAvailable).toList();
                    final nonSpecials = dailyItems.where((d) => d.category != 'special' && d.isAvailable).toList();

                    // Apply meal filter
                    final filteredItems = _selectedMealFilter == 'all'
                        ? nonSpecials
                        : nonSpecials.where((d) => d.category == _selectedMealFilter).toList();

                    // Get available categories for filter tabs
                    final availableCategories = nonSpecials.map((e) => e.category).toSet();

                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Today's Special (always visible)
                            if (specials.isNotEmpty) ...[
                              Text("Today's Special", style: GoogleFonts.plusJakartaSans(
                                fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A),
                              )),
                              const SizedBox(height: 12),
                              _buildDailySpecialCard(specials.first),
                              const SizedBox(height: 24),
                            ],

                            // Meal Category Filter Tabs
                            if (nonSpecials.isNotEmpty) ...[
                              Row(
                                children: [
                                  Text("Today's Menu", style: GoogleFonts.plusJakartaSans(
                                    fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A),
                                  )),
                                  const Spacer(),
                                  Text('${filteredItems.length} items', style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12, color: const Color(0xFF94A3B8),
                                  )),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Filter pills
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildMealFilterChip('All', 'all', true),
                                    if (availableCategories.contains('breakfast'))
                                      _buildMealFilterChip('Breakfast', 'breakfast', true),
                                    if (availableCategories.contains('lunch'))
                                      _buildMealFilterChip('Lunch', 'lunch', true),
                                    if (availableCategories.contains('dinner'))
                                      _buildMealFilterChip('Dinner', 'dinner', true),
                                    if (availableCategories.contains('snacks'))
                                      _buildMealFilterChip('Snacks', 'snacks', true),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Filtered Items
                              if (filteredItems.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 24),
                                  child: Center(
                                    child: Text(
                                      'No ${_selectedMealFilter} items for today',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13, color: const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ),
                                )
                              else
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  clipBehavior: Clip.none,
                                  child: Row(
                                    children: filteredItems.map((item) => Padding(
                                      padding: const EdgeInsets.only(right: 16),
                                      child: _buildDailyItemCard(item),
                                    )).toList(),
                                  ),
                                ),
                              const SizedBox(height: 24),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),

              // ─── Food Menu Header ────────────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Food Menu', style: GoogleFonts.plusJakartaSans(
                        fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A),
                      )),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.search, size: 16, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 6),
                          Text('Search', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF94A3B8))),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Regular Menu (Real-time) ─────────────────────────────
              if (hasCookId)
                StreamBuilder<List<UserMenuItem>>(
                  stream: _menuService.getAvailableMenuStream(effectiveCookId),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      debugPrint('Menu stream error: ${snapshot.error}');
                      return SliverToBoxAdapter(
                        child: _buildEmptySection('Menu coming soon', Icons.lunch_dining),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator(color: Color(0xFF16A34A), strokeWidth: 2)),
                        ),
                      );
                    }

                    final items = snapshot.data ?? [];
                    if (items.isEmpty) {
                      return SliverToBoxAdapter(
                        child: _buildEmptySection('Menu coming soon', Icons.lunch_dining),
                      );
                    }

                    // Group by category
                    final grouped = <String, List<UserMenuItem>>{};
                    for (final item in items) {
                      grouped.putIfAbsent(item.category, () => []).add(item);
                    }

                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final category = grouped.keys.elementAt(index);
                          final categoryItems = grouped[category]!;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                                child: Text(
                                  category.isNotEmpty ? category[0].toUpperCase() + category.substring(1) : 'Menu',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14, fontWeight: FontWeight.bold,
                                    color: const Color(0xFF64748B), letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              ...categoryItems.map((item) => _buildRealMenuItem(item)),
                            ],
                          );
                        },
                        childCount: grouped.length,
                      ),
                    );
                  },
                ),

              // No cook ID fallback
              if (!hasCookId)
                SliverToBoxAdapter(
                  child: _buildEmptySection('Menu coming soon', Icons.lunch_dining),
                ),

              // Reviews Section (placeholder - kept from original)
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(top: 16),
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
                          Text('What Neighbours Say', style: GoogleFonts.plusJakartaSans(
                            fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A),
                          )),
                          Text('View all', style: GoogleFonts.plusJakartaSans(
                            fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A),
                          )),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Rate Input
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white, borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Rate your experience', style: GoogleFonts.plusJakartaSans(
                              fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B),
                            )),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(5, (i) => const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Icon(Icons.star, color: Color(0xFFCBD5E1), size: 32),
                              )),
                            ),
                            const SizedBox(height: 16),
                            Row(children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Text('Write a review...', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8))),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16A34A), shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(color: const Color(0xFF16A34A).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                                ),
                                child: const Icon(Icons.send, color: Colors.white, size: 20),
                              ),
                            ]),
                          ],
                        ),
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Cart Popup
          if (_cartItemCount > 0)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -4))],
                ),
                child: SafeArea(
                  top: false,
                  child: GestureDetector(
                    onTap: () {
                      // Convert to cart screen format
                      final cartItems = <String, int>{};
                      final itemPrices = <String, int>{};
                      final itemImages = <String, String>{};
                      _cartQuantities.forEach((id, qty) {
                        // Use price lookup name for cart
                        final name = id; // IDs are used as keys
                        cartItems[name] = qty;
                        itemPrices[name] = (_cartPrices[id] ?? 0).toInt();
                        if (_cartImages[id] != null) itemImages[name] = _cartImages[id]!;
                      });
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => CartScreen(
                          cartItems: cartItems, itemPrices: itemPrices,
                          itemImages: itemImages, kitchenName: widget.kitchenName,
                        ),
                      ));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A), borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: const Color(0xFF16A34A).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$_cartItemCount ITEMS', style: GoogleFonts.plusJakartaSans(
                                fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white.withOpacity(0.8),
                              )),
                              Text('\u20B9${_cartTotal.toStringAsFixed(0)}', style: GoogleFonts.plusJakartaSans(
                                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white,
                              )),
                            ],
                          ),
                          Row(children: [
                            Text('View Cart', style: GoogleFonts.plusJakartaSans(
                              fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white,
                            )),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_right_alt, color: Colors.white),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Widget Builders ──────────────────────────────────────────────────

  Widget _buildEmptySection(String message, IconData icon) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 48, color: const Color(0xFFCBD5E1)),
            const SizedBox(height: 12),
            Text(message, style: GoogleFonts.plusJakartaSans(
              fontSize: 14, color: const Color(0xFF94A3B8),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildDailySpecialCard(UserDailyMenuItem special) {
    final id = special.id;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCFCE7)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 96, height: 96,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: special.imageUrl != null ? DecorationImage(
                      image: NetworkImage(special.imageUrl!), fit: BoxFit.cover,
                    ) : null,
                    color: const Color(0xFFF1F5F9),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
                  ),
                  child: special.imageUrl == null ? const Icon(Icons.restaurant, color: Color(0xFF94A3B8)) : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(special.name, style: GoogleFonts.plusJakartaSans(
                        fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A),
                      )),
                      const SizedBox(height: 4),
                      Text(special.description ?? 'Today\'s special from the kitchen',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF475569), height: 1.5),
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('\u20B9${special.price.toStringAsFixed(0)}', style: GoogleFonts.plusJakartaSans(
                            fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A),
                          )),
                          _buildAddBtn(id, special.name, special.price, special.imageUrl),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: const BoxDecoration(
                color: Color(0xFFC2941B),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(8)),
              ),
              child: Text('SPECIAL', style: GoogleFonts.plusJakartaSans(
                fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white,
              )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyItemCard(UserDailyMenuItem item) {
    final id = item.id;
    return Container(
      width: 280,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(children: [
            Container(
              height: 128,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: item.imageUrl != null ? DecorationImage(
                  image: NetworkImage(item.imageUrl!), fit: BoxFit.cover,
                ) : null,
                color: const Color(0xFFF1F5F9),
              ),
              child: item.imageUrl == null ? const Center(child: Icon(Icons.restaurant, size: 32, color: Color(0xFF94A3B8))) : null,
            ),
            Positioned(
              top: 8, left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Row(children: [
                  const Icon(Icons.local_offer, size: 12, color: Color(0xFFC2941B)),
                  const SizedBox(width: 4),
                  Text(item.quantity > 5 ? 'POPULAR' : 'LIMITED', style: GoogleFonts.plusJakartaSans(
                    fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFC2941B),
                  )),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Text(item.name, style: GoogleFonts.plusJakartaSans(
            fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A),
          )),
          const SizedBox(height: 4),
          Text(item.categoryName, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF64748B))),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('\u20B9${item.price.toStringAsFixed(0)}', style: GoogleFonts.plusJakartaSans(
                fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A),
              )),
              _buildAddBtn(id, item.name, item.price, item.imageUrl, isSmall: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRealMenuItem(UserMenuItem item) {
    final id = item.id;
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF8FAFC)))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    margin: const EdgeInsets.only(top: 4, right: 8),
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF16A34A)), borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.circle, size: 8, color: Color(0xFF16A34A)),
                  ),
                  Expanded(child: Text(item.name, style: GoogleFonts.plusJakartaSans(
                    fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A),
                  ))),
                ]),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Text(item.description ?? 'Freshly prepared with love',
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, color: const Color(0xFF64748B), height: 1.5),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Text('\u20B9${item.price.toStringAsFixed(0)}', style: GoogleFonts.plusJakartaSans(
                    fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A),
                  )),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 112, height: 112,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: item.imageUrl != null ? DecorationImage(image: NetworkImage(item.imageUrl!), fit: BoxFit.cover) : null,
                  color: const Color(0xFFF1F5F9),
                ),
                child: item.imageUrl == null ? const Icon(Icons.restaurant, color: Color(0xFF94A3B8)) : null,
              ),
              Positioned(
                bottom: -12, left: 0, right: 0,
                child: Center(child: _buildAddBtn(id, item.name, item.price, item.imageUrl, isPill: true)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddBtn(String id, String name, double price, String? imageUrl, {bool isSmall = false, bool isPill = false}) {
    final qty = _getQuantity(id);

    if (qty > 0) {
      return Container(
        height: isSmall ? 32 : (isPill ? 36 : 40),
        padding: EdgeInsets.symmetric(horizontal: isSmall ? 6 : 4),
        decoration: BoxDecoration(
          color: const Color(0xFF16A34A),
          borderRadius: BorderRadius.circular(isSmall ? 16 : (isPill ? 18 : 20)),
          boxShadow: [BoxShadow(color: const Color(0xFF16A34A).withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => _updateQuantity(id, name, price, imageUrl, -1),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isSmall ? 4 : 8, vertical: 4),
                child: Icon(Icons.remove, size: isSmall ? 16 : 18, color: Colors.white),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text('$qty', style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: isSmall ? 12 : 14,
              )),
            ),
            InkWell(
              onTap: () => _updateQuantity(id, name, price, imageUrl, 1),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isSmall ? 4 : 8, vertical: 4),
                child: Icon(Icons.add, size: isSmall ? 16 : 18, color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    if (isPill) {
      return GestureDetector(
        onTap: () => _updateQuantity(id, name, price, imageUrl, 1),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF16A34A)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: Center(child: Text('ADD', style: GoogleFonts.plusJakartaSans(
            fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A),
          ))),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _updateQuantity(id, name, price, imageUrl, 1),
      child: Container(
        height: isSmall ? 32 : 40,
        padding: EdgeInsets.symmetric(horizontal: isSmall ? 16 : 24),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(isSmall ? 16 : 20),
          border: Border.all(color: const Color(0xFF16A34A)),
        ),
        child: Center(child: Text('ADD', style: GoogleFonts.plusJakartaSans(
          fontSize: isSmall ? 12 : 14, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A),
        ))),
      ),
    );
  }

  Widget _buildTag(IconData icon, String label, String sub, Color iconColor, Color bgColor, {Color? fgColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor, borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.plusJakartaSans(
            fontSize: 14, fontWeight: FontWeight.bold, color: fgColor ?? const Color(0xFF1E293B),
          )),
          if (sub.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(sub, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF64748B))),
          ],
        ],
      ),
    );
  }

  Widget _buildMealFilterChip(String label, String value, bool showToAll) {
    final isActive = _selectedMealFilter == value;
    const Map<String, Color> categoryColors = {
      'all': Color(0xFF16A34A),
      'breakfast': Color(0xFFFF9800),
      'lunch': Color(0xFF4CAF50),
      'dinner': Color(0xFF3F51B5),
      'snacks': Color(0xFF9C27B0),
    };
    final color = categoryColors[value] ?? const Color(0xFF16A34A);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selectedMealFilter = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? color : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20),
            border: isActive ? null : Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: isActive
                ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))]
                : null,
          ),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: isActive ? Colors.white : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }
}


// Sticky "Food Menu" header delegate
class _MenuHeaderDelegate extends SliverPersistentHeaderDelegate {
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Food Menu', style: GoogleFonts.plusJakartaSans(
            fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A),
          )),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(children: [
              const Icon(Icons.search, size: 16, color: Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Text('Search', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF94A3B8))),
            ]),
          ),
        ],
      ),
    );
  }

  @override
  double get maxExtent => 56;
  @override
  double get minExtent => 56;
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => false;
}

class StickyHeader extends StatelessWidget {
  final Widget child;
  const StickyHeader({super.key, required this.child});

  @override
  Widget build(BuildContext context) => child;
}
