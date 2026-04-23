import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'active_order_banner.dart';
import 'cart_toast.dart';

class GlobalOverlay extends StatefulWidget {
  final Widget child;
  const GlobalOverlay({super.key, required this.child});

  @override
  State<GlobalOverlay> createState() => GlobalOverlayState();
}

class GlobalOverlayState extends State<GlobalOverlay> {

  double _bottomPadding = 10;
  bool _showCartToast = false;
  VoidCallback? _onCartTap;

  void updateOverlay({required bool showCart, VoidCallback? onCartTap, double? bottomPadding}) {
    if (mounted) {
      setState(() {
        _showCartToast = showCart;
        _onCartTap = onCartTap;
        if (bottomPadding != null) _bottomPadding = bottomPadding;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Basic route check - don't show on splash or login
    final bool isAuth = Supabase.instance.client.auth.currentUser != null;
    
    // We no longer override MediaQuery padding globally as it causes double-padding 
    // issues with Scaffold and CustomBottomNav. Instead, we let the Scaffold
    // handle the bottom area naturally.
    
    return Stack(
      children: [
        widget.child,
        
        // Persistent Overlays - Only if logged in
        if (isAuth)
          Positioned(
            bottom: _bottomPadding,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ActiveOrderBanner(),
                if (_showCartToast)
                  CartToast(onTap: () {
                    _onCartTap?.call();
                  }),
              ],
            ),
          ),
      ],
    );
  }
}

// Global handle to control the overlay
class GlobalOverlayController {
  static GlobalKey<GlobalOverlayState> overlayKey = GlobalKey<GlobalOverlayState>();

  static void showCartToast({required bool show, VoidCallback? onTap, double? bottomPadding}) {
    overlayKey.currentState?.updateOverlay(showCart: show, onCartTap: onTap, bottomPadding: bottomPadding);
  }

  static void setBottomPadding(double padding) {
    overlayKey.currentState?.updateOverlay(
      showCart: overlayKey.currentState?._showCartToast ?? false,
      onCartTap: overlayKey.currentState?._onCartTap,
      bottomPadding: padding,
    );
  }
}
