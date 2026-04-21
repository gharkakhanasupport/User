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
  final ReviewService _reviewService = ReviewService();
  final PageController _photoController = PageController();
  int _currentPhotoIndex = 0;


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
        _menuFuture = _loadMenus(effectiveCookId);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    CartService.instance.addListener(_rebuild);
    final effectiveCookId = (widget.cookId != null && widget.cookId!.isNotEmpty) ? widget.cookId! : '';
    if (effectiveCookId.isNotEmpty) {
      _menuFuture = _loadMenus(effectiveCookId);
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
                              final userData = review['users'] as Map<String, dynamic>?;
                              final userName = userData?['name'] as String? ?? 'Customer';

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

                      // Rating badge — dynamic from real reviews
                      if (_ratingStatsFuture != null)
                        FutureBuilder<Map<String, dynamic>>(
                          future: _ratingStatsFuture,
                          builder: (context, statsSnap) {
                            String ratingLabel = widget.rating;
                            String countLabel = widget.ratingCount;

                            if (statsSnap.hasData) {
                              final avg = (statsSnap.data!['average'] as num?)?.toDouble() ?? 0.0;
                              final count = (statsSnap.data!['count'] as num?)?.toInt() ?? 0;
                              if (count > 0) {
                                ratingLabel = avg.toStringAsFixed(1);
                                countLabel = '($count)';
                              }
                            }

                            return Wrap(
                              alignment: WrapAlignment.center, spacing: 12, runSpacing: 12,
                              children: [
                                _buildTag(Icons.star, ratingLabel, countLabel, const Color(0xFFC2941B), const Color(0xFFF8F9FA)),
                                _buildTag(Icons.schedule, widget.time, '', const Color(0xFFC2941B), const Color(0xFFF8F9FA)),
                                _buildTag(Icons.home_work, widget.tag, '', const Color(0xFF166534), const Color(0xFFF0FDF4), fgColor: const Color(0xFF166534)),
                              ],
                            );
                          },
                        )
                      else
                        Wrap(
                          alignment: WrapAlignment.center, spacing: 12, runSpacing: 12,
                          children: [
                            _buildTag(Icons.star, widget.rating, widget.ratingCount, const Color(0xFFC2941B), const Color(0xFFF8F9FA)),
                            _buildTag(Icons.schedule, widget.time, '', const Color(0xFFC2941B), const Color(0xFFF8F9FA)),
                            _buildTag(Icons.home_work, widget.tag, '', const Color(0xFF166534), const Color(0xFFF0FDF4), fgColor: const Color(0xFF166534)),
                          ],
                        ),

                      // Reviews tap button
                      const SizedBox(height: 16),
                      if (_ratingStatsFuture != null)
                        FutureBuilder<Map<String, dynamic>>(
                          future: _ratingStatsFuture,
                          builder: (context, statsSnap) {
                            final avg = statsSnap.hasData ? ((statsSnap.data!['average'] as num?)?.toDouble() ?? 0.0) : 0.0;
                            final count = statsSnap.hasData ? ((statsSnap.data!['count'] as num?)?.toInt() ?? 0) : 0;
                            return GestureDetector(
                              onTap: () => _showReviewsSheet(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFFBEB),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFFDE68A)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.star_rounded, size: 20, color: Color(0xFFEAB308)),
                                    const SizedBox(width: 6),
                                    Text(
                                      count > 0 ? '$avg · $count Reviews' : 'No reviews yet',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF92400E)),
                                    ),
                                    const Spacer(),
                                    const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFFB45309)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),

              // Subscription Button
              if (effectiveCookId.isNotEmpty && _kitchenDataFuture != null)
                SliverToBoxAdapter(
                  child: FutureBuilder<Kitchen?>(
                    future: _kitchenDataFuture,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data == null) {
                        return const SizedBox.shrink();
                      }
                      
                      final kitchen = snapshot.data!;
                      if (kitchen.weeklyPlanPrice == null && kitchen.monthlyPlanPrice == null) {
                        return const SizedBox.shrink();
                      }

                      final startingPrice = kitchen.weeklyPlanPrice ?? kitchen.monthlyPlanPrice;
                      final planLabel = kitchen.weeklyPlanPrice != null ? 'week' : 'month';

                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => KitchenSubscriptionScreen(
                                kitchenName: widget.kitchenName,
                                imageUrl: widget.imageUrl,
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
                                    Text('Plans starting at \u20B9${startingPrice?.toInt()}/$planLabel', style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12, color: const Color(0xFF166534),
                                    )),
                                  ]),
                                ]),
                                const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF166534)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
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

                      if (allItems.isEmpty) {
                        return _buildEmptySection(
                          'no_items_available'.tr(context),
                          Icons.no_meals_outlined,
                        );
                      }

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

