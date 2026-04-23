import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/menu_service.dart';
import '../services/cart_service.dart';
import '../services/review_service.dart';
import '../models/menu_item.dart';
import '../models/daily_menu_item.dart';
import '../models/kitchen.dart';
import '../services/kitchen_service.dart';
import '../core/localization.dart';
import 'basket_screen.dart';
import 'dish_detail_screen.dart';
import 'kitchen_subscription_screen.dart';
import '../widgets/cart_toast.dart';
import '../utils/error_handler.dart';
import 'package:share_plus/share_plus.dart';

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
    required this.isVeg,
    this.cookId,
    this.kitchenPhotos = const [],
    this.preloadedMenuFuture,
  });

  @override
  State<KitchenDetailScreen> createState() => _KitchenDetailScreenState();
}

class _KitchenDetailScreenState extends State<KitchenDetailScreen> {
  final MenuService _menuService = MenuService();
  final ReviewService _reviewService = ReviewService();
  final PageController _photoController = PageController();


  bool _showVegOnly = false;

  void _rebuild() {
    if (mounted) setState(() {});
  }

  int _getQuantity(String id) => CartService.instance.getQuantity(id, widget.cookId ?? '');

  void _updateQuantity(String id, String name, double price, String? imageUrl, int delta) {
    final cookId = widget.cookId ?? '';
    final qty = CartService.instance.getQuantity(id, cookId);

    if (qty == 0 && delta > 0) {
      final result = CartService.instance.addItem(
        dishId: id,
        dishName: name,
        price: price,
        cookId: cookId,
        kitchenName: widget.kitchenName,
        imageUrl: imageUrl,
      );
      if (result == 'different_kitchen') {
        _showReplaceCartDialog(id, name, price, imageUrl);
        return;
      }
    } else {
      CartService.instance.adjustQuantity(id, cookId, delta);
    }
  }

  void _showReplaceCartDialog(String id, String name, double price, String? imageUrl) {
    final existingKitchen = CartService.instance.items.isNotEmpty
        ? CartService.instance.items.first.kitchenName
        : 'another kitchen';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Replace cart items?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text(
          'Your cart has items from "$existingKitchen". Do you want to clear them and add items from "${widget.kitchenName}" instead?',
          style: GoogleFonts.plusJakartaSans(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('No', style: GoogleFonts.plusJakartaSans(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              CartService.instance.clearCart();
              CartService.instance.addItem(
                dishId: id,
                dishName: name,
                price: price,
                cookId: widget.cookId ?? '',
                kitchenName: widget.kitchenName,
                imageUrl: imageUrl,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Yes, Replace', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>>? _menuFuture;
  Map<String, dynamic>? _loadedMenu;
  bool _isLoadingMenu = true;
  Future<Kitchen?>? _kitchenDataFuture;
  Future<List<Map<String, dynamic>>>? _reviewsFuture;
  Future<Map<String, dynamic>>? _ratingStatsFuture;
  Locale? _lastLocale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentLocale = Localizations.localeOf(context);
    if (_lastLocale != currentLocale) {
      _lastLocale = currentLocale;
      final effectiveCookId = (widget.cookId != null && widget.cookId!.isNotEmpty) ? widget.cookId! : '';
      if (effectiveCookId.isNotEmpty) {
        _isLoadingMenu = true;
        _menuFuture = _loadMenus(effectiveCookId);
        _menuFuture!.then((data) {
          if (mounted) setState(() { _loadedMenu = data; _isLoadingMenu = false; });
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    CartService.instance.addListener(_rebuild);
    final effectiveCookId = (widget.cookId != null && widget.cookId!.isNotEmpty) ? widget.cookId! : '';
    if (widget.preloadedMenuFuture != null) {
      _menuFuture = widget.preloadedMenuFuture;
    } else if (effectiveCookId.isNotEmpty) {
      _menuFuture = _loadMenus(effectiveCookId);
    }
    
    if (_menuFuture != null) {
      _menuFuture!.then((data) {
        if (mounted) setState(() { _loadedMenu = data; _isLoadingMenu = false; });
      });
    } else {
      _isLoadingMenu = false;
    }
    
    if (effectiveCookId.isNotEmpty) {
      _kitchenDataFuture = KitchenService().getKitchenByCookId(effectiveCookId);
      _reviewsFuture = _reviewService.getKitchenReviews(effectiveCookId, limit: 10);
      _ratingStatsFuture = _reviewService.getKitchenRatingStats(effectiveCookId);
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
      if (mounted) {
        ErrorHandler.showGracefulError(context, e);
      }
      return {'regular': <UserMenuItem>[], 'daily': <UserDailyMenuItem>[]};
    }
  }

  void _showReviewsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40, height: 4,
                decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Text('Reviews', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),

              // Rating summary row
              if (_ratingStatsFuture != null)
                FutureBuilder<Map<String, dynamic>>(
                  future: _ratingStatsFuture,
                  builder: (context, statsSnap) {
                    if (!statsSnap.hasData) return const SizedBox.shrink();
                    final avg = (statsSnap.data!['average'] as num?)?.toDouble() ?? 0.0;
                    final count = (statsSnap.data!['count'] as num?)?.toInt() ?? 0;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      child: Row(
                        children: [
                          Text(avg.toStringAsFixed(1), style: GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: List.generate(5, (i) => Icon(
                                  i < avg.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                                  size: 18, color: const Color(0xFFEAB308),
                                )),
                              ),
                              Text('$count reviews', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF94A3B8))),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),

              const Divider(height: 1, color: Color(0xFFF1F5F9)),

              // Reviews list
              Expanded(
                child: _reviewsFuture != null
                    ? FutureBuilder<List<Map<String, dynamic>>>(
                        future: _reviewsFuture,
                        builder: (context, snap) {
                          if (!snap.hasData) {
                            return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF16A34A)));
                          }
                          if (snap.data!.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.rate_review_outlined, size: 48, color: Color(0xFFCBD5E1)),
                                  const SizedBox(height: 12),
                                  Text('No reviews yet', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8))),
                                  const SizedBox(height: 4),
                                  Text('Be the first to review!', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFFCBD5E1))),
                                ],
                              ),
                            );
                          }
                          return ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            itemCount: snap.data!.length,
                            separatorBuilder: (context, index) => const Divider(height: 24, color: Color(0xFFF1F5F9)),
                            itemBuilder: (_, i) {
                              final review = snap.data![i];
                              final rating = (review['kitchen_rating'] as num?)?.toInt() ?? 0;
                              final comment = review['kitchen_comment'] as String? ?? '';
                              final createdAt = review['created_at'] as String? ?? '';
                              
                              // Try to get customer name from orders join first, then users join
                              final orderData = review['orders'] as Map<String, dynamic>?;
                              final userData = review['users'] as Map<String, dynamic>?;
                              final userName = orderData?['customer_name'] as String? 
                                  ?? userData?['name'] as String? 
                                  ?? 'Customer';
                              
                              // Build items summary from order
                              String? itemsSummary;
                              if (orderData != null && orderData['items'] is List) {
                                final items = orderData['items'] as List;
                                if (items.isNotEmpty) {
                                  final names = items.take(2).map((item) {
                                    if (item is Map) return item['name'] ?? item['dish_name'] ?? '';
                                    return '';
                                  }).where((n) => n.toString().isNotEmpty).toList();
                                  if (names.isNotEmpty) {
                                    itemsSummary = names.join(', ');
                                    if (items.length > 2) itemsSummary = '$itemsSummary +${items.length - 2} more';
                                  }
                                }
                              }

                              String dateStr = '';
                              try {
                                final dt = DateTime.parse(createdAt);
                                final diff = DateTime.now().difference(dt);
                                if (diff.inDays == 0) {
                                  dateStr = 'Today';
                                } else if (diff.inDays == 1) {
                                  dateStr = 'Yesterday';
                                } else if (diff.inDays < 30) {
                                  dateStr = '${diff.inDays}d ago';
                                } else {
                                  dateStr = '${dt.day}/${dt.month}/${dt.year}';
                                }
                              } catch (_) {}

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: const Color(0xFFF1F5F9),
                                    child: Text(
                                      userName.isNotEmpty ? userName[0].toUpperCase() : 'C',
                                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF64748B)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(userName, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B))),
                                            const Spacer(),
                                            Text(dateStr, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF94A3B8))),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: List.generate(5, (s) => Icon(
                                            s < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                                            size: 16, color: const Color(0xFFEAB308),
                                          )),
                                        ),
                                        if (comment.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(comment, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF475569), height: 1.4)),
                                        ],
                                        if (itemsSummary != null) ...[
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Icon(Icons.restaurant_menu, size: 12, color: Colors.grey.shade400),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  'Ordered: $itemsSummary',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      )
                    : Center(
                        child: Text('No reviews available', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8))),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    CartService.instance.removeListener(_rebuild);
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
                  _isLoadingMenu = true;
                  _menuFuture = _loadMenus(effectiveCookId);
                });
                final data = await _menuFuture;
                if (mounted) setState(() { _loadedMenu = data; _isLoadingMenu = false; });
              }
            },
            color: const Color(0xFF16A34A),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                // Hero Image + App Bar
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 220,
                  backgroundColor: Colors.white,
                  surfaceTintColor: Colors.white,
                  elevation: 0,
                  leading: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.white),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  actions: [
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.share_outlined, size: 18, color: Colors.white),
                      ),
                      onPressed: () {
                        SharePlus.instance.share(
                          ShareParams(
                            text: 'Check out ${widget.kitchenName} on Ghar Ka Khana! 🍽️ Homemade food delivered to your door.',
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.info_outline, size: 18, color: Colors.white),
                      ),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (ctx) => Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.kitchenName,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.kitchenSubtitle.replaceAll('_', ' '),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    const Icon(Icons.star_rounded, size: 18, color: Color(0xFFEAB308)),
                                    const SizedBox(width: 4),
                                    Text('${widget.rating} (${widget.ratingCount} ratings)',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_outlined, size: 18, color: Color(0xFF94A3B8)),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(widget.tag.replaceAll('_', ' '),
                                        style: GoogleFonts.plusJakartaSans(fontSize: 14, color: const Color(0xFF64748B))),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.timer_outlined, size: 18, color: Color(0xFF94A3B8)),
                                    const SizedBox(width: 4),
                                    Text('Delivery: ${widget.time}',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 14, color: const Color(0xFF64748B))),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(widget.isVeg ? Icons.eco : Icons.kebab_dining,
                                      size: 18, color: widget.isVeg ? const Color(0xFF16A34A) : Colors.red),
                                    const SizedBox(width: 4),
                                    Text(widget.isVeg ? 'Pure Vegetarian Kitchen' : 'Non-Veg Available',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 14, color: const Color(0xFF64748B))),
                                  ],
                                ),
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: widget.imageUrl.isNotEmpty
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                widget.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => Container(
                                  color: const Color(0xFFF1F5F9),
                                  child: const Center(
                                    child: Icon(Icons.restaurant, size: 48, color: Color(0xFFCBD5E1)),
                                  ),
                                ),
                              ),
                              // Bottom gradient for readability
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, Colors.black54],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Container(
                            color: const Color(0xFFF1F5F9),
                            child: const Center(
                              child: Icon(Icons.restaurant, size: 48, color: Color(0xFFCBD5E1)),
                            ),
                          ),
                  ),
                ),

                // Kitchen Info Card (Premium Header)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.kitchenName,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF0F172A),
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.kitchenSubtitle.replaceAll('_', ' '),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF94A3B8)),
                                      const SizedBox(width: 4),
                                      Text(
                                        widget.tag.replaceAll('_', ' '),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          color: const Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _showReviewsSheet(context),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16A34A),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF16A34A).withOpacity(0.2),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          widget.rating,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const Icon(Icons.star_rounded, color: Colors.white, size: 16),
                                      ],
                                    ),
                                    Text(
                                      'REVIEWS',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white.withOpacity(0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _buildInfoChip(Icons.timer_outlined, widget.time),
                            const SizedBox(width: 12),
                            _buildInfoChip(Icons.currency_rupee_rounded, '200 for two'),
                            const SizedBox(width: 12),
                            _buildInfoChip(widget.isVeg ? Icons.eco : Icons.kebab_dining, 
                                widget.isVeg ? 'Pure Veg' : 'Non-Veg',
                                color: widget.isVeg ? const Color(0xFF16A34A) : Colors.red),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Filter Buttons
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => setState(() => _showVegOnly = !_showVegOnly),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _showVegOnly ? const Color(0xFF16A34A).withOpacity(0.1) : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _showVegOnly ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 14, height: 14,
                                      decoration: BoxDecoration(
                                        border: Border.all(color: const Color(0xFF16A34A), width: 1),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Center(
                                        child: Container(
                                          width: 6, height: 6,
                                          decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('Veg Only', style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12, fontWeight: FontWeight.w700, 
                                      color: _showVegOnly ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                                    )),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Subscription Promo (Zomato Style)
                if (effectiveCookId.isNotEmpty && _kitchenDataFuture != null)
                  SliverToBoxAdapter(
                    child: FutureBuilder<Kitchen?>(
                      future: _kitchenDataFuture,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data == null) return const SizedBox.shrink();
                        final kitchen = snapshot.data!;
                        if (kitchen.weeklyPlanPrice == null && kitchen.monthlyPlanPrice == null) return const SizedBox.shrink();
                        
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.stars, color: Color(0xFFFACC15), size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'GKK GOLD SPECIAL',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFFFACC15),
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    Text(
                                      'Get weekly plans from \u20B9${kitchen.weeklyPlanPrice?.toInt()}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: Colors.white.withOpacity(0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => KitchenSubscriptionScreen(
                                      kitchenName: widget.kitchenName,
                                      imageUrl: widget.imageUrl,
                                      rating: widget.rating,
                                      cookId: effectiveCookId,
                                    ),
                                  ));
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFACC15),
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('JOIN NOW', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                // ─── Menu Section ───────────────────────
                if (hasCookId && _isLoadingMenu)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(64),
                      child: Center(child: CircularProgressIndicator(color: Color(0xFF16A34A))),
                    ),
                  )
                else if (hasCookId && _loadedMenu != null)
                  ...() {
                    var regularItems = _loadedMenu!['regular'] as List<UserMenuItem>? ?? [];
                    var dailyItems = _loadedMenu!['daily'] as List<UserDailyMenuItem>? ?? [];
                    
                    if (_showVegOnly) {
                      regularItems = regularItems.where((i) => i.isVeg).toList();
                      dailyItems = dailyItems.where((i) => i.isVeg).toList();
                    }
                    
                    final allItems = [...regularItems, ...dailyItems];

                    if (allItems.isEmpty) {
                      return [
                        SliverToBoxAdapter(
                          child: _buildEmptySection(
                            'no_items_available'.tr(context),
                            Icons.no_meals_outlined,
                          ),
                        )
                      ];
                    }

                    // Group items by category
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

                    final categories = grouped.keys.toList();
                    final slivers = <Widget>[];

                    // Sticky Category Header
                    slivers.add(SliverPersistentHeader(
                      pinned: true,
                      delegate: CategoryHeaderDelegate(
                        categories: categories,
                        onCategorySelected: (cat) {
                          // Scroll to category logic could be added here
                        },
                      ),
                    ));

                    for (final category in categories) {
                      final categoryItems = grouped[category]!;

                      slivers.add(SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                          child: Text(
                            category.replaceAll('_', ' ').toUpperCase(),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF1E293B),
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ));

                      slivers.add(SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = categoryItems[index];
                            return ZomatoMenuItem(
                              item: item,
                              quantity: _getQuantity(item.id),
                              onUpdate: (delta) => _updateQuantity(
                                item.id, item.name.toString().replaceAll('_', ' '), item.price, item.imageUrl, delta
                              ),
                            );
                          },
                          childCount: categoryItems.length,
                        ),
                      ));
                      
                      // Add a spacer after each category
                      slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 24)));
                    }

                    return slivers;
                  }(),

              // No cook ID fallback
              if (!hasCookId)
                SliverToBoxAdapter(
                  child: _buildEmptySection('menu_coming_soon'.tr(context), Icons.lunch_dining),
                ),

              // Reviews Summary — tap to open full sheet
              SliverToBoxAdapter(
                child: GestureDetector(
                  onTap: () => _showReviewsSheet(context),
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: _ratingStatsFuture != null
                        ? FutureBuilder<Map<String, dynamic>>(
                            future: _ratingStatsFuture,
                            builder: (context, statsSnap) {
                              final avg = statsSnap.hasData ? ((statsSnap.data!['average'] as num?)?.toDouble() ?? 0.0) : 0.0;
                              final count = statsSnap.hasData ? ((statsSnap.data!['count'] as num?)?.toInt() ?? 0) : 0;
                              return Row(
                                children: [
                                  const Icon(Icons.star_rounded, size: 22, color: Color(0xFFEAB308)),
                                  const SizedBox(width: 8),
                                  Text(
                                    count > 0 ? '$avg · $count Reviews' : 'No reviews yet',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF92400E)),
                                  ),
                                  const Spacer(),
                                  Text('See all', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFFB45309))),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.arrow_forward_ios, size: 13, color: Color(0xFFB45309)),
                                ],
                              );
                            },
                          )
                        : Text('Tap to see reviews', style: GoogleFonts.plusJakartaSans(fontSize: 14, color: const Color(0xFF92400E))),
                  ),
                ),
              ),
            ],
          ),
        ),
          // Cart Popup
          Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: CartToast(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BasketScreen(initialTabIndex: 0),
                    ),
                  );
                },
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









  Widget _buildInfoChip(IconData icon, String label, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color ?? const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  /* removed _buildMealFilterChip */
}


// ─── Zomato-style Menu Item Card ────────────────────────────
class ZomatoMenuItem extends StatelessWidget {
  final dynamic item;
  final int quantity;
  final Function(int) onUpdate;

  const ZomatoMenuItem({
    super.key,
    required this.item,
    required this.quantity,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final String name = item.name.toString().replaceAll('_', ' ');
    final double price = item.price;
    final String? imageUrl = item.imageUrl;
    final String? description = item is UserMenuItem
        ? (item.description as String?)
        : (item is UserDailyMenuItem ? item.description : null);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DishDetailScreen(
              item: item,
              quantity: quantity,
              onUpdate: onUpdate,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: Text info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Veg/Non-veg badge
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: item.isVeg ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: item.isVeg ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Name
                  Text(
                    name,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Price
                  Text(
                    '\u20B9${price.toStringAsFixed(0)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  if (description != null && description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: const Color(0xFF94A3B8),
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Right: Image + ADD button
            SizedBox(
              width: 120,
              child: Column(
                children: [
                  // Image
                  Hero(
                    tag: 'dish_${item.id}',
                    child: Container(
                      width: 120,
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: const Color(0xFFF1F5F9),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: imageUrl != null && imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                width: 120,
                                height: 100,
                                errorBuilder: (c, e, s) => _buildPlaceholder(),
                              )
                            : _buildPlaceholder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // ADD button
                  _buildAddButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFFF1F5F9),
      width: 120,
      height: 100,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fastfood_rounded, color: Color(0xFFCBD5E1), size: 28),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    if (quantity > 0) {
      return Container(
        height: 34,
        decoration: BoxDecoration(
          color: const Color(0xFF16A34A),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 34),
              icon: const Icon(Icons.remove, size: 16, color: Colors.white),
              onPressed: () => onUpdate(-1),
            ),
            Text(
              '$quantity',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 34),
              icon: const Icon(Icons.add, size: 16, color: Colors.white),
              onPressed: () => onUpdate(1),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => onUpdate(1),
      child: Container(
        width: 120,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF16A34A), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF16A34A).withOpacity(0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'ADD',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF16A34A),
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}


// ─── Sticky Category Header Delegate ────────────────────────
class CategoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  final List<String> categories;
  final Function(String) onCategorySelected;

  CategoryHeaderDelegate({
    required this.categories,
    required this.onCategorySelected,
  });

  @override
  double get minExtent => 52;
  @override
  double get maxExtent => 52;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: overlapsContent
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        separatorBuilder: (_, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isFirst = index == 0;
          return GestureDetector(
            onTap: () => onCategorySelected(cat),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isFirst ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  cat,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isFirst ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  bool shouldRebuild(CategoryHeaderDelegate oldDelegate) {
    return categories != oldDelegate.categories;
  }
}
