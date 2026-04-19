import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_screen.dart';
import 'my_orders_screen.dart';

/// Shown after successful placement of split orders.
class OrderConfirmationScreen extends StatelessWidget {
  final List<Map<String, dynamic>> orderResults;

  const OrderConfirmationScreen({super.key, required this.orderResults});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const SizedBox(height: 40),
                    // Success animation
                    Center(
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          color: Color(0xFF16A34A),
                          size: 60,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Order Placed!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF16A34A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      orderResults.length == 1
                          ? 'Your order has been sent to the kitchen'
                          : 'Your orders from ${orderResults.length} kitchens have been placed',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Order cards
                    ...orderResults.map((order) => _buildOrderCard(context, order)),
                  ],
                ),
              ),
              // Bottom buttons
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const MyOrdersScreen()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            'Track Orders',
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (_) => const HomeScreen()),
                              (route) => false,
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF16A34A),
                            side: const BorderSide(color: Color(0xFF16A34A)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            'Back to Home',
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, Map<String, dynamic> order) {
    final orderId = (order['order_id'] ?? '').toString();
    final kitchenName = order['kitchen_name'] ?? 'Kitchen';
    final total = (order['total'] ?? 0).toDouble();
    final shortId = orderId.length > 8 ? orderId.substring(0, 8) : orderId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.restaurant, color: Color(0xFF16A34A), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kitchenName,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '#$shortId',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: orderId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Order ID copied!'),
                            duration: Duration(seconds: 1),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: Icon(Icons.copy_rounded, size: 12, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\u20B9${total.toStringAsFixed(0)}',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Pending',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.amber.shade800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
