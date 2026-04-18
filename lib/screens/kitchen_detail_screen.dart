import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'kitchen_subscription_screen.dart';
import 'cart_screen.dart';
import 'dish_detail_screen.dart';
import '../services/menu_service.dart';
import '../models/menu_item.dart';
import '../models/daily_menu_item.dart';
import '../core/localization.dart';

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


  // Cart State
  final Map<String, int> _cartQuantities = {};
  final Map<String, double> _cartPrices = {};
  final Map<String, String> _cartImages = {};
  final Map<String, String> _cartNames = {};

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
        _cartNames.remove(id);
      } else {
        _cartQuantities[id] = newQty;
        _cartPrices[id] = price;
        _cartNames[id] = name;
        if (imageUrl != null) _cartImages[id] = imageUrl;
      }
    });
  }

  Future<Map<String, dynamic>>? _menuFuture;
  Locale? _lastLocale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentLocale = Localizations.localeOf(context);
    if (_lastLocale != currentLocale) {
      _lastLocale = currentLocale;
      final effectiveCookId = (widget.cookId != null && widget.cookId!.isNotEmpty) ? widget.cookId! : '';
      if (effectiveCookId.isNotEmpty) {
        _menuFuture = _loadMenus(effectiveCookId);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    final effectiveCookId = (widget.cookId != null && widget.cookId!.isNotEmpty) ? widget.cookId! : '';
    if (effectiveCookId.isNotEmpty) {
      _menuFuture = _loadMenus(effectiveCookId);
    }
  }

  Future<Map<String, dynamic>> _loadMenus(String cookId) async {
    try {
      final regular = await _menuService.getAvailableMenuItems(cookId);
      final daily = await _menuService.getTodaysDailyMenu(cookId);
      debugPrint('Loaded ${regular.length} regular items, ${daily.length} daily items');
      return {
        'regular': regular,
        'daily': daily,
      };
    } catch (e) {
      debugPrint('Error loading menus: $e');
      return {'regular': <UserMenuItem>[], 'daily': <UserDailyMenuItem>[]};
    }
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

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              if (hasCookId) {
                setState(() {
                  _menuFuture = _loadMenus(effectiveCookId);
                });
                await _menuFuture;
              }
            },
            color: const Color(0xFF16A34A),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
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
                          Text(
                            widget.isVeg ? 'veg'.tr(context) : 'non_veg'.tr(context),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF475569),
                            ),
                          ),
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
                              errorBuilder: (_, _, _) => Container(
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
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 4))],
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
                          kitchenName: widget.kitchenName,
                          imageUrl: widget.imageUrl,
                          price: '\u20B93,500',
                          rating: widget.rating,
                          cookId: effectiveCookId,
                        ),
                      ));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFDCFCE7), Color(0xFFF0FDF4)]),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                        boxShadow: [BoxShadow(color: Colors.green.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 4))],
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

              // ─── Menu Section (Futures) ───────────────────────
              if (hasCookId && _menuFuture != null)
                SliverToBoxAdapter(
                  child: FutureBuilder<Map<String, dynamic>>(
                    future: _menuFuture,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return _buildEmptySection('Failed to load menu', Icons.error_outline);
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(child: CircularProgressIndicator(color: Color(0xFF16A34A), strokeWidth: 2)),
                        );
                      }

                      final data = snapshot.data!;
                      final regularItems = data['regular'] as List<UserMenuItem>;
                      final dailyItems = data['daily'] as List<UserDailyMenuItem>;
                      final specials = dailyItems.where((d) => d.category == 'special' && d.isAvailable).toList();
                      final nonSpecials = dailyItems.where((d) => d.category != 'special' && d.isAvailable).toList();

                      // Group food menu
                      final allItems = [...regularItems, ...dailyItems];
                      final grouped = <String, List<dynamic>>{};
                      for (final item in allItems) {
                        String category = '';
                        if (item is UserMenuItem) {
                          category = item.category;
                        } else if (item is UserDailyMenuItem) {
                          category = item.category == 'special' ? 'Specials' : item.category;
                        }
                        
                        if (category.isNotEmpty) {
                          grouped.putIfAbsent(category, () => []).add(item);
                        }
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // First, show the Daily Specials if they exist
                          if (specials.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("special_items".tr(context), style: GoogleFonts.plusJakartaSans(
                                    fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A),
                                  )),
                                  const SizedBox(height: 12),
                                  _buildDailySpecialCard(specials.first),
                                  const SizedBox(height: 24),
                                ],
                              ),
                            ),

                          if (nonSpecials.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("today_menu".tr(context), style: GoogleFonts.plusJakartaSans(
                                    fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A),
                                  )),
                                  const SizedBox(height: 12),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: nonSpecials.map((item) => Padding(
                                        padding: const EdgeInsets.only(right: 16),
                                        child: _buildDailyItemCard(item),
                                      )).toList(),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                ],
                              ),
                            ),

                          // Header for regular menu
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                            child: Text('food_menu'.tr(context), style: GoogleFonts.plusJakartaSans(
                              fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A),
                            )),
                          ),

                          // Then show categorized menu
                          ...grouped.entries.map((entry) {
                            final category = entry.key;
                            final categoryItems = entry.value;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                                  child: Text(
                                    category.isNotEmpty ? category.tr(context) : 'food_menu'.tr(context),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14, fontWeight: FontWeight.bold,
                                      color: const Color(0xFF64748B), letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                ...categoryItems.map((item) {
                                  String itemId = '';
                                  String itemName = '';
                                  double itemPrice = 0;
                                  String? itemImage;
                                  
                                  if (item is UserMenuItem) {
                                    itemId = item.id;
                                    itemName = item.name;
                                    itemPrice = item.price;
                                    itemImage = item.imageUrl;
                                  } else if (item is UserDailyMenuItem) {
                                    itemId = item.id;
                                    itemName = item.name;
                                    itemPrice = item.price;
                                    itemImage = item.imageUrl;
                                  }

                                  return PersistentMenuItem(
                                    key: ValueKey(itemId),
                                    item: item,
                                    quantity: _getQuantity(itemId),
                                    onUpdate: (delta) => _updateQuantity(
                                      itemId, itemName, itemPrice, itemImage, delta
                                    ),
                                  );
                                }),
                              ],
                            );
                          }),
                        ],
                      );
                    },
                  ),
                ),

              // No cook ID fallback
              if (!hasCookId)
                SliverToBoxAdapter(
                  child: _buildEmptySection('menu_coming_soon'.tr(context), Icons.lunch_dining),
                ),

              // Reviews Section
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
                          Text('reviews_title'.tr(context), style: GoogleFonts.plusJakartaSans(
                            fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A),
                          )),
                          Text('view_all'.tr(context), style: GoogleFonts.plusJakartaSans(
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
                            Text('rate_experience'.tr(context), style: GoogleFonts.plusJakartaSans(
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
                                  child: Text('write_review'.tr(context), style: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8))),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16A34A), shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(color: const Color(0xFF16A34A).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
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
          ),

          // Cart Popup
          if (_cartItemCount > 0)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, -4))],
                ),
                child: SafeArea(
                  top: false,
                  child: GestureDetector(
                    onTap: () async {
                      final cartItems = <String, int>{};
                      final itemPrices = <String, int>{};
                      final itemImages = <String, String>{};
                      final itemNames = <String, String>{};
                      
                      _cartQuantities.forEach((id, qty) {
                        cartItems[id] = qty;
                        itemPrices[id] = (_cartPrices[id] ?? 0).toInt();
                        if (_cartImages[id] != null) itemImages[id] = _cartImages[id]!;
                        if (_cartNames[id] != null) itemNames[id] = _cartNames[id]!;
                      });

                      final result = await Navigator.push(context, MaterialPageRoute(
                        builder: (_) => CartScreen(
                          cartItems: cartItems,
                          itemPrices: itemPrices,
                          itemImages: itemImages,
                          itemNames: itemNames,
                          kitchenName: widget.kitchenName,
                          cookId: effectiveCookId,
                        ),
                      ));

                      if (!mounted) return;

                      if (result != null && result is Map<String, int>) {
                        setState(() {
                          _cartQuantities.clear();
                          _cartPrices.clear();
                          _cartImages.clear();
                          _cartNames.clear();
                          if (result.isNotEmpty) {
                            result.forEach((id, qty) {
                              _cartQuantities[id] = qty;
                            });
                          }
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A), borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: const Color(0xFF16A34A).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$_cartItemCount ${'items'.tr(context).toUpperCase()}', style: GoogleFonts.plusJakartaSans(
                                fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.8),
                              )),
                              Text('\u20B9${_cartTotal.toStringAsFixed(0)}', style: GoogleFonts.plusJakartaSans(
                                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white,
                              )),
                            ],
                          ),
                          Row(children: [
                            Text('view_cart'.tr(context), style: GoogleFonts.plusJakartaSans(
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
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCFCE7)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 2))],
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
                      Text(special.description ?? 'Daily Special',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF475569)),
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('\u20B9${special.price.toStringAsFixed(0)}', style: GoogleFonts.plusJakartaSans(
                            fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A),
                          )),
                          _buildAddBtnInline(special.id, special.name, special.price, special.imageUrl),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyItemCard(UserDailyMenuItem item) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: item.imageUrl != null ? DecorationImage(
                image: NetworkImage(item.imageUrl!), fit: BoxFit.cover,
              ) : null,
              color: const Color(0xFFF1F5F9),
            ),
          ),
          const SizedBox(height: 8),
          Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.plusJakartaSans(
            fontSize: 14, fontWeight: FontWeight.bold,
          )),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('\u20B9${item.price.toStringAsFixed(0)}'),
              _buildAddBtnInline(item.id, item.name, item.price, item.imageUrl, isSmall: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddBtnInline(String id, String name, double price, String? imageUrl, {bool isSmall = false}) {
    final qty = _getQuantity(id);
    if (qty > 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(icon: const Icon(Icons.remove_circle_outline, size: 20), onPressed: () => _updateQuantity(id, name, price, imageUrl, -1)),
          Text('$qty'),
          IconButton(icon: const Icon(Icons.add_circle_outline, size: 20), onPressed: () => _updateQuantity(id, name, price, imageUrl, 1)),
        ],
      );
    }
    return ElevatedButton(
      onPressed: () => _updateQuantity(id, name, price, imageUrl, 1),
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: isSmall ? 8 : 16),
        minimumSize: Size(0, isSmall ? 28 : 36),
      ),
      child: Text('add'.tr(context)),
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
        ],
      ),
    );
  }

  /* removed _buildMealFilterChip */
}


class PersistentMenuItem extends StatefulWidget {
  final dynamic item;
  final int quantity;
  final Function(int delta) onUpdate;
  const PersistentMenuItem({super.key, required this.item, required this.quantity, required this.onUpdate});
  @override State<PersistentMenuItem> createState() => _PersistentMenuItemState();
}

class _PersistentMenuItemState extends State<PersistentMenuItem> with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final item = widget.item;
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DishDetailScreen(
              item: item,
              quantity: widget.quantity,
              onUpdate: widget.onUpdate,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Extra Large Photo with Hero
            Hero(
              tag: 'dish_${item.id}',
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: const Color(0xFFF1F5F9),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                    ? Image.network(item.imageUrl!, fit: BoxFit.cover) 
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.fastfood_rounded, size: 48, color: Color(0xFFCBD5E1)),
                          const SizedBox(height: 8),
                          Text('no_photo'.tr(context), style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                        ],
                      ),
                ),
              ),
            ),
          const SizedBox(width: 20),
          // Extra Large Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F172A),
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  '₹${item.price.toStringAsFixed(0)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          ),
          // Bigger ADD button
          _buildAddBtn(),
        ],
      ),
    ),
    );
  }

  Widget _buildAddBtn() {
    final qty = widget.quantity;
    if (qty > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF16A34A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove, size: 20, color: Colors.white),
              onPressed: () => widget.onUpdate(-1),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
            ),
            Text('$qty', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            IconButton(
              icon: const Icon(Icons.add, size: 20, color: Colors.white),
              onPressed: () => widget.onUpdate(1),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      );
    }
    return ElevatedButton(
      onPressed: () => widget.onUpdate(1),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF16A34A),
        side: const BorderSide(color: Color(0xFF16A34A), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
        minimumSize: const Size(80, 40),
      ),
      child: const Text('ADD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }
}

