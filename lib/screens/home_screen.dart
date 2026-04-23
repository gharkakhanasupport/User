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
import 'category_transition_screen.dart';
import 'login_screen.dart';
import '../widgets/active_order_banner.dart';
import '../core/localization.dart';


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
  String selectedCategory = 'Lunch';
  RealtimeChannel? _banSubscription;
  final GlobalKey<HeroBannerState> _heroBannerKey = GlobalKey<HeroBannerState>();
  final KitchenService _kitchenService = KitchenService();
  late Future<List<Kitchen>> _kitchensFuture;
  final GlobalKey<ActiveOrderBannerState> _activeOrderBannerKey = GlobalKey<ActiveOrderBannerState>();

  @override
  void initState() {
    super.initState();
    _checkBanStatus();
    _setupBanListener();
    _kitchensFuture = _kitchenService.getKitchens();
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

  void onCategorySelected(String category) {
    setState(() {
      selectedCategory = category;
    });

    if (CategoryTransitionScreen.shouldAnimate(category)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CategoryTransitionScreen(categoryName: category),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CategoryTransitionScreen.getTargetScreen(category),
        ),
      );
    }
  }

  /// Pull-to-refresh handler
  Future<void> _onRefresh() async {
    // Reload banners
    _heroBannerKey.currentState?.loadBanners();
    
    // Refresh active order banner
    _activeOrderBannerKey.currentState?.refreshStream();
    
    // Reload kitchens
    setState(() {
      _kitchensFuture = _kitchenService.getKitchens();
    });
    
    await _kitchensFuture;
  }

  LinearGradient getBackgroundGradient() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) return AppColors.bgGradientDark;

    if (selectedCategory == 'Breakfast') {
      return AppColors.bgGradientYellow;
    } else if (selectedCategory == 'Dinner') {
      return AppColors.bgGradientBlue;
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
        child: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  // Scrollable Content
                  Positioned.fill(
                    child: RefreshIndicator(
                      onRefresh: _onRefresh,
                      color: dietFilter == DietFilter.nonVeg ? AppColors.primaryRed : AppColors.primary,
                      backgroundColor: Colors.white,
                      displacement: 420,
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          // Spacer for the fixed header
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 500), 
                          ),
                  // Stable kitchen list from Supabase
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
                                  Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textSub.withOpacity(0.5)),
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
                        return const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(child: CircularProgressIndicator()),
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
                                  Icon(Icons.storefront_outlined, size: 64, color: AppColors.textSub.withOpacity(0.3)),
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
                              final double bottomSpacing = MediaQuery.of(context).padding.bottom + 90;
                              return SizedBox(height: bottomSpacing);
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
                ],
              ),
            ),

          // Fixed Header
          Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ColorFilter.mode(
                    Colors.white.withOpacity(0.1),
                    BlendMode.srcOver,
                  ),
                  child: Container(
                    padding: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.primary.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomAppBar(
                            dietFilter: dietFilter, 
                            onFilterChanged: (f) => setState(() => dietFilter = f)
                          ),
                          const SizedBox(height: 12),
                          HeroBanner(
                            key: _heroBannerKey, 
                            isVeg: dietFilter != DietFilter.nonVeg
                          ),
                          const SizedBox(height: 20),
                          CategorySelector(
                            selectedCategory: selectedCategory,
                            onCategorySelected: onCategorySelected,
                            isVeg: dietFilter != DietFilter.nonVeg,
                          ),
                          const SizedBox(height: 24),
                          // "All Kitchens" now fixed as well
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'all_kitchens'.tr(context),
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
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
