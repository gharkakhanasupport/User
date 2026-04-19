import 'package:flutter/material.dart';
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


  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
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
        ? cart.cartByKitchen.values.first.kitchenName
        : '$kitchenCount kitchens';

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF16A34A), Color(0xFF15803D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
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
                      '${cart.totalItems} item${cart.totalItems > 1 ? 's' : ''}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Kitchen label
                  Expanded(
                    child: Text(
                      kitchenLabel,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Total price
                  Text(
                    '\u20B9${cart.totalPrice.toStringAsFixed(0)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
