import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/hero_banner.dart';
import '../widgets/category_selector.dart';
import '../widgets/kitchen_card.dart';
import '../widgets/custom_bottom_nav.dart';
import '../services/kitchen_service.dart';
import '../models/kitchen.dart';
import 'category_transition_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}


class _HomeScreenState extends State<HomeScreen> {
  bool isVeg = true;
  String selectedCategory = 'Lunch';
  RealtimeChannel? _banSubscription;
  final GlobalKey<HeroBannerState> _heroBannerKey = GlobalKey<HeroBannerState>();
  bool _isRefreshing = false;
  final KitchenService _kitchenService = KitchenService();

  @override
  void initState() {
    super.initState();
    _checkBanStatus();
    _setupBanListener();
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
        const SnackBar(
          content: Text('Your account has been suspended. Contact support.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
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

  void toggleTheme() {
    setState(() {
      isVeg = !isVeg;
    });
  }

  void onCategorySelected(String category) {
    setState(() {
      selectedCategory = category;
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryTransitionScreen(categoryName: category),
      ),
    );
  }

  /// Pull-to-refresh handler
  Future<void> _onRefresh() async {
    setState(() => _isRefreshing = true);
    
    // Reload banners
    _heroBannerKey.currentState?.loadBanners();
    
    // Simulate minimum refresh time for UX
    await Future.delayed(const Duration(milliseconds: 800));
    
    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  LinearGradient getBackgroundGradient() {
    if (selectedCategory == 'Breakfast') {
      return AppColors.bgGradientYellow;
    } else if (selectedCategory == 'Dinner') {
      return AppColors.bgGradientBlue;
    } else if (selectedCategory == 'Lunch') {
      // For Lunch, we can use Orange or fallback to the Veg/Non-Veg Green/Red
       return isVeg ? AppColors.bgGradientLight : AppColors.bgGradientRed;
    }
    // Default fallback
    return isVeg ? AppColors.bgGradientLight : AppColors.bgGradientRed;
  }

  @override
  Widget build(BuildContext context) {
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
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                color: isVeg ? AppColors.primary : AppColors.primaryRed,
                backgroundColor: Colors.white,
                displacement: 40,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomAppBar(isVeg: isVeg, onToggle: toggleTheme),
                          const SizedBox(height: 12),
                          HeroBanner(key: _heroBannerKey, isVeg: isVeg),
                          const SizedBox(height: 24),
                          CategorySelector(
                            selectedCategory: selectedCategory,
                            onCategorySelected: onCategorySelected,
                            isVeg: isVeg,
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'All Kitchens Near You',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textMain,
                            ),
                          ),
                          Text(
                            'View all',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isVeg ? AppColors.primary : AppColors.primaryRed,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  // Real-time kitchen list from Supabase
                  StreamBuilder<List<Kitchen>>(
                    stream: _kitchenService.getAllKitchensStream(),
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
                                    'Connection Timeout',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textMain,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Unable to connect to live updates.\nPlease check your internet.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSub),
                                  ),
                                  const SizedBox(height: 20),
                                  ElevatedButton(
                                    onPressed: () => setState(() {}),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: const Text('Retry Connection'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      if (!snapshot.hasData) {
                        return const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        );
                      }

                      final allKitchens = snapshot.data!;
                      final kitchens = isVeg
                          ? allKitchens.where((k) => k.isVegetarian).toList()
                          : allKitchens;

                      if (kitchens.isEmpty) {
                        return SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Center(
                              child: Text(
                                'No kitchens available yet',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: AppColors.textSub,
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      return SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index == kitchens.length) {
                              return const SizedBox(height: 100);
                            }
                            final k = kitchens[index];
                            return KitchenCard(
                              cookId: k.cookId,
                              title: k.kitchenName,
                              subtitle: k.subtitle,
                              imageUrl: k.displayImage ?? 'https://via.placeholder.com/150',
                              rating: k.ratingText,
                              price: '${k.totalOrders} orders',
                              time: k.isAvailable ? 'Open Now' : 'Closed',
                              isVeg: k.isVegetarian,
                              tag: k.isVegetarian ? 'Pure Veg' : null,
                              tagColor: k.isVegetarian ? Colors.green : null,
                              isClosed: !k.isAvailable,
                              kitchenPhotos: k.kitchenPhotos,
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
            
            // Fixed Bottom Nav
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: CustomBottomNav(isVeg: isVeg),
            ),
          ],
        ),
      ),
    );
  }
}
