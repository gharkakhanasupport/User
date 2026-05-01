import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'active_order_banner.dart';
import '../services/cart_service.dart';

class GlobalOverlay extends StatefulWidget {
  final Widget child;
  const GlobalOverlay({super.key, required this.child});

  @override
  State<GlobalOverlay> createState() => GlobalOverlayState();
}

class GlobalOverlayState extends State<GlobalOverlay> {
  double _bottomPadding = 10;

  void updateOverlay({double? bottomPadding}) {
    if (mounted) {
      setState(() {
        if (bottomPadding != null) _bottomPadding = bottomPadding;
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

            if (!isAuth && cartItems == 0) return const SizedBox.shrink();

            return Positioned(
              bottom: _bottomPadding,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (cartItems > 0)
                    _buildGlobalCartBar(context, cartItems, totalPrice),
                  const ActiveOrderBanner(),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildGlobalCartBar(BuildContext context, int count, double total) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween<double>(begin: 0.95, end: 1.0),
      curve: Curves.elasticOut,
      key: ValueKey(count),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.shopping_basket_outlined, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$count ITEM${count > 1 ? 'S' : ''}',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        '₹${total.toStringAsFixed(0)}',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                       Navigator.pushNamed(context, '/basket');
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View Cart',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class GlobalOverlayController {
  static GlobalKey<GlobalOverlayState> overlayKey = GlobalKey<GlobalOverlayState>();

  static void setBottomPadding(double padding) {
    overlayKey.currentState?.updateOverlay(bottomPadding: padding);
  }
}
