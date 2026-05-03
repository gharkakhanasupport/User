import 'package:flutter/material.dart';
import '../widgets/global_overlay.dart';

import 'home_screen.dart';
import 'basket_screen.dart';
import 'premium_screen.dart';
import 'my_wallet_screen.dart';
import 'ai_chat_screen.dart';
import '../widgets/custom_bottom_nav.dart';
import '../widgets/update_overlay.dart';
import '../services/order_status_notifier.dart';
import '../services/in_app_update_service.dart';

class MainLayout extends StatefulWidget {
  final int initialIndex;
  const MainLayout({super.key, this.initialIndex = 2});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  late int _currentIndex;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    
    // Start listening for order status changes → push notifications
    OrderStatusNotifier().start();
    // Check for updates in background after a short delay
    Future.delayed(const Duration(seconds: 3), () {
      InAppUpdateService.instance.checkForUpdate();
    });

    // Set bottom padding for Global Cart Overlay to stay above BottomNav
    WidgetsBinding.instance.addPostFrameCallback((_) {
      GlobalOverlayController.setBottomPadding(95);
    });
  }

  final List<Widget> _screens = [
    const SizedBox.shrink(), // Placeholder for AI (handled via Navigator)
    const BasketScreen(),
    const HomeScreen(),
    const PremiumScreen(),
    const MyWalletScreen(),
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

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
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
    return UpdateOverlay(
      child: Scaffold(
        body: Stack(
          children: [
            PageView(
              controller: _pageController,
              onPageChanged: (index) {
                if (index != 0) {
                  setState(() => _currentIndex = index);
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
      ),
    );
  }

  @override
  void dispose() {
    // Reset bottom padding when leaving MainLayout
    GlobalOverlayController.setBottomPadding(10);
    OrderStatusNotifier().stop();
    _pageController.dispose();
    super.dispose();
  }
}
