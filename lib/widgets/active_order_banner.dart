import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/order_service.dart';
import '../core/localization.dart';
import '../screens/order_tracking_screen.dart';
import '../core/constants.dart';

/// A persistent, rich banner that shows when the user has one or more active orders.
/// Supports a carousel (PageView) for multiple simultaneous orders.
/// Displays: order items/qty, ETA/status, tap to open tracking.
class ActiveOrderBanner extends StatefulWidget {
  const ActiveOrderBanner({super.key});

  @override
  State<ActiveOrderBanner> createState() => ActiveOrderBannerState();
}

class ActiveOrderBannerState extends State<ActiveOrderBanner>
    with SingleTickerProviderStateMixin {
  final OrderService _orderService = OrderService();
  StreamSubscription? _sub;
  List<Map<String, dynamic>> _activeOrders = [];
  late AnimationController _animCtrl;
  late Animation<Offset> _slideAnim;
  bool _isMinimized = false;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.elasticOut));

    _subscribeToStream();
  }

  /// Public method: cancel existing stream and re-subscribe (called on pull-to-refresh).
  void refreshStream() {
    _sub?.cancel();
    _subscribeToStream();
  }

  void _subscribeToStream() {
    _sub = _orderService.getActiveOrderDetailsStream().listen((orders) {
      if (!mounted) return;
      final hadOrders = _activeOrders.isNotEmpty;
      
      if (orders.isNotEmpty) {
        setState(() => _activeOrders = orders);
        if (!hadOrders) {
          _animCtrl.forward();
        }
      } else if (hadOrders && orders.isEmpty) {
        _animCtrl.reverse().then((_) {
          if (mounted) setState(() => _activeOrders = []);
        });
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _animCtrl.dispose();
    _pageController.dispose();
    super.dispose();
  }

  String _statusTitle(String status) {
    switch (status) {
      case OrderStatus.pending:
        return 'order_placed'.tr(context);
      case 'accepted':
      case OrderStatus.confirmed:
        return 'order_accepted'.tr(context);
      case OrderStatus.preparing:
        return 'preparing_food'.tr(context);
      case OrderStatus.ready:
        return 'ready_pickup'.tr(context);
      case OrderStatus.outForDelivery:
        return 'out_for_delivery'.tr(context);
      default:
        return 'processing'.tr(context);
    }
  }


  IconData _statusIcon(String status) {
    switch (status) {
      case OrderStatus.pending:
        return Icons.schedule_rounded;
      case 'accepted':
      case OrderStatus.confirmed:
        return Icons.check_circle_outline_rounded;
      case OrderStatus.preparing:
        return Icons.outdoor_grill_rounded;
      case OrderStatus.ready:
        return Icons.inventory_2_rounded;
      case OrderStatus.outForDelivery:
        return Icons.delivery_dining_rounded;
      default:
        return Icons.restaurant_rounded;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
      case 'confirmed':
        return const Color(0xFF2563EB);
      case 'preparing':
        return Colors.amber.shade800;
      case 'ready':
        return const Color(0xFF16A34A);
      case 'out_for_delivery':
        return const Color(0xFFE8722A);
      default:
        return Colors.grey.shade600;
    }
  }

  double _statusProgress(String status) {
    switch (status) {
      case 'pending':
        return 0.15;
      case 'accepted':
      case 'confirmed':
        return 0.3;
      case 'preparing':
        return 0.5;
      case 'ready':
        return 0.75;
      case 'out_for_delivery':
        return 0.9;
      default:
        return 0.1;
    }
  }

  String _getEta(String status) {
    switch (status) {
      case 'pending':
        return '~25-30 min';
      case 'accepted':
      case 'confirmed':
        return '~20-25 min';
      case 'preparing':
        return '~15-20 min';
      case 'ready':
        return '~10-15 min';
      case 'out_for_delivery':
        return '~5-10 min';
      default:
        return '';
    }
  }

  String _buildItemsSummary(Map<String, dynamic> order) {
    final items = order['items'];
    if (items == null || items is! List || items.isEmpty) {
      return 'Your order';
    }
    final List<dynamic> itemList = items;
    if (itemList.length == 1) {
      final item = itemList[0];
      final name = item['name'] ?? item['dish_name'] ?? 'Item';
      final qty = item['quantity'] ?? 1;
      return '$name × $qty';
    }
    final first = itemList[0];
    final name = first['name'] ?? first['dish_name'] ?? 'Item';
    final more = itemList.length - 1;
    return '$name + $more more';
  }

  @override
  Widget build(BuildContext context) {
    if (_activeOrders.isEmpty) return const SizedBox.shrink();

    if (_isMinimized) {
      final order = _activeOrders.first;
      final status = order['status']?.toString() ?? 'pending';
      final statusColor = _statusColor(status);

      return SlideTransition(
        position: _slideAnim,
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 16, bottom: 8),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _isMinimized = false);
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(_statusIcon(status), color: statusColor, size: 26),
                    if (_activeOrders.length > 1)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${_activeOrders.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SlideTransition(
      position: _slideAnim,
      child: Container(
        height: 200, // Fixed height for carousel
        margin: const EdgeInsets.only(bottom: 12),
        child: PageView.builder(
          controller: _pageController,
          itemCount: _activeOrders.length,
          itemBuilder: (context, index) {
            return _buildSingleOrderBanner(_activeOrders[index]);
          },
        ),
      ),
    );
  }

  Widget _buildSingleOrderBanner(Map<String, dynamic> order) {
    final status = order['status']?.toString() ?? 'pending';
    final orderId = order['id']?.toString() ?? '';
    final kitchenName = order['kitchen_name']?.toString() ?? 'Kitchen';
    final statusColor = _statusColor(status);
    final eta = _getEta(status);
    final progress = _statusProgress(status);
    final itemsSummary = _buildItemsSummary(order);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.white.withValues(alpha: 0.94),
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OrderTrackingScreen(
                      orderId: orderId,
                      kitchenName: kitchenName,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(_statusIcon(status), color: statusColor, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _statusTitle(status),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: statusColor,
                                ),
                              ),
                              Text(
                                status == 'out_for_delivery' && order['delivery_partner_name'] != null
                                    ? order['delivery_partner_name']
                                    : kitchenName,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade900,
                                ),
                              ),
                              if (status == 'out_for_delivery' && order['delivery_partner_name'] != null)
                                Text(
                                  'Your partner is arriving',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (eta.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              eta,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: statusColor,
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        if (status == 'out_for_delivery' && order['delivery_otp'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'OTP',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                                Text(
                                  order['delivery_otp'].toString(),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.green.shade700,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() => _isMinimized = true),
                          visualDensity: VisualDensity.compact,
                          color: Colors.grey.shade400,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.shopping_bag_outlined, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            itemsSummary,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (_activeOrders.length > 1)
                          Text(
                            '${_activeOrders.indexOf(order) + 1}/${_activeOrders.length}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Stack(
                      children: [
                        Container(
                          height: 6,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 800),
                              height: 6,
                              width: constraints.maxWidth * progress,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [statusColor, statusColor.withValues(alpha: 0.8)],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: statusColor.withValues(alpha: 0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    if (_activeOrders.length > 1) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_activeOrders.length, (dotIndex) {
                          final isCurrent = _activeOrders.indexOf(order) == dotIndex;
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: isCurrent ? 12 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isCurrent ? statusColor : statusColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
