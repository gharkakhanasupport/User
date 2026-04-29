import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import 'cart_screen.dart';
import '../services/menu_service.dart';
import '../models/daily_menu_item.dart';
import '../models/menu_item.dart';
import '../theme/app_colors.dart';

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
  final Future<Map<String, dynamic>>? preloadedMenuFuture;

  const KitchenDetailScreen({
    super.key,
    required this.kitchenName,
    required this.kitchenSubtitle,
    required this.rating,
    required this.ratingCount,
    required this.imageUrl,
    required this.tag,
    required this.time,
    this.cookId,
    this.isVeg = true,
    this.kitchenPhotos = const [],
    this.preloadedMenuFuture,
  });

  @override
  State<KitchenDetailScreen> createState() => _KitchenDetailScreenState();
}

class _KitchenDetailScreenState extends State<KitchenDetailScreen> {
  final MenuService _menuService = MenuService();
  String _selectedCategory = 'Lunch';
  bool _isLoading = true;
  
  // Real Data
  List<UserDailyMenuItem> _dailyMenuItems = [];
  List<UserMenuItem> _standardMenuItems = [];
  
  // Cart State
  final Map<String, int> _cartQuantities = {};
  final Map<String, int> _itemPricesCache = {};
  final Map<String, String> _itemImagesCache = {};

  @override
  void initState() {
    super.initState();
    _determineInitialCategory();
    _loadMenuData();
  }

  void _determineInitialCategory() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 11) {
      _selectedCategory = 'Breakfast';
    } else if (hour >= 11 && hour < 16) {
      _selectedCategory = 'Lunch';
    } else if (hour >= 16 && hour < 19) {
      _selectedCategory = 'Snacks';
    } else if (hour >= 19 && hour < 23) {
      _selectedCategory = 'Dinner';
    } else {
      _selectedCategory = 'Lunch';
    }
  }

  Future<void> _loadMenuData() async {
    setState(() => _isLoading = true);
    try {
      if (widget.preloadedMenuFuture != null) {
        final results = await widget.preloadedMenuFuture!;
        _dailyMenuItems = results['daily'] ?? [];
        _standardMenuItems = results['regular'] ?? [];
      } else {
        final dailyItems = await _menuService.getTodaysDailyMenu(widget.cookId ?? '');
        final standardItems = await _menuService.getAvailableMenuItems(widget.cookId ?? '');
        _dailyMenuItems = dailyItems;
        _standardMenuItems = standardItems;
      }
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _updateCaches();
        });
      }
    } catch (e) {
      debugPrint('Error loading menu: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updateCaches() {
    _itemPricesCache.clear();
    _itemImagesCache.clear();
    for (var item in _dailyMenuItems) {
      _itemPricesCache[item.name] = item.price.toInt();
      _itemImagesCache[item.name] = item.imageUrl ?? '';
    }
    for (var item in _standardMenuItems) {
      _itemPricesCache[item.name] = item.price.toInt();
      _itemImagesCache[item.name] = item.imageUrl ?? '';
    }
  }

  void _updateQuantity(String name, int quantity) {
    if (quantity < 0) return;
    setState(() {
      if (quantity == 0) {
        _cartQuantities.remove(name);
      } else {
        _cartQuantities[name] = quantity;
      }
    });
  }

  int get _cartCount => _cartQuantities.values.fold(0, (sum, q) => sum + q);
  
  double get _totalPrice {
    double total = 0;
    _cartQuantities.forEach((name, qty) {
      total += (_itemPricesCache[name] ?? 0) * qty;
    });
    return total;
  }

  void _navigateToCart() {
    // Build the maps CartScreen expects
    final Map<String, String> itemNames = {};
    final Map<String, String> itemImages = {};
    final Map<String, int> itemPrices = {};

    for (final entry in _cartQuantities.entries) {
      itemNames[entry.key] = entry.key;
      itemImages[entry.key] = _itemImagesCache[entry.key] ?? '';
      itemPrices[entry.key] = _itemPricesCache[entry.key] ?? 0;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CartScreen(
          cartItems: Map<String, int>.from(_cartQuantities),
          itemPrices: itemPrices,
          itemImages: itemImages,
          itemNames: itemNames,
          kitchenName: widget.kitchenName,
          cookId: widget.cookId ?? '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildAppBar(),
              _buildKitchenInfo(),
              _buildCategoryTabs(),
              _buildMenuList(),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
          _buildFloatingCart(),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              widget.imageUrl.isNotEmpty ? widget.imageUrl : 'https://images.unsplash.com/photo-1504674900247-0877df9cc836',
              fit: BoxFit.cover,
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.4),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKitchenInfo() {
    return SliverToBoxAdapter(
      child: Transform.translate(
        offset: const Offset(0, -30),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.kitchenName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Text(
                          widget.rating,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.star, color: Colors.white, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.kitchenSubtitle.isNotEmpty ? widget.kitchenSubtitle : 'Delicious home-cooked meals',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildInfoItem(Icons.timer_outlined, widget.time.isNotEmpty ? widget.time : '30-45 mins'),
                  const SizedBox(width: 20),
                  _buildInfoItem(Icons.location_on_outlined, '2.5 km'),
                  const SizedBox(width: 20),
                  _buildInfoItem(Icons.currency_rupee, '100 for one'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFFC2941B)),
        const SizedBox(width: 6),
        Text(
          text,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF475569),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryTabs() {
    final categories = ['Breakfast', 'Lunch', 'Snacks', 'Dinner', 'Menu'];
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SliverAppBarDelegate(
        minHeight: 65,
        maxHeight: 65,
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final isSelected = _selectedCategory == categories[index];
              return GestureDetector(
                onTap: () => setState(() => _selectedCategory = categories[index]),
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ] : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    categories[index],
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : const Color(0xFF475569),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMenuList() {
    if (_isLoading) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    List<Widget> items = [];
    
    if (_selectedCategory == 'Menu') {
      for (var item in _standardMenuItems) {
        items.add(_buildMenuItemCard(
          item.name,
          item.description ?? '',
          '₹${item.price}',
          item.imageUrl ?? '',
          item.isVeg,
        ));
      }
    } else {
      final filteredItems = _dailyMenuItems.where((item) => 
        item.category.toLowerCase() == _selectedCategory.toLowerCase()
      ).toList();
      
      if (filteredItems.isEmpty) {
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 60),
            child: Column(
              children: [
                Icon(Icons.no_meals_outlined, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'No items available for $_selectedCategory',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.grey[500],
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        for (var item in filteredItems) {
          items.add(_buildMenuItemCard(
            item.name,
            item.description ?? '',
            '₹${item.price}',
            item.imageUrl ?? '',
            item.isVeg,
          ));
        }
      }
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => items[index],
        childCount: items.length,
      ),
    );
  }

  Widget _buildMenuItemCard(String name, String desc, String price, String img, bool isVeg) {
    final quantity = _cartQuantities[name] ?? 0;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    border: Border.all(color: isVeg ? Colors.green : Colors.red),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    Icons.circle,
                    color: isVeg ? Colors.green : Colors.red,
                    size: 8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  price,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  desc,
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF64748B),
                    fontSize: 13,
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  img.isNotEmpty ? img : 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c',
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 120,
                    height: 120,
                    color: const Color(0xFFF1F5F9),
                    child: const Icon(Icons.fastfood, color: Color(0xFFCBD5E1), size: 40),
                  ),
                ),
              ),
              Positioned(
                bottom: -15,
                child: Container(
                  height: 38,
                  width: 100,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: quantity == 0
                      ? TextButton(
                          onPressed: () => _updateQuantity(name, 1),
                          child: Text(
                            'ADD',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 18, color: AppColors.primary),
                              onPressed: () => _updateQuantity(name, quantity - 1),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            Text(
                              '$quantity',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                                fontSize: 15,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 18, color: AppColors.primary),
                              onPressed: () => _updateQuantity(name, quantity + 1),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingCart() {
    if (_cartCount == 0) return const SizedBox.shrink();

    return Positioned(
      bottom: 24,
      left: 16,
      right: 16,
      child: GestureDetector(
        onTap: _navigateToCart,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4CAF50), Color(0xFF388E3C)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.shopping_basket, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$_cartCount ITEMS',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        '₹${_totalPrice.toStringAsFixed(0)}',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    'VIEW CART',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  final double minHeight;
  final double maxHeight;
  final Widget child;

  @override
  double get minExtent => minHeight;
  @override
  double get maxExtent => max(maxHeight, minHeight);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}
