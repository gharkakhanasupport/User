import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/daily_menu_item.dart';
import '../services/menu_service.dart';
import '../services/kitchen_service.dart';
import '../models/kitchen.dart';

class CategoryPage extends StatefulWidget {
  final String categoryName;

  const CategoryPage({super.key, required this.categoryName});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> with SingleTickerProviderStateMixin {
  final MenuService _menuService = MenuService();
  final KitchenService _kitchenService = KitchenService();

  List<UserDailyMenuItem> _allItems = [];
  List<UserDailyMenuItem> _specials = [];
  Map<String, Kitchen> _kitchenCache = {};
  bool _isLoading = true;

  // Active sub-filter: 'all', 'breakfast', 'lunch', 'dinner', 'snacks'
  late String _activeFilter;

  // Tab labels and their corresponding DB category values
  final List<Map<String, String>> _tabs = [
    {'label': 'All', 'value': 'all'},
    {'label': 'Breakfast', 'value': 'breakfast'},
    {'label': 'Lunch', 'value': 'lunch'},
    {'label': 'Dinner', 'value': 'dinner'},
    {'label': 'Snacks', 'value': 'snacks'},
  ];

  @override
  void initState() {
    super.initState();
    // Set initial filter based on the category from home screen
    _activeFilter = _mapCategoryToFilter(widget.categoryName);
    _loadData();
  }

  /// Map the home category name to our internal filter value
  String _mapCategoryToFilter(String category) {
    switch (category.toLowerCase()) {
      case 'breakfast':
        return 'breakfast';
      case 'lunch':
        return 'lunch';
      case 'dinner':
        return 'dinner';
      case 'snacks':
        return 'snacks';
      default:
        return 'all';
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Fetch all today's items across all kitchens
      final items = await _menuService.getAllTodaysDailyMenuItems();

      // Separate specials (always shown)
      final specials = items.where((i) => i.category == 'special').toList();
      final nonSpecials = items.where((i) => i.category != 'special').toList();

      // Collect unique cook IDs to fetch kitchen names
      final cookIds = items.map((e) => e.cookId).toSet();
      final kitchenMap = <String, Kitchen>{};
      for (final cookId in cookIds) {
        if (cookId.isEmpty) continue;
        try {
          final kitchen = await _kitchenService.getKitchenByCookId(cookId);
          if (kitchen != null) {
            kitchenMap[cookId] = kitchen;
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _allItems = nonSpecials;
          _specials = specials;
          _kitchenCache = kitchenMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('CategoryPage._loadData error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Get filtered items based on active filter
  List<UserDailyMenuItem> get _filteredItems {
    if (_activeFilter == 'all') return _allItems;
    return _allItems.where((i) => i.category == _activeFilter).toList();
  }

  /// Get accent color based on current category
  Color get _accentColor {
    switch (_activeFilter) {
      case 'breakfast':
        return const Color(0xFFFF9800);
      case 'dinner':
        return const Color(0xFF3F51B5);
      case 'snacks':
        return const Color(0xFF9C27B0);
      default: // lunch or all
        return const Color(0xFF4CAF50);
    }
  }

  /// Get gradient for header based on original category
  LinearGradient get _headerGradient {
    switch (widget.categoryName.toLowerCase()) {
      case 'breakfast':
        return const LinearGradient(
          colors: [Color(0xFFFF9800), Color(0xFFFFB74D)],
        );
      case 'dinner':
        return const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF3F51B5)],
        );
      case 'snacks':
        return const LinearGradient(
          colors: [Color(0xFF7B1FA2), Color(0xFFCE93D8)],
        );
      default:
        return const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ─── App Bar ────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Color(0xFF334155), size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
              title: Text(
                "Today's Menu",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: _headerGradient,
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 24, top: 40),
                    child: Icon(
                      _getCategoryIcon(widget.categoryName),
                      size: 56,
                      color: Colors.white.withOpacity(0.25),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ─── Meal Category Filter Tabs ──────────────
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: _tabs.map((tab) {
                    final isActive = _activeFilter == tab['value'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _activeFilter = tab['value']!),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: isActive ? _accentColor : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(24),
                            border: isActive
                                ? null
                                : Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: _accentColor.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isActive) ...[
                                Icon(
                                  _getCategoryIcon(tab['label']!),
                                  size: 16,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                tab['label']!,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                                  color: isActive ? Colors.white : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          // Divider
          const SliverToBoxAdapter(
            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
          ),

          // ─── Loading State ────────────────────────────
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),

          // ─── Content ────────────────────────────
          if (!_isLoading) ...[
            // Today's Specials (always visible)
            if (_specials.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC2941B).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.auto_awesome, size: 18, color: Color(0xFFC2941B)),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "Today's Specials",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC2941B).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '⭐ ${_specials.length} items',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFC2941B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 220,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _specials.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _buildSpecialCard(_specials[index]),
                      );
                    },
                  ),
                ),
              ),
            ],

            // Category items header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getCategoryIcon(_activeFilter == 'all' ? widget.categoryName : _activeFilter),
                        size: 18,
                        color: _accentColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _activeFilter == 'all'
                          ? 'All Items'
                          : '${_activeFilter[0].toUpperCase()}${_activeFilter.substring(1)} Items',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_filteredItems.length} items',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Category items list
            if (_filteredItems.isEmpty)
              SliverToBoxAdapter(
                child: _buildEmptyState(),
              ),

            if (_filteredItems.isNotEmpty)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == _filteredItems.length) {
                      return const SizedBox(height: 24);
                    }
                    return _buildMenuItemCard(_filteredItems[index]);
                  },
                  childCount: _filteredItems.length + 1,
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ─── Helper Widgets ─────────────────────────────────────────────────

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'breakfast':
        return Icons.bakery_dining;
      case 'dinner':
        return Icons.nights_stay;
      case 'snacks':
        return Icons.icecream;
      case 'all':
        return Icons.restaurant_menu;
      default:
        return Icons.wb_sunny;
    }
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _accentColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.no_meals_outlined,
                size: 48,
                color: _accentColor.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No items available',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Kitchens haven\'t added ${_activeFilter == 'all' ? 'any' : _activeFilter} items\nfor today yet. Check back soon!',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: const Color(0xFF94A3B8),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build a horizontal special card
  Widget _buildSpecialCard(UserDailyMenuItem item) {
    final kitchen = _kitchenCache[item.cookId];
    return Container(
      width: 260,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF8E1), Color(0xFFFFECB3)],
        ),
        border: Border.all(color: const Color(0xFFFFD54F).withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC2941B).withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Kitchen name
                if (kitchen != null)
                  Text(
                    kitchen.kitchenName,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFC2941B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 4),
                Text(
                  item.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  item.description ?? "Chef's special for today",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.priceText,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC2941B),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFC2941B).withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        'ADD',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Special badge
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: const BoxDecoration(
                color: Color(0xFFC2941B),
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome, size: 12, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    'SPECIAL',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Image (if available)
          if (item.imageUrl != null)
            Positioned(
              right: 12,
              top: 40,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: NetworkImage(item.imageUrl!),
                    fit: BoxFit.cover,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Build a vertical list item card
  Widget _buildMenuItemCard(UserDailyMenuItem item) {
    final kitchen = _kitchenCache[item.cookId];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Image
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFFF1F5F9),
              image: item.imageUrl != null
                  ? DecorationImage(
                      image: NetworkImage(item.imageUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: item.imageUrl == null
                ? Icon(Icons.restaurant, color: _accentColor.withOpacity(0.4), size: 28)
                : null,
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Kitchen name
                if (kitchen != null)
                  Text(
                    kitchen.kitchenName,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _accentColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 2),
                // Item name
                Text(
                  item.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.description!,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Price
                    Text(
                      item.priceText,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    // Category chip + Add btn
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _getCategoryColor(item.category).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.categoryName,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _getCategoryColor(item.category),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            border: Border.all(color: _accentColor),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            'ADD',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _accentColor,
                            ),
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
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'breakfast':
        return const Color(0xFFFF9800);
      case 'lunch':
        return const Color(0xFF4CAF50);
      case 'dinner':
        return const Color(0xFF3F51B5);
      case 'snacks':
        return const Color(0xFF9C27B0);
      case 'special':
        return const Color(0xFFC2941B);
      default:
        return const Color(0xFF607D8B);
    }
  }
}
