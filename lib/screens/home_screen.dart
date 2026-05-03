import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/hero_banner.dart';
import '../widgets/category_selector.dart';
import '../widgets/kitchen_card.dart';
import '../services/kitchen_service.dart';
import '../models/kitchen.dart';
import 'package:geolocator/geolocator.dart';
import 'login_screen.dart';
import '../widgets/active_order_banner.dart';
import '../widgets/quick_reorder_card.dart';
import '../core/localization.dart';
import '../widgets/skeleton_loaders.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}


enum DietFilter { all, veg, nonVeg }

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  DietFilter dietFilter = DietFilter.all;
  String selectedCategory = 'All';
  RealtimeChannel? _banSubscription;
  final GlobalKey<HeroBannerState> _heroBannerKey = GlobalKey<HeroBannerState>();
  final KitchenService _kitchenService = KitchenService();
  late Future<List<Kitchen>> _kitchensFuture;
  final GlobalKey<ActiveOrderBannerState> _activeOrderBannerKey = GlobalKey<ActiveOrderBannerState>();

  @override
  void initState() {
    super.initState();
    _selectedDefaultCategory();
    _checkBanStatus();
    _setupBanListener();
    _loadKitchens();
  }

  void _loadKitchens() {
    setState(() {
      _kitchensFuture = _fetchKitchensWithLocation();
    });
  }

  Future<List<Kitchen>> _fetchKitchensWithLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return await _kitchenService.getKitchens();
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return await _kitchenService.getKitchens();
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return await _kitchenService.getKitchens();
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      );
          
      return await _kitchenService.getNearbyKitchens(position.latitude, position.longitude, radiusKm: 5.0);
    } catch (e) {
      debugPrint('Error getting location for kitchens: $e');
      return await _kitchenService.getKitchens();
    }
  }

  void _selectedDefaultCategory() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 11) {
      selectedCategory = 'Breakfast';
    } else if (hour >= 11 && hour < 16) {
      selectedCategory = 'Lunch';
    } else if (hour >= 16 && hour < 19) {
      selectedCategory = 'Snacks';
    } else if (hour >= 19 && hour < 23) {
      selectedCategory = 'Dinner';
    } else {
      selectedCategory = 'All';
    }
  }

  Locale? _lastLocale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newLocale = Localizations.localeOf(context);
    if (_lastLocale != null && _lastLocale != newLocale) {
      // Locale changed! 
      if (mounted) setState(() {});
      _onRefresh();
    }
    _lastLocale = newLocale;
  }

  @override
  void dispose() {
    _banSubscription?.unsubscribe();
    super.dispose();
  }

  /// Setup real-time listener for ban status changes
  void _setupBanListener() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _banSubscription = Supabase.instance.client
        .channel('user_ban_${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'users',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: user.id,
          ),
          callback: (payload) {
            final newData = payload.newRecord;
            if (newData['is_banned'] == true || newData['status'] == 'rejected') {
              _forceLogout();
            }
          },
        )
        .subscribe();
  }

  /// Force logout the user
  Future<void> _forceLogout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('account_suspended'.tr(context)),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  /// Check if user is banned on app start
  Future<void> _checkBanStatus() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('is_banned, status')
          .eq('id', user.id)
          .maybeSingle();

      if (response != null && 
          (response['is_banned'] == true || response['status'] == 'rejected')) {
        _forceLogout();
      }
    } catch (e) {
      debugPrint('Ban check error: $e');
    }
  }

  /// Category selected → just update local filter, no navigation
  void onCategorySelected(String category) {
    setState(() {
      selectedCategory = category;
    });
    // No navigation — categories are filters only
  }

  /// Pull-to-refresh handler
  Future<void> _onRefresh() async {
    // Reload banners
    _heroBannerKey.currentState?.loadBanners();
    
    // Refresh active order banner
    _activeOrderBannerKey.currentState?.refreshStream();
    
    // Reload kitchens
    _loadKitchens();
    
    await _kitchensFuture;
  }

  LinearGradient getBackgroundGradient() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) return AppColors.bgGradientDark;

    if (selectedCategory == 'Breakfast') {
      return AppColors.bgGradientYellow;
    } else if (selectedCategory == 'Dinner') {
      return AppColors.bgGradientBlue;
    } else if (selectedCategory == 'Snacks') {
      return AppColors.bgGradientPurple;
    } else if (selectedCategory == 'Lunch') {
       if (dietFilter == DietFilter.veg) return AppColors.bgGradientLight;
       if (dietFilter == DietFilter.nonVeg) return AppColors.bgGradientRed;
       return AppColors.bgGradientLight;
    }
    return dietFilter == DietFilter.nonVeg ? AppColors.bgGradientRed : AppColors.bgGradientLight;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom + 90;

    return Scaffold(
      backgroundColor: Colors.transparent, 
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          image: const DecorationImage(
            image: NetworkImage('https://lh3.googleusercontent.com/aida-public/AB6AXuBA8A15vZoWrwVoorXyHYFKFoc4wEjh_cI92GhRWHbAFR3jwuI3e1CSuixGlxwXtIKJueYZk42gHN_Gs-PbSQfqgcW-CLyk0-x3UwKx_wEoqbDJvkfBRq_GcFDpsEusUeQPKrZ3S8YjoZSS2uJImJtiREJBh1IbGhG6Y8Z9hLVjiccL3uUDIXxKkgVXMAAX0iZQM4feL7u3Sm0gJXIG7KZzwdStM7TRkBs6rRXBCmJ-kNfRq9-66XTNvKsBKQhbzaG1T0dzMfWEJ27h'), 
            fit: BoxFit.cover,
            opacity: 0.4,
          ),
          gradient: getBackgroundGradient(),
        ),
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            color: dietFilter == DietFilter.nonVeg ? AppColors.primaryRed : AppColors.primary,
            backgroundColor: Colors.white,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ─── PINNED APP BAR ───────────────────────────────────
                SliverToBoxAdapter(
                  child: CustomAppBar(
                    dietFilter: dietFilter, 
                    onFilterChanged: (f) => setState(() => dietFilter = f),
                  ),
                ),

                // ─── HERO BANNER ──────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: HeroBanner(
                      key: _heroBannerKey, 
                      isVeg: dietFilter != DietFilter.nonVeg,
                    ),
                  ),
                ),

                // ─── QUICK REORDER ────────────────────────────────────
                const SliverToBoxAdapter(
                  child: QuickReorderCard(),
                ),

                // ─── CATEGORY FILTER ──────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: CategorySelector(
                      selectedCategory: selectedCategory,
                      onCategorySelected: onCategorySelected,
                      isVeg: dietFilter != DietFilter.nonVeg,
                    ),
                  ),
                ),

                // ─── "ALL KITCHENS" LABEL ─────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          selectedCategory == 'All'
                              ? 'all_kitchens'.tr(context)
                              : '${selectedCategory.toLowerCase().tr(context)} ${'kitchens'.tr(context)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textMain,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'view_all'.tr(context),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: dietFilter == DietFilter.nonVeg ? AppColors.primaryRed : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ─── KITCHEN LIST ─────────────────────────────────────
                FutureBuilder<List<Kitchen>>(
                  future: _kitchensFuture,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      debugPrint('Home Screen Kitchens Error: ${snapshot.error}');
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textSub.withValues(alpha: 0.5)),
                                const SizedBox(height: 16),
                                Text(
                                  'kitchen_load_error'.tr(context),
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textMain,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'check_internet'.tr(context),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSub),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton(
                                  onPressed: _onRefresh,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: Text('retry'.tr(context)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return SliverToBoxAdapter(
                        child: Column(
                          children: List.generate(3, (_) => const KitchenCardSkeleton()),
                        ),
                      );
                    }

                    final allKitchens = snapshot.data ?? [];
                    final kitchens = allKitchens.where((k) {
                      if (dietFilter == DietFilter.veg) return k.isVegetarian;
                      if (dietFilter == DietFilter.nonVeg) return !k.isVegetarian;
                      return true;
                    }).toList();

                    if (kitchens.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.storefront_outlined, size: 64, color: AppColors.textSub.withValues(alpha: 0.3)),
                                const SizedBox(height: 16),
                                Text(
                                  'no_kitchens'.tr(context),
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textSub,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index == kitchens.length) {
                            return SizedBox(height: bottomPadding);
                          }
                          final k = kitchens[index];
                          return KitchenCard(
                            title: k.kitchenName,
                            subtitle: k.subtitle,
                            imageUrl: k.displayImage ?? 'https://via.placeholder.com/150',
                            rating: k.ratingText,
                            price: '${k.totalOrders}',
                            time: k.isAvailable ? 'open_now'.tr(context) : 'closed'.tr(context),
                            isVeg: k.isVegetarian,
                            tag: k.isVegetarian ? 'pure_veg'.tr(context) : null,
                            tagColor: k.isVegetarian ? Colors.green : null,
                            isClosed: !k.isAvailable,
                            cookId: k.cookId,
                          );
                        },
                        childCount: kitchens.length + 1, // +1 for bottom spacing
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
