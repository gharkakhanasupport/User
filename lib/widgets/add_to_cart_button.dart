import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/cart_service.dart';

/// Reusable Add-to-Cart button with quantity stepper.
/// Shows "ADD" when item is not in cart, quantity controls when it is.
class AddToCartButton extends StatefulWidget {
  final String dishId;
  final String dishName;
  final double price;
  final String cookId;
  final String kitchenName;
  final String? imageUrl;
  final VoidCallback? onChanged; // optional callback on any cart change

  const AddToCartButton({
    super.key,
    required this.dishId,
    required this.dishName,
    required this.price,
    required this.cookId,
    required this.kitchenName,
    this.imageUrl,
    this.onChanged,
  });

  @override
  State<AddToCartButton> createState() => _AddToCartButtonState();
}

class _AddToCartButtonState extends State<AddToCartButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _bounceAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeOut),
    );
    CartService.instance.addListener(_onCartChanged);
  }

  @override
  void dispose() {
    CartService.instance.removeListener(_onCartChanged);
    _bounceController.dispose();
    super.dispose();
  }

  void _onCartChanged() {
    if (mounted) setState(() {});
  }

  void _bounce() {
    _bounceController.forward().then((_) => _bounceController.reverse());
  }

  int get _qty => CartService.instance.getQuantity(widget.dishId, widget.cookId);

  void _add() {
    CartService.instance.addItem(
      dishId: widget.dishId,
      dishName: widget.dishName,
      price: widget.price,
      cookId: widget.cookId,
      kitchenName: widget.kitchenName,
      imageUrl: widget.imageUrl,
    );
    _bounce();
    _showFeedback('${widget.dishName} added to cart');
    widget.onChanged?.call();
  }

  void _increment() {
    CartService.instance.adjustQuantity(widget.dishId, widget.cookId, 1);
    _bounce();
    _showFeedback('Added one more ${widget.dishName}');
    widget.onChanged?.call();
  }

  void _showFeedback(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        width: 250,
      ),
    );
  }

  void _decrement() {
    CartService.instance.adjustQuantity(widget.dishId, widget.cookId, -1);
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final qty = _qty;

    if (qty == 0) {
      // "ADD" button
      return SizedBox(
        height: 36,
        child: ElevatedButton(
          onPressed: _add,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF16A34A),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
          child: Text(
            'ADD',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
      );
    }

    // Quantity stepper
    return ScaleTransition(
      scale: _bounceAnimation,
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF16A34A),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _stepperButton(Icons.remove, _decrement),
            Container(
              constraints: const BoxConstraints(minWidth: 32),
              alignment: Alignment.center,
              child: Text(
                '$qty',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            _stepperButton(Icons.add, qty < 10 ? _increment : null),
          ],
        ),
      ),
    );
  }

  Widget _stepperButton(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Icon(
          icon,
          size: 20,
          color: onTap != null ? Colors.white : Colors.white38,
        ),
      ),
    );
  }
}
