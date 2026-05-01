import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/main_layout.dart';
import '../services/cart_service.dart';
import '../utils/overlay_toast.dart';

/// A compact, beautiful widget that shows the user's last order
/// with a 1-tap "Reorder" button. Place this on the home screen.
class QuickReorderCard extends StatefulWidget {
  const QuickReorderCard({super.key});

  @override
  State<QuickReorderCard> createState() => _QuickReorderCardState();
}

class _QuickReorderCardState extends State<QuickReorderCard>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _lastOrder;
  bool _isLoading = true;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _loadLastOrder();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _loadLastOrder() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final result = await Supabase.instance.client
          .from('orders')
          .select()
          .eq('customer_id', userId)
          .inFilter('status', ['delivered', 'completed'])
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _lastOrder = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('QuickReorder: Error loading last order: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleReorder() {
    if (_lastOrder == null) return;

    final items = _lastOrder!['items'];
    if (items == null || items is! List || items.isEmpty) {
      OverlayToast.show(context, 'Order items not available for reorder', icon: Icons.error_outline, color: Colors.orange);
      return;
    }

    final kitchenName = (_lastOrder!['kitchen_name'] ?? 'Kitchen').toString();
    final cookId = (_lastOrder!['cook_id'] ?? '').toString();

    // Clear and populate global cart
    CartService.instance.clearCart();
    
    for (final item in items) {
      final name = (item['name'] ?? item['item_name'] ?? '').toString();
      final qty = int.tryParse((item['quantity'] ?? 1).toString()) ?? 1;
      final price = double.tryParse((item['price'] ?? item['item_price'] ?? 0).toString()) ?? 0.0;
      final image = (item['image_url'] ?? item['image'] ?? '').toString();
      final itemId = (item['item_id'] ?? item['id'] ?? '').toString();

      if (name.isEmpty || itemId.isEmpty) continue;

      CartService.instance.addItem(
        dishId: itemId,
        dishName: name,
        price: price,
        cookId: cookId,
        kitchenName: kitchenName,
        imageUrl: image,
      );
      
      if (qty > 1) {
        // Update to the correct quantity
        try {
          final added = CartService.instance.items.firstWhere((i) => i.dishId == itemId);
          CartService.instance.updateQuantity(added.id, qty);
        } catch (_) {}
      }
    }

    OverlayToast.show(context, 'Items added to cart', icon: Icons.shopping_bag, quantity: items.length, color: const Color(0xFF16A34A));

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const MainLayout(initialIndex: 1),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox.shrink(); // Don't show loader, just hide
    }

    if (_lastOrder == null) {
      return const SizedBox.shrink(); // No past orders
    }

    final items = _lastOrder!['items'];
    final kitchenName =
        (_lastOrder!['kitchen_name'] ?? 'Kitchen').toString();
    final total =
        (_lastOrder!['total_amount'] ?? _lastOrder!['total'] ?? 0);

    // Build item summary text
    String itemSummary = '';
    if (items is List && items.isNotEmpty) {
      final names = items
          .take(3)
          .map((i) => i['name'] ?? i['item_name'] ?? '')
          .where((n) => n.toString().isNotEmpty)
          .toList();
      itemSummary = names.join(', ');
      if (items.length > 3) {
        itemSummary += ' +${items.length - 3} more';
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF0FDF4), Color(0xFFECFDF5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBBF7D0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16A34A).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _handleReorder,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.replay_rounded,
                    color: Color(0xFF16A34A),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              kitchenName,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF14532D),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '₹$total',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                      if (itemSummary.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          itemSummary,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: const Color(0xFF166534),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Reorder button
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF16A34A)
                            .withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shopping_cart_rounded,
                          color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Reorder',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
