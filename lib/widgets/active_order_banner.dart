import 'dart:async';
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
      setState(() => _activeOrder = order);
      if (order != null && !hadOrder) {
        _animCtrl.forward();
      } else if (order == null && hadOrder) {
        _animCtrl.reverse();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'order_pending_eta'.tr(context);
      case 'confirmed':
        return 'order_confirmed_eta'.tr(context);
      case 'preparing':
        return 'order_preparing_eta'.tr(context);
      case 'ready':
        return 'order_ready_eta'.tr(context);
      case 'out_for_delivery':
        return 'order_delivery_eta'.tr(context);
      default:
        return 'processing'.tr(context);
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
        return Colors.amber.shade700;
      case 'confirmed':
        return const Color(0xFF2563EB);
      case 'preparing':
        return Colors.deepOrange;
      case 'ready':
        return const Color(0xFF16A34A);
      case 'out_for_delivery':
        return const Color(0xFF7C3AED);
      default:
        return Colors.grey;
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

    return SlideTransition(
      position: _slideAnim,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    statusColor.withValues(alpha: 0.07),
                    statusColor.withValues(alpha: 0.02),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withValues(alpha: 0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top row: icon + status + ETA
                  Row(
                    children: [
                      // Animated status icon
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(_statusIcon(status), color: statusColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      // Status lines
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _statusLabel(status),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: statusColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              itemsSummary,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // ETA chip
                      if (eta.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.timer_outlined, size: 13, color: statusColor),
                              const SizedBox(width: 4),
                              Text(
                                eta,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(width: 8),
                      Icon(Icons.chevron_right_rounded, color: statusColor, size: 22),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 5,
                      backgroundColor: statusColor.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation(statusColor),
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
}
