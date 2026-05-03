import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'active_order_banner.dart';
import '../services/cart_service.dart';
import '../screens/basket_screen.dart';

class GlobalOverlay extends StatefulWidget {
  final Widget child;
  const GlobalOverlay({super.key, required this.child});

  @override
  State<GlobalOverlay> createState() => GlobalOverlayState();
}

class GlobalOverlayState extends State<GlobalOverlay> {
  double _bottomPadding = 10;
  bool _isTemporaryShift = false;
  bool _isVisible = true;

  void updateOverlay({double? bottomPadding, bool? isTemporaryShift, bool? isVisible}) {
    if (mounted) {
      setState(() {
        if (bottomPadding != null) _bottomPadding = bottomPadding;
        if (isTemporaryShift != null) _isTemporaryShift = isTemporaryShift;
        if (isVisible != null) _isVisible = isVisible;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        ListenableBuilder(
          listenable: CartService.instance,
          builder: (context, _) {
            final bool isAuth = Supabase.instance.client.auth.currentUser != null;
            final cartItems = CartService.instance.totalItems;
            final totalPrice = CartService.instance.totalPrice;

            if (!_isVisible) return const SizedBox.shrink();
            if (!isAuth && cartItems == 0) return const SizedBox.shrink();

            // Adjust padding relative to safe area
            final double bottomSafeArea = MediaQuery.of(context).padding.bottom;
            double effectivePadding = _bottomPadding + bottomSafeArea;
            
            if (_isTemporaryShift) {
              effectivePadding += 60; // Shift up for temporary notifications
            }

            return Positioned(
              bottom: effectivePadding,
              left: 0,
              right: 0,
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (cartItems > 0)
                      _buildGlobalCartBar(context, cartItems, totalPrice),
                    const ActiveOrderBanner(),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildGlobalCartBar(BuildContext context, int count, double total) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 400),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      curve: Curves.easeOutBack,
      key: ValueKey(count > 0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: GestureDetector(
              onTap: () => _navigateToCart(context),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A), // Blinkit Green
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$count ITEM${count > 1 ? 'S' : ''}',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            Text(
                              '₹${total.toStringAsFixed(0)}',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          'View Cart',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_right, color: Colors.white, size: 24),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _navigateToCart(BuildContext context) {
    // Navigate to BasketScreen directly using the global navigator key
    final nav = GlobalOverlayController.navigatorKey.currentState;
    if (nav != null) {
      nav.push(
        MaterialPageRoute(builder: (context) => const BasketScreen()),
      );
    } else {
      // Fallback if key not set
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const BasketScreen()),
      );
    }
  }
}

class GlobalOverlayController {
  static GlobalKey<GlobalOverlayState> overlayKey = GlobalKey<GlobalOverlayState>();
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static void setBottomPadding(double padding) {
    overlayKey.currentState?.updateOverlay(bottomPadding: padding);
  }

  static void showSnackbarNotification(bool active) {
    overlayKey.currentState?.updateOverlay(isTemporaryShift: active);
  }

  static void setVisible(bool visible) {
    overlayKey.currentState?.updateOverlay(isVisible: visible);
  }
}
