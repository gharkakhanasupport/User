import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/cart_service.dart';
import '../models/cart_item.dart';
import 'checkout_screen.dart';

/// Full-screen cart page showing items grouped by kitchen.
class MultiCartScreen extends StatefulWidget {
  const MultiCartScreen({super.key});

  @override
  State<MultiCartScreen> createState() => _MultiCartScreenState();
}

class _MultiCartScreenState extends State<MultiCartScreen> {
  @override
  void initState() {
    super.initState();
    CartService.instance.addListener(_refresh);
  }

  @override
  void dispose() {
    CartService.instance.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cart = CartService.instance;
    final groups = cart.cartByKitchen;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Your Cart',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (cart.totalItems > 0)
            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Clear Cart?'),
                    content: const Text('Remove all items from your cart?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () {
                          CartService.instance.clearCart();
                          Navigator.pop(context);
                        },
                        child: const Text('Clear', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
              child: Text(
                'Clear All',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.red.shade400,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
      body: cart.totalItems == 0 ? _buildEmptyState() : _buildCartList(groups),
      bottomNavigationBar: cart.totalItems > 0 ? _buildBottomBar(cart) : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Your cart is empty',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Browse kitchens and add delicious items!',
            style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: Text('Browse Kitchens', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildCartList(Map<String, KitchenCartGroup> groups) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...groups.entries.map((entry) => _buildKitchenGroup(entry.value)),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildKitchenGroup(KitchenCartGroup group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity( 0.04), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kitchen header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withOpacity( 0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.restaurant, size: 18, color: Color(0xFF16A34A)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    group.kitchenName,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF16A34A),
                    ),
                  ),
                ),
                Text(
                  '${group.itemCount} items',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          // Items
          ...group.items.map((item) => _buildItemRow(item)),
          // Subtotal
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Subtotal',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                ),
                Text(
                  '\u20B9${group.subtotal.toStringAsFixed(0)}',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(CartItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                ? Image.network(item.imageUrl!, width: 48, height: 48, fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _placeholderImage())
                : _placeholderImage(),
          ),
          const SizedBox(width: 12),
          // Name + price
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.dishName,
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.priceText,
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          // Quantity stepper
          Container(
            height: 32,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF16A34A)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => CartService.instance.adjustQuantity(item.dishId, item.cookId, -1),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Icon(Icons.remove, size: 16, color: Color(0xFF16A34A)),
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(minWidth: 28),
                  alignment: Alignment.center,
                  child: Text(
                    '${item.quantity}',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF16A34A)),
                  ),
                ),
                InkWell(
                  onTap: item.quantity < 10
                      ? () => CartService.instance.adjustQuantity(item.dishId, item.cookId, 1)
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Icon(Icons.add, size: 16, color: item.quantity < 10 ? const Color(0xFF16A34A) : Colors.grey),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Line total
          SizedBox(
            width: 55,
            child: Text(
              '\u20B9${item.lineTotal.toStringAsFixed(0)}',
              textAlign: TextAlign.right,
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderImage() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.fastfood_outlined, color: Colors.grey.shade400, size: 24),
    );
  }

  Widget _buildBottomBar(CartService cart) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity( 0.05), blurRadius: 10, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Grand Total',
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.grey),
                    ),
                    Text(
                      '\u20B9${cart.totalPrice.toStringAsFixed(0)}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CheckoutScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      elevation: 4,
                      shadowColor: const Color(0xFF16A34A).withOpacity( 0.3),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Checkout',
                          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
