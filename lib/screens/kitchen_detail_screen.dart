import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import 'cart_screen.dart';
import '../services/menu_service.dart';
import '../models/daily_menu_item.dart';
import '../models/menu_item.dart';
import '../theme/app_colors.dart';
import '../utils/deep_link_helper.dart';
import '../widgets/skeleton_loaders.dart';

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
  String _selectedCategory = 'All';
  bool _isLoading = true;

  List<UserDailyMenuItem> _dailyMenuItems = [];
  List<UserMenuItem> _standardMenuItems = [];
  List<String> _availableCategories = ['All'];

  final Map<String, int> _cartQuantities = {};
  final Map<String, int> _itemPricesCache = {};
  final Map<String, String> _itemImagesCache = {};
  final Map<String, String> _itemIdCache = {};

  @override
  void initState() {
    super.initState();
    _loadMenuData();
  }

  Future<void> _loadMenuData() async {
    setState(() => _isLoading = true);
    try {
      if (widget.preloadedMenuFuture != null) {
        final results = await widget.preloadedMenuFuture!;
        _dailyMenuItems = results['daily'] ?? [];
        _standardMenuItems = results['regular'] ?? [];
      } else {
        _dailyMenuItems = await _menuService.getTodaysDailyMenu(widget.cookId ?? '');
        _standardMenuItems = await _menuService.getAvailableMenuItems(widget.cookId ?? '');
      }
      debugPrint('KitchenDetail: ${_dailyMenuItems.length} daily, ${_standardMenuItems.length} standard');
      if (mounted) setState(() { _isLoading = false; _updateCaches(); _buildCategoryList(); });
    } catch (e) {
      debugPrint('Error loading menu: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _buildCategoryList() {
    final cats = <String>{'All'};
    for (var item in _dailyMenuItems) {
      if (item.category.isNotEmpty) cats.add(_fmt(item.category));
    }
    for (var item in _standardMenuItems) {
      if (item.category.isNotEmpty) cats.add(_fmt(item.category));
    }
    _availableCategories = cats.toList();
    _selectedCategory = 'All';
  }

  String _fmt(String raw) {
    const map = {
      'main_course': 'Main Course', 'rice': 'Rice', 'breads': 'Breads',
      'sides': 'Sides', 'desserts': 'Desserts', 'beverages': 'Beverages',
      'breakfast': 'Breakfast', 'lunch': 'Lunch', 'dinner': 'Dinner',
      'snacks': 'Snacks', 'special': 'Specials', 'starters': 'Starters', 'thali': 'Thali',
    };
    return map[raw.toLowerCase()] ?? raw.split('_').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');
  }

  bool _catMatch(String raw) => _selectedCategory == 'All' || _fmt(raw) == _selectedCategory;

  void _updateCaches() {
    _itemPricesCache.clear(); _itemImagesCache.clear(); _itemIdCache.clear();
    for (var i in _dailyMenuItems) { _itemPricesCache[i.name] = i.price.toInt(); _itemImagesCache[i.name] = i.imageUrl ?? ''; _itemIdCache[i.name] = i.id; }
    for (var i in _standardMenuItems) { _itemPricesCache[i.name] = i.price.toInt(); _itemImagesCache[i.name] = i.imageUrl ?? ''; _itemIdCache[i.name] = i.id; }
  }

  void _updateQty(String name, int qty) {
    if (qty < 0) return;
    setState(() {
      if (qty == 0) {
        _cartQuantities.remove(name);
      } else {
        _cartQuantities[name] = qty;
      }
    });
  }

  int get _cartCount => _cartQuantities.values.fold(0, (s, q) => s + q);
  double get _totalPrice { double t = 0; _cartQuantities.forEach((n, q) { t += (_itemPricesCache[n] ?? 0) * q; }); return t; }

  void _navigateToCart() {
    final Map<String, String> names = {}, images = {};
    final Map<String, int> prices = {};
    for (final e in _cartQuantities.entries) { names[e.key] = e.key; images[e.key] = _itemImagesCache[e.key] ?? ''; prices[e.key] = _itemPricesCache[e.key] ?? 0; }
    Navigator.push(context, MaterialPageRoute(builder: (_) => CartScreen(cartItems: Map.from(_cartQuantities), itemPrices: prices, itemImages: images, itemNames: names, kitchenName: widget.kitchenName, cookId: widget.cookId ?? '')));
  }

  void _shareKitchen() => DeepLinkHelper.shareKitchen(kitchenName: widget.kitchenName, cookId: widget.cookId ?? '', description: widget.kitchenSubtitle);

  void _shareItem(String name, double price, String itemId) => DeepLinkHelper.shareItem(itemName: name, itemId: itemId, cookId: widget.cookId ?? '', kitchenName: widget.kitchenName, price: price);

  void _showKitchenInfo() {
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (_) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),
        Text(widget.kitchenName, style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(widget.kitchenSubtitle.isNotEmpty ? widget.kitchenSubtitle : 'Delicious home-cooked meals', style: GoogleFonts.plusJakartaSans(fontSize: 15, color: const Color(0xFF64748B))),
        const SizedBox(height: 16), const Divider(),
        _infoRow(Icons.star_rounded, 'Rating', '${widget.rating} (${widget.ratingCount})'),
        _infoRow(Icons.timer_outlined, 'Delivery', widget.time.isNotEmpty ? widget.time : '30-45 mins'),
        _infoRow(Icons.restaurant_menu, 'Menu Items', '${_standardMenuItems.length} items'),
        _infoRow(Icons.eco_outlined, 'Type', widget.isVeg ? 'Pure Vegetarian' : 'Veg & Non-Veg'),
        const SizedBox(height: 16),
      ]),
    ));
  }

  Widget _infoRow(IconData ic, String label, String val) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [Icon(ic, size: 20, color: AppColors.primary), const SizedBox(width: 12), Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 14, color: const Color(0xFF64748B))), const Spacer(), Text(val, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600))]),
  );

  Future<void> _onRefresh() async {
    _dailyMenuItems = [];
    _standardMenuItems = [];
    await _loadMenuData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(children: [
        RefreshIndicator(
          onRefresh: _onRefresh,
          color: AppColors.primary,
          backgroundColor: Colors.white,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              _buildAppBar(), _buildKitchenInfo(), _buildCategoryTabs(),
              if (!_isLoading) _buildDailyMenuSection(),
              _buildMenuList(),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
        _buildFloatingCart(),
      ]),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 250, pinned: true, elevation: 0, backgroundColor: Colors.white,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), shape: BoxShape.circle),
        child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
      ),
      actions: [
        Container(margin: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), shape: BoxShape.circle),
          child: IconButton(icon: const Icon(Icons.info_outline, color: Colors.white, size: 20), onPressed: _showKitchenInfo)),
        Container(margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), shape: BoxShape.circle),
          child: IconButton(icon: const Icon(Icons.share_rounded, color: Colors.white, size: 20), onPressed: _shareKitchen)),
      ],
      flexibleSpace: FlexibleSpaceBar(background: Stack(fit: StackFit.expand, children: [
        Image.network(widget.imageUrl.isNotEmpty ? widget.imageUrl : 'https://images.unsplash.com/photo-1504674900247-0877df9cc836', fit: BoxFit.cover,
          errorBuilder: (_, e, st) => Container(color: const Color(0xFFF1F5F9), child: const Icon(Icons.restaurant, size: 64, color: Color(0xFFCBD5E1)))),
        Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withValues(alpha: 0.4), Colors.transparent, Colors.black.withValues(alpha: 0.7)]))),
      ])),
    );
  }

  Widget _buildKitchenInfo() {
    return SliverToBoxAdapter(child: Transform.translate(offset: const Offset(0, -30), child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 15, offset: const Offset(0, 5))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text(widget.kitchenName, style: GoogleFonts.plusJakartaSans(fontSize: 26, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)))),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: const Color(0xFF16A34A), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [Text(widget.rating, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(width: 4), const Icon(Icons.star, color: Colors.white, size: 16)])),
        ]),
        const SizedBox(height: 8),
        Text(widget.kitchenSubtitle.isNotEmpty ? widget.kitchenSubtitle : 'Delicious home-cooked meals', style: GoogleFonts.plusJakartaSans(fontSize: 15, color: const Color(0xFF64748B))),
        const SizedBox(height: 16), const Divider(), const SizedBox(height: 12),
        Row(children: [
          _buildInfoChip(Icons.timer_outlined, widget.time.isNotEmpty ? widget.time : '30-45 mins'),
          const SizedBox(width: 20), _buildInfoChip(Icons.location_on_outlined, '2.5 km'),
          const SizedBox(width: 20), _buildInfoChip(Icons.currency_rupee, '100 for one'),
        ]),
      ]),
    )));
  }

  Widget _buildInfoChip(IconData icon, String text) => Row(children: [
    Icon(icon, size: 18, color: const Color(0xFFC2941B)), const SizedBox(width: 6),
    Text(text, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
  ]);

  Widget _buildCategoryTabs() {
    return SliverPersistentHeader(pinned: true, delegate: _SliverAppBarDelegate(minHeight: 65, maxHeight: 65,
      child: Container(color: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12),
        child: ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: _availableCategories.length, itemBuilder: (_, i) {
          final cat = _availableCategories[i]; final sel = _selectedCategory == cat;
          return GestureDetector(onTap: () => setState(() => _selectedCategory = cat),
            child: Container(margin: const EdgeInsets.only(right: 12), padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(color: sel ? AppColors.primary : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(30),
                boxShadow: sel ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))] : null),
              alignment: Alignment.center, child: Text(cat, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: sel ? Colors.white : const Color(0xFF475569)))));
        })),
    ));
  }

  /// Daily menu section — shown above standard menu, with graceful empty state
  Widget _buildDailyMenuSection() {
    final filtered = _dailyMenuItems.where((i) => _catMatch(i.category)).toList();

    if (_dailyMenuItems.isEmpty) {
      // No daily menus at all — show a subtle info banner
      return SliverToBoxAdapter(child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFED7AA)),
        ),
        child: Row(children: [
          const Icon(Icons.schedule_rounded, color: Color(0xFFF59E0B), size: 24),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Today's Special Menu", style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF92400E))),
            const SizedBox(height: 2),
            Text('No daily specials posted yet. Check back later!', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFFB45309))),
          ])),
        ]),
      ));
    }

    if (filtered.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildSectionHeader("🔥 Today's Specials"),
      ...filtered.map((item) => _buildMenuItemCard(item.name, item.description ?? '', '₹${item.price.toStringAsFixed(0)}', item.imageUrl ?? '', item.isVeg, !item.isAvailable, item.id, item.price)),
    ]));
  }

  Widget _buildMenuList() {
    if (_isLoading) {
      return SliverToBoxAdapter(
        child: Column(children: List.generate(4, (_) => const MenuItemSkeleton())),
      );
    }

    final filtered = _standardMenuItems.where((i) => _catMatch(i.category)).toList();

    if (filtered.isEmpty && _dailyMenuItems.isEmpty) {
      return SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(children: [
          Icon(Icons.no_meals_outlined, size: 80, color: Colors.grey[300]), const SizedBox(height: 16),
          Text('No items available', style: GoogleFonts.plusJakartaSans(color: Colors.grey[500], fontSize: 16, fontWeight: FontWeight.w500)),
        ])));
    }

    final List<Widget> items = [];
    if (_selectedCategory == 'All') {
      final grouped = <String, List<UserMenuItem>>{};
      for (var i in filtered) {
        grouped.putIfAbsent(_fmt(i.category), () => []).add(i);
      }
      for (final e in grouped.entries) {
        items.add(_buildSectionHeader(e.key));
        for (var i in e.value) {
          items.add(_buildMenuItemCard(i.name, i.description ?? '', '₹${i.price.toStringAsFixed(0)}', i.imageUrl ?? '', i.isVeg, !i.isAvailable, i.id, i.price));
        }
      }
    } else {
      if (filtered.isNotEmpty) items.add(_buildSectionHeader(_selectedCategory));
      for (var i in filtered) {
        items.add(_buildMenuItemCard(i.name, i.description ?? '', '₹${i.price.toStringAsFixed(0)}', i.imageUrl ?? '', i.isVeg, !i.isAvailable, i.id, i.price));
      }
    }

    if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverList(delegate: SliverChildBuilderDelegate((_, i) => items[i], childCount: items.length));
  }

  Widget _buildSectionHeader(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
    child: Row(children: [
      Container(width: 4, height: 20, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 10),
      Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
      const SizedBox(width: 8),
      Expanded(child: Container(height: 1, color: const Color(0xFFE2E8F0))),
    ]),
  );

  Widget _buildMenuItemCard(String name, String desc, String price, String img, bool isVeg, bool unavailable, String itemId, double rawPrice) {
    final qty = _cartQuantities[name] ?? 0;
    return Opacity(opacity: unavailable ? 0.5 : 1.0, child: Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(border: Border.all(color: isVeg ? Colors.green : Colors.red), borderRadius: BorderRadius.circular(4)),
              child: Icon(Icons.circle, color: isVeg ? Colors.green : Colors.red, size: 8)),
            const Spacer(),
            // Share button for item
            GestureDetector(onTap: () => _shareItem(name, rawPrice, itemId),
              child: Icon(Icons.share_outlined, size: 18, color: Colors.grey[400])),
          ]),
          const SizedBox(height: 8),
          Text(name, style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
          const SizedBox(height: 4),
          Text(price, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
          if (desc.isNotEmpty) ...[const SizedBox(height: 10), Text(desc, style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 13, height: 1.5), maxLines: 3, overflow: TextOverflow.ellipsis)],
          if (unavailable) ...[const SizedBox(height: 6), Text('Currently unavailable', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.red[400], fontWeight: FontWeight.w500))],
        ])),
        const SizedBox(width: 16),
        Stack(clipBehavior: Clip.none, alignment: Alignment.bottomCenter, children: [
          ClipRRect(borderRadius: BorderRadius.circular(16),
            child: Image.network(img.isNotEmpty ? img : 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c', width: 120, height: 120, fit: BoxFit.cover,
              errorBuilder: (_, e, st) => Container(width: 120, height: 120, color: const Color(0xFFF1F5F9), child: const Icon(Icons.fastfood, color: Color(0xFFCBD5E1), size: 40)))),
          if (!unavailable) Positioned(bottom: -15, child: Container(height: 38, width: 100,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 3))]),
            child: qty == 0
              ? TextButton(onPressed: () => _updateQty(name, 1), child: Text('ADD', style: GoogleFonts.plusJakartaSans(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14)))
              : Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  IconButton(icon: const Icon(Icons.remove, size: 18, color: AppColors.primary), onPressed: () => _updateQty(name, qty - 1), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                  Text('$qty', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 15)),
                  IconButton(icon: const Icon(Icons.add, size: 18, color: AppColors.primary), onPressed: () => _updateQty(name, qty + 1), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                ]),
          )),
        ]),
      ]),
    ));
  }

  Widget _buildFloatingCart() {
    if (_cartCount == 0) return const SizedBox.shrink();
    return Positioned(bottom: 24, left: 16, right: 16, child: GestureDetector(onTap: _navigateToCart,
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF388E3C)]), borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: const Color(0xFF4CAF50).withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 6))]),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.shopping_basket, color: Colors.white, size: 20)),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('$_cartCount ITEMS', style: GoogleFonts.plusJakartaSans(color: Colors.white.withValues(alpha: 0.9), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              Text('₹${_totalPrice.toStringAsFixed(0)}', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
          ]),
          Row(children: [
            Text('VIEW CART', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(width: 4), const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
          ]),
        ]),
      ),
    ));
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate({required this.minHeight, required this.maxHeight, required this.child});
  final double minHeight, maxHeight;
  final Widget child;
  @override double get minExtent => minHeight;
  @override double get maxExtent => max(maxHeight, minHeight);
  @override Widget build(BuildContext c, double s, bool o) => SizedBox.expand(child: child);
  @override bool shouldRebuild(_SliverAppBarDelegate old) => maxHeight != old.maxHeight || minHeight != old.minHeight || child != old.child;
}
