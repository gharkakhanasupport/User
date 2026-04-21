import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/order_service.dart';
import '../core/localization.dart';
import '../screens/order_tracking_screen.dart';

/// A persistent, rich banner that shows when the user has an active order.
/// Displays: order items/qty, ETA/status, tap to open tracking.
class ActiveOrderBanner extends StatefulWidget {
  const ActiveOrderBanner({super.key});

  @override
  State<ActiveOrderBanner> createState() => _ActiveOrderBannerState();
}

class _ActiveOrderBannerState extends State<ActiveOrderBanner>
    with SingleTickerProviderStateMixin {
  final OrderService _orderService = OrderService();
  StreamSubscription? _sub;
  Map<String, dynamic>? _activeOrder;
  late AnimationController _animCtrl;
  late Animation<Offset> _slideAnim;
  bool _isMinimized = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));

    _sub = _orderService.getActiveOrderDetailsStream().listen((order) {
      if (!mounted) return;
      final hadOrder = _activeOrder != null;
      
      if (order != null) {
        setState(() => _activeOrder = order);
        if (!hadOrder) {
          _animCtrl.forward();
        }
      } else if (hadOrder && order == null) {
        // Let it animate out before clearing the active order
        _animCtrl.reverse().then((_) {
          if (mounted) setState(() => _activeOrder = null);
        });
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  String _statusTitle(String status) {
    switch (status) {
      case 'pending':
        return 'order_placed'.tr(context);
      case 'accepted':
      case 'confirmed':
        return 'order_accepted'.tr(context);
      case 'preparing':
        return 'preparing_food'.tr(context);
      case 'ready':
        return 'ready_pickup'.tr(context);
      case 'out_for_delivery':
        return 'out_for_delivery'.tr(context);
      default:
        return 'processing'.tr(context);
    }
  }

  String _statusSubtitle(String status) {
    switch (status) {
      case 'pending':
        return 'waiting_accept'.tr(context);
      case 'accepted':
      case 'confirmed':
        return 'kitchen_accepted'.tr(context);
      case 'preparing':
        return 'food_cooking'.tr(context);
      case 'ready':
        return 'pickup_ready'.tr(context);
      case 'out_for_delivery':
        return 'food_on_way'.tr(context);
      default:
        return 'please_wait'.tr(context);
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.schedule_rounded;
      case 'confirmed':
        return Icons.thumb_up_alt_rounded;
      case 'preparing':
        return Icons.restaurant_rounded;
      case 'ready':
        return Icons.check_circle_rounded;
      case 'out_for_delivery':
        return Icons.delivery_dining_rounded;
      default:
        return Icons.hourglass_top_rounded;
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
    if (_activeOrder == null) return const SizedBox.shrink();

    final order = _activeOrder!;
    final status = order['status']?.toString() ?? 'pending';
    final orderId = order['id']?.toString() ?? '';
    final kitchenName = order['kitchen_name']?.toString() ?? 'Kitchen';
    final statusColor = _statusColor(status);
    final eta = _getEta(status);
    final progress = _statusProgress(status);
    final itemsSummary = _buildItemsSummary(order);

    if (_isMinimized) {
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
                child: Icon(
                  _statusIcon(status),
                  color: statusColor,
                  size: 26,
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
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: statusColor.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Material(
                color: Colors.white.withValues(alpha: 0.94),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrderTrackingScreen(
                          orderId: orderId,
                          kitchenName: kitchenName,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.15),
                        width: 1.5,
                      ),
                      gradient: LinearGradient(
                        colors: [
                          statusColor.withValues(alpha: 0.05),
                          Colors.transparent,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            // Status Icon with Pulse-like background
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Icon(
                                _statusIcon(status),
                                color: statusColor,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 14),
                            // Status & Description
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _statusTitle(status),
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: statusColor,
                                            height: 1.2,
                                          ),
                                        ),
                                      ),
                                      if (eta.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: statusColor.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            eta,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: statusColor,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _statusSubtitle(status),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    itemsSummary,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: statusColor.withValues(alpha: 0.5),
                              size: 14,
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () {
                                setState(() => _isMinimized = true);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.close, color: Colors.grey.shade600, size: 16),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Premium Progress Bar
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return Stack(
                              children: [
                                Container(
                                  height: 6,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                AnimatedContainer(
                                  duration: const Duration(seconds: 1),
                                  height: 6,
                                  width: constraints.maxWidth * progress,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        statusColor,
                                        statusColor.withValues(alpha: 0.8),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: statusColor.withValues(alpha: 0.25),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
