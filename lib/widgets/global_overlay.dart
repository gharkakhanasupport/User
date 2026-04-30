import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'active_order_banner.dart';
import '../services/cart_service.dart';
import '../theme/app_colors.dart';

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
    final bool isAuth = Supabase.instance.client.auth.currentUser != null;
    
    return Stack(
      children: [
        widget.child,
        
        if (isAuth)
          Positioned(
            bottom: _bottomPadding,
            left: 0,
            right: 0,
            child: ListenableBuilder(
              listenable: CartService.instance,
              builder: (context, _) {
                final cartItems = CartService.instance.totalItems;
                final totalPrice = CartService.instance.totalPrice;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (cartItems > 0)
                      _buildGlobalCartBar(context, cartItems, totalPrice),
                    const ActiveOrderBanner(),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildGlobalCartBar(BuildContext context, int count, double total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: GestureDetector(
        onTap: () {
          // This bar is global, so it doesn't know about MainLayout's tab selection.
          // But it can notify or we can just let the user see it.
          // Tapping it could open a Cart Bottom Sheet or navigate to a Cart Screen.
          // For now, it serves as the "Add to Cart" confirmation.
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
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
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.shopping_basket, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$count ${count == 1 ? 'ITEM' : 'ITEMS'}',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        '₹${total.toStringAsFixed(0)}',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    'VIEW CART',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 12),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GlobalOverlayController {
  static GlobalKey<GlobalOverlayState> overlayKey = GlobalKey<GlobalOverlayState>();

  static void setBottomPadding(double padding) {
    overlayKey.currentState?.updateOverlay(bottomPadding: padding);
  }
}
