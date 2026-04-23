import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'basket_screen.dart';
import 'premium_screen.dart';
import 'wallet_screen.dart';
import 'ai_chat_screen.dart';
import '../widgets/custom_bottom_nav.dart';
import '../widgets/cart_toast.dart';
import '../widgets/active_order_banner.dart';

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



    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Screen Content
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              if (index != 0) {
                setState(() => _currentIndex = index);
              }
            },
            physics: const BouncingScrollPhysics(), // Allow slide change screens
            children: _screens,
          ),

          // Persistent Bottom Navigation (rendered first so toasts appear on top)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: CustomBottomNav(
              currentIndex: _currentIndex,
              onTap: _onTabTapped,
              isVeg: true, // This could be made dynamic if needed
            ),
          ),

          // Global Toasts (positioned above nav bar, rendered AFTER nav so they are on top)
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 85,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ActiveOrderBanner(),
                CartToast(onTap: () => _onTabTapped(1)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
