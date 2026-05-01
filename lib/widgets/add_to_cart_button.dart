import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/cart_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/phone_verification_screen.dart';
import '../services/config_service.dart';

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

  void _add() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user != null) {
      try {
        final userData = await supabase.from('users').select('phone_verified').eq('id', user.id).maybeSingle();
        final isOtpEnabled = ConfigService().isOtpEnabled;
        
        if (userData != null && userData['phone_verified'] != true && isOtpEnabled) {
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PhoneVerificationScreen()),
            );
          }
          return;
        }
      } catch (e) {
        debugPrint('Error checking phone verification: $e');
      }
    }

    final result = CartService.instance.addItem(
      dishId: widget.dishId,
      dishName: widget.dishName,
      price: widget.price,
      cookId: widget.cookId,
      kitchenName: widget.kitchenName,
      imageUrl: widget.imageUrl,
    );

    if (result == 'different_kitchen') {
      // Show dialog asking user to replace cart
      _showReplaceCartDialog();
      return;
    }

    _bounce();
    widget.onChanged?.call();
  }

  void _showReplaceCartDialog() {
    final existingKitchen = CartService.instance.items.isNotEmpty
        ? CartService.instance.items.first.kitchenName
        : 'another kitchen';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Replace cart items?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text(
          'Your cart has items from "$existingKitchen". Do you want to clear them and add items from "${widget.kitchenName}" instead?',
          style: GoogleFonts.plusJakartaSans(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('No', style: GoogleFonts.plusJakartaSans(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              CartService.instance.clearCart();
              CartService.instance.addItem(
                dishId: widget.dishId,
                dishName: widget.dishName,
                price: widget.price,
                cookId: widget.cookId,
                kitchenName: widget.kitchenName,
                imageUrl: widget.imageUrl,
              );
              _bounce();
              widget.onChanged?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Yes, Replace', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _increment() {
    CartService.instance.adjustQuantity(widget.dishId, widget.cookId, 1);
    _bounce();
    widget.onChanged?.call();
  }


  void _decrement() {
    CartService.instance.adjustQuantity(widget.dishId, widget.cookId, -1);
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final qty = _qty;

    return ScaleTransition(
      scale: _bounceAnimation,
      child: Container(
        height: 38,
        width: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF16A34A).withValues(alpha: 0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: qty == 0
            ? Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _add,
                  borderRadius: BorderRadius.circular(10),
                  child: Center(
                    child: Text(
                      'ADD',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF16A34A),
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _stepperButton(Icons.remove, _decrement),
                  Text(
                    '$qty',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF16A34A),
                    ),
                  ),
                  _stepperButton(Icons.add, qty < 10 ? _increment : null),
                ],
              ),
      ),
    );
  }

  Widget _stepperButton(IconData icon, VoidCallback? onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Icon(
            icon,
            size: 18,
            color: onTap != null ? const Color(0xFF16A34A) : Colors.grey[300],
          ),
        ),
      ),
    );
  }
}
