import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'active_order_banner.dart';
import '../services/cart_service.dart';
import '../theme/app_colors.dart';
import '../screens/main_layout.dart';

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
    // Find the last added item image for the toast
    String? lastImg;
    try {
      if (CartService.instance.items.isNotEmpty) {
        lastImg = CartService.instance.items.last.imageUrl;
      }
    } catch (_) {}

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: GestureDetector(
        onTap: () {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const MainLayout(initialIndex: 1)),
            (route) => false,
          );
        },
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFF16A34A), // Blinkit solid green
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 8),
              // Image section
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.network(
                    lastImg != null && lastImg.isNotEmpty ? lastImg : 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c',
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(Icons.fastfood, color: Color(0xFF16A34A), size: 20),
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Text section
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'View cart',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '$count item${count > 1 ? 's' : ''} • ₹${total.toStringAsFixed(0)}',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Arrow section
              const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 28),
              const SizedBox(width: 16),
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
