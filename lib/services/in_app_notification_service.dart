import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/order_service.dart';
import '../services/fcm_service.dart';

/// Native in-app notification overlay for order status changes.
/// Uses Flutter Overlay API — no FCM dependency.
class InAppNotificationService {
  static final InAppNotificationService _instance = InAppNotificationService._();
  factory InAppNotificationService() => _instance;
  InAppNotificationService._();

  StreamSubscription? _orderSub;
  String? _lastNotifiedStatus;
  OverlayEntry? _currentOverlay;

  /// Start listening to order status changes. Call once from main app widget.
  void startListening() {
    _orderSub?.cancel();
    _orderSub = OrderService().getActiveOrderDetailsStream().listen((orders) {
      if (orders.isEmpty) {
        _lastNotifiedStatus = null;
        return;
      }
      
      // Get the most recent order that isn't delivered or cancelled
      final order = orders.first;
      final newStatus = order['status']?.toString();
      
      if (newStatus != null && newStatus != _lastNotifiedStatus) {
        final oldStatus = _lastNotifiedStatus;
        _lastNotifiedStatus = newStatus;
        
        // Don't notify on initial app load (oldStatus is null)
        if (oldStatus != null) {
          _showNotification(newStatus, order);
        }
      }
    });
  }

  /// Stop listening (call on logout / dispose).
  void stopListening() {
    _orderSub?.cancel();
    _orderSub = null;
    _lastNotifiedStatus = null;
  }

  void _showNotification(String status, Map<String, dynamic> order) {
    final info = _statusInfo(status);
    if (info == null) return;

    // Trigger system notification (background safe)
    FCMService().showOrderNotification(
      title: info['title']!,
      body: info['subtitle']!,
    );

    final context = _navigatorKey?.currentContext;
    if (context == null) return;

    final overlay = Overlay.of(context);

    // Remove any existing notification
    _currentOverlay?.remove();
    _currentOverlay = null;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _NotificationBanner(
        title: info['title']!,
        subtitle: info['subtitle']!,
        icon: info['icon'] as IconData,
        color: info['color'] as Color,
        onDismiss: () {
          entry.remove();
          if (_currentOverlay == entry) _currentOverlay = null;
        },
      ),
    );

    _currentOverlay = entry;
    overlay.insert(entry);
  }

  Map<String, dynamic>? _statusInfo(String status) {
    switch (status) {
      case 'accepted':
      case 'confirmed':
        return {
          'title': 'Order Accepted! ✅',
          'subtitle': 'Kitchen has accepted your order.',
          'icon': Icons.thumb_up_alt_rounded,
          'color': const Color(0xFF2563EB),
        };
      case 'preparing':
        return {
          'title': 'Preparing Your Food 🍳',
          'subtitle': 'Your meal is being prepared with love.',
          'icon': Icons.restaurant_rounded,
          'color': Colors.amber.shade800,
        };
      case 'ready':
        return {
          'title': 'Food is Ready! 🎉',
          'subtitle': 'Your order is ready for pickup/delivery.',
          'icon': Icons.check_circle_rounded,
          'color': const Color(0xFF16A34A),
        };
      case 'out_for_delivery':
        return {
          'title': 'Out for Delivery 🚀',
          'subtitle': 'Your food is on the way!',
          'icon': Icons.delivery_dining_rounded,
          'color': const Color(0xFFE8722A),
        };
      case 'delivered':
        return {
          'title': 'Order Delivered! 🎊',
          'subtitle': 'Enjoy your meal!',
          'icon': Icons.task_alt_rounded,
          'color': const Color(0xFF059669),
        };
      case 'cancelled':
        return {
          'title': 'Order Cancelled',
          'subtitle': 'Your order has been cancelled.',
          'icon': Icons.cancel_rounded,
          'color': const Color(0xFFDC2626),
        };
      default:
        return null;
    }
  }

  // --- Global navigator key (set from main.dart) ---
  static GlobalKey<NavigatorState>? _navigatorKey;
  static void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }
}

// ---------- Animated Overlay Banner ----------

class _NotificationBanner extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onDismiss;

  const _NotificationBanner({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onDismiss,
  });

  @override
  State<_NotificationBanner> createState() => _NotificationBannerState();
}

class _NotificationBannerState extends State<_NotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  Timer? _autoHide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _slide = Tween<Offset>(begin: const Offset(0, -1.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();

    _autoHide = Timer(const Duration(seconds: 4), _dismiss);
  }

  void _dismiss() {
    _ctrl.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _autoHide?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onVerticalDragEnd: (_) => _dismiss(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: widget.color.withOpacity( 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity( 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity( 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity( 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(widget.icon, color: widget.color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _dismiss,
                    child: Icon(Icons.close, size: 18, color: Colors.grey.shade400),
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
