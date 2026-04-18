import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/order_service.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;
  final String kitchenName;

  const OrderTrackingScreen({
    super.key,
    required this.orderId,
    required this.kitchenName,
  });

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final _orderService = OrderService();

  static const _statusSteps = ['pending', 'accepted', 'preparing', 'ready', 'completed'];

  int _statusIndex(String status) {
    final idx = _statusSteps.indexOf(status);
    return idx >= 0 ? idx : 0;
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_top_rounded;
      case 'accepted':
        return Icons.thumb_up_alt_rounded;
      case 'preparing':
        return Icons.restaurant_rounded;
      case 'ready':
        return Icons.check_circle_rounded;
      case 'completed':
        return Icons.done_all_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.blue;
      case 'preparing':
        return Colors.amber.shade700;
      case 'ready':
        return const Color(0xFF16A34A);
      case 'completed':
        return const Color(0xFF16A34A);
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusTitle(String status) {
    switch (status) {
      case 'pending':
        return 'Order Placed';
      case 'accepted':
        return 'Order Accepted';
      case 'preparing':
        return 'Preparing Your Food';
      case 'ready':
        return 'Ready for Pickup';
      case 'completed':
        return 'Order Delivered';
      case 'rejected':
        return 'Order Rejected';
      default:
        return 'Processing';
    }
  }

  String _statusSubtitle(String status) {
    switch (status) {
      case 'pending':
        return 'Waiting for the kitchen to accept your order...';
      case 'accepted':
        return 'The kitchen has accepted your order!';
      case 'preparing':
        return 'Your delicious food is being cooked...';
      case 'ready':
        return 'Your order is ready for pickup/delivery!';
      case 'completed':
        return 'Your order has been delivered. Enjoy!';
      case 'rejected':
        return 'Unfortunately, the kitchen could not accept your order.';
      default:
        return 'Please wait...';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Track Order', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _orderService.getOrderStream(widget.orderId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF16A34A)));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('Order not found', style: GoogleFonts.plusJakartaSans(fontSize: 16, color: Colors.grey)),
                ],
              ),
            );
          }

          final order = snapshot.data!.first;
          final status = (order['status'] ?? 'pending').toString();
          final isRejected = status == 'rejected';
          final currentStep = _statusIndex(status);
          final items = order['items'] as List<dynamic>? ?? [];
          final totalAmount = (order['total_amount'] ?? 0).toString();
          final deliveryAddress = (order['delivery_address'] ?? 'Not provided').toString();
          final createdAt = DateTime.tryParse(order['created_at'] ?? '');

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Header Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _statusColor(status).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Icon(_statusIcon(status), size: 56, color: _statusColor(status)),
                      const SizedBox(height: 12),
                      Text(
                        _statusTitle(status),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _statusColor(status),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _statusSubtitle(status),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Progress Stepper (not shown for rejected)
                if (!isRejected) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Order Progress', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        ...List.generate(_statusSteps.length, (i) {
                          final stepStatus = _statusSteps[i];
                          final isCompleted = i <= currentStep;
                          final isActive = i == currentStep;
                          final color = isCompleted ? const Color(0xFF16A34A) : Colors.grey.shade300;

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isActive ? color : (isCompleted ? color : Colors.grey.shade100),
                                      border: Border.all(color: color, width: 2),
                                    ),
                                    child: isCompleted
                                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                                        : null,
                                  ),
                                  if (i < _statusSteps.length - 1)
                                    Container(
                                      width: 2,
                                      height: 32,
                                      color: i < currentStep ? const Color(0xFF16A34A) : Colors.grey.shade200,
                                    ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                    _statusTitle(stepStatus),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                                      color: isCompleted ? Colors.black87 : Colors.grey.shade400,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Kitchen Info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.restaurant, color: Color(0xFF16A34A)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.kitchenName, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 15)),
                            if (createdAt != null)
                              Text(
                                'Ordered at ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}',
                                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Order Items
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Order Details', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      ...items.map((item) {
                        final itemMap = item is Map ? item : {};
                        final name = itemMap['name'] ?? 'Item';
                        final qty = itemMap['quantity'] ?? 1;
                        final price = itemMap['price'] ?? 0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('$qty x', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF16A34A), fontSize: 13)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Text('$name', style: GoogleFonts.plusJakartaSans(fontSize: 14))),
                              Text('\u20B9${(price as num) * (qty as num)}', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                            ],
                          ),
                        );
                      }),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text('\u20B9$totalAmount', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A))),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Delivery Address
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on, color: Color(0xFF16A34A), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Delivery Address', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 4),
                            Text(deliveryAddress, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Back to Home Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF16A34A)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('Back to Home', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF16A34A), fontWeight: FontWeight.w600)),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}
