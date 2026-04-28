import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/hero_banner.dart';
import '../widgets/category_selector.dart';
import '../widgets/kitchen_card.dart';
import '../widgets/custom_bottom_nav.dart';
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
    // Reload banners
    _heroBannerKey.currentState?.loadBanners();
    
    // Simulate minimum refresh time for UX
    await Future.delayed(const Duration(milliseconds: 800));
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
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  SliverList(
                    delegate: SliverChildListDelegate([
                      const KitchenCard(
                        title: 'Aunty\'s Kitchen',
                        subtitle: 'North Indian • Homestyle',
                        imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAKeai1aQcCxJF6PiIxo9YICjQKgnQ6ONfpY8OEu1JQ2yNrvdx1DEfBs-R8rPr_8-1sGe40VF2wCCf99JVU6nTukN-m5BaO04HbSgxLMmCGXXZbvdAnDe29v-YOWjC0Tn7ndct6j2AYPjb8rH_SunK23vSeVA37kwOsE4KwF5Agje6Rqh2YiV05AfCL9RORQE3aGRCEpEn60uAk4EPd6_ZJFoeVvlrOxUYo8bBdTEDUEokmkFQASpvsG_GaX0GU8-4ObHUGKE_TRQj_',
                        rating: '4.8',
                        price: '₹120 for Thali',
                        time: '35 mins',
                        isVeg: true,
                        tag: 'Pure Veg',
                        tagColor: Colors.green,
                        secondaryTag: 'Today\'s Special',
                        secondaryTagColor: Colors.yellow,
                      ),
                      const KitchenCard(
                        title: 'Desi Delight',
                        subtitle: 'Maharashtrian • Spicy',
                        imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuBgRI_BJa7g7D6iYGRDARjUQU2PKdEykXLQo3nnbCvbW5SP8MSDgk-pd1bHYAJZoayBmFkb-si1DSAR3W4xIW95ZXE70e1zEfmmYwp4bQY-MzD9Q_tuUCYZEgthKp1u1wgU7nqkoNEqm9CL7Ogno5MdS_I1c2O3F2Izq1xz_xJqRwJwiXdjumD1S5CAhf3CAzsxrGqgqULINYVKeHYRseMVWDZ66cNKDiT3WQg-x1NlKGZdbRuYWgZ-wPhCSdA0fv84IFxglkThGL7U',
                        rating: '4.5',
                        price: '₹90 Puran Poli',
                        time: '25 mins',
                        isVeg: true,
                        tag: 'Best Seller',
                        tagColor: Colors.orange,
                        secondaryTag: 'Healthy',
                        secondaryTagColor: Colors.blue,
                      ),
                      const KitchenCard(
                         title: 'Maa Ka Pyaar',
                        subtitle: 'South Indian • Idli Dosa',
                        imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAOyk4HRArbDVTgmGiPXUSFi7fMS60jmQYMAPC0j-doNlMdaKTHQMpNUanOvYhv5pKKRwGDreCqlGIwWxeTiGDaDOQjVR9fed9y5sJvvlRqkxs0Uyy-f8miBp79D7ycgpJza9SwiHZQvV3xeiJkzVVi1hxYocpHbJd_OaO5IGwcZfI8piYNSEqVSsIunSB5_LvMh2WOZfzvJGuv-z4Cw-RocfixYp-SOkswiPrwR7EYfsM-FDAV9U7d2sp4hcl6zXOk_lLYNpKlsOip',
                        rating: '4.2',
                        price: '₹80 Combo',
                        time: 'Opens 7PM',
                        isVeg: true,
                        tag: 'Hygiene+',
                        tagColor: Colors.green,
                        isClosed: true,
                      ),
                      const SizedBox(height: 100), // Space for Custom Bottom Nav
                    ]),
                  ),
                  ],
                ),
              ),
            ),
            
            // Fixed Bottom Nav
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: CustomBottomNav(),
            ),
          ],
        ),
      ),
    );
  }
}
