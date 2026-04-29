import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'basket_screen.dart';
import 'premium_screen.dart';
import 'wallet_screen.dart';
import 'ai_chat_screen.dart';
import '../widgets/custom_bottom_nav.dart';
import '../widgets/global_overlay.dart';
import '../services/cart_service.dart';
import '../services/order_status_notifier.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 2; // Home is index 2
  final PageController _pageController = PageController(initialPage: 2);


  final List<Widget> _screens = [
    const SizedBox.shrink(), // Placeholder for AI (handled via Navigator)
    const BasketScreen(),
    const HomeScreen(),
    const PremiumScreen(),
    const WalletScreen(),
  ];

  void _onTabTapped(int index) {
    if (index == 0) {
      // AI Chat is a full-screen push
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AiChatScreen()),
      );
      return;
    }

    // If we are navigating to the basket (index 1) via a toast/banner
    // and we're currently on a pushed screen (like KitchenDetail), 
    // we need to pop back to the root first.
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }

    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
    _syncGlobalOverlay();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              if (index != 0) {
                setState(() => _currentIndex = index);
                _syncGlobalOverlay();
              }
            },
            physics: const BouncingScrollPhysics(),
            children: _screens,
          ),

        ],
      ),


      bottomNavigationBar: CustomBottomNav(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        isVeg: true,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant MainLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncGlobalOverlay();
  }

  @override
  void initState() {
    super.initState();
    CartService.instance.addListener(_syncGlobalOverlay);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncGlobalOverlay());
    // Start listening for order status changes → push notifications
    OrderStatusNotifier().start();
  }

  @override
  void dispose() {
    CartService.instance.removeListener(_syncGlobalOverlay);
    OrderStatusNotifier().stop();
    _pageController.dispose();
    super.dispose();
  }

  void _syncGlobalOverlay() {
    if (!mounted) return;
    final hasItems = CartService.instance.totalItems > 0;
    final bottomPadding = 100 + MediaQuery.of(context).padding.bottom;
    
    GlobalOverlayController.showCartToast(
      show: _currentIndex != 1 && hasItems,
      onTap: () => _onTabTapped(1),
      bottomPadding: bottomPadding,
    );
  }
}
