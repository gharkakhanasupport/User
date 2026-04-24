import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/cart_service.dart';

/// Smart floating toast bar shown at bottom of screen when cart has items.
/// Shows item count, total price, and navigates to cart on tap.
class CartToast extends StatefulWidget {
  final VoidCallback onTap;

  const CartToast({super.key, required this.onTap});

  @override
  State<CartToast> createState() => _CartToastState();
}

class _CartToastState extends State<CartToast> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  int _previousCount = 0;
  bool _isMinimized = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _previousCount = CartService.instance.totalItems;
    CartService.instance.addListener(_onCartUpdate);

    if (_previousCount > 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    CartService.instance.removeListener(_onCartUpdate);
    _controller.dispose();
    super.dispose();
  }

  void _onCartUpdate() {
    if (!mounted) return;
    final newCount = CartService.instance.totalItems;

    if (newCount > 0 && _previousCount == 0) {
      _controller.forward();
    } else if (newCount == 0 && _previousCount > 0) {
      _controller.reverse();
    }
    
    _previousCount = newCount;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cart = CartService.instance;
    if (cart.totalItems == 0 && !_controller.isAnimating) {
      return const SizedBox.shrink();
    }

    final kitchenCount = cart.kitchenCount;
    final kitchenLabel = kitchenCount == 1
        ? (cart.cartByKitchen.isNotEmpty ? cart.cartByKitchen.values.first.kitchenName : 'Kitchen')
        : '$kitchenCount kitchens';

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: _isMinimized ? _buildMinimized(cart) : _buildExpanded(cart, kitchenLabel),
        ),
      ),
    );
  }

  Widget _buildMinimized(CartService cart) {
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _isMinimized = false);
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF16A34A), Color(0xFF15803D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF16A34A).withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 26),
              if (cart.totalItems > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${cart.totalItems}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.none, // Prevent yellow double lines
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpanded(CartService cart, String kitchenLabel) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF16A34A), Color(0xFF15803D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16A34A).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Row(
          children: [
            // Main clickable area for the cart
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    widget.onTap();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        // Item count badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${cart.totalItems}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Label & Price
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'View Basket',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              Text(
                                kitchenLabel,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontWeight: FontWeight.w500,
                                  decoration: TextDecoration.none,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '\u20B9${cart.totalPrice.toStringAsFixed(0)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Explicit vertical separator
            Container(
              height: 30,
              width: 1,
              color: Colors.white.withValues(alpha: 0.15),
            ),
            // Close button area
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _isMinimized = true);
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Icon(Icons.close_rounded, color: Colors.white, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
