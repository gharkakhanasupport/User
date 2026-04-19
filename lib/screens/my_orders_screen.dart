import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/order_service.dart';
import '../core/localization.dart';
import 'order_tracking_screen.dart';

class MyOrdersScreen extends StatefulWidget {
  final bool hideAppBar;
  const MyOrdersScreen({super.key, this.hideAppBar = false});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  Locale? _lastLocale;
  Key _streamKey = UniqueKey();
  final OrderService _orderService = OrderService();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newLocale = Localizations.localeOf(context);
    if (_lastLocale != null && _lastLocale != newLocale) {
      if (mounted) setState(() {});
    }
    _lastLocale = newLocale;
  }


  Future<void> _onRefresh() async {
    setState(() => _streamKey = UniqueKey());
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
      case 'confirmed':
        return Colors.blue;
      case 'preparing':
        return Colors.amber.shade700;
      case 'ready':
        return const Color(0xFF16A34A);
      case 'out_for_delivery':
        return Colors.deepOrange;
      case 'completed':
      case 'delivered':
        return const Color(0xFF16A34A);
      case 'rejected':
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'status_pending'.tr(context);
      case 'accepted':
      case 'confirmed':
        return 'status_confirmed'.tr(context);
      case 'preparing':
        return 'status_preparing'.tr(context);
      case 'ready':
        return 'status_ready'.tr(context);
      case 'out_for_delivery':
        return 'status_out_delivery'.tr(context);
      case 'completed':
      case 'delivered':
        return 'status_delivered'.tr(context);
      case 'rejected':
      case 'cancelled':
        return 'status_cancelled'.tr(context);
      default:
        return status;
    }
  }

  bool _isActive(String status) {
    return ['pending', 'accepted', 'preparing', 'ready'].contains(status);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: widget.hideAppBar ? null : AppBar(
        title: Text('my_orders'.tr(context), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: RefreshIndicator(
        color: const Color(0xFF16A34A),
        onRefresh: _onRefresh,
        child: StreamBuilder<List<Map<String, dynamic>>>(
          key: _streamKey,
          stream: _orderService.getMyOrdersStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF16A34A)));
            }

            final orders = snapshot.data ?? [];

            if (orders.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('no_orders'.tr(context), style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Text('no_orders_desc'.tr(context), style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.grey.shade400)),
                      ],
                    ),
                  ),
                ],
              );
            }

            final active = orders.where((o) => _isActive((o['status'] ?? '').toString())).toList();
            final past = orders.where((o) => !_isActive((o['status'] ?? '').toString())).toList();

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (active.isNotEmpty) ...[
                  Text('active_orders'.tr(context), style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...active.map((order) => _buildOrderCard(order)),
                  const SizedBox(height: 24),
                ],
                if (past.isNotEmpty) ...[
                  Text('past_orders'.tr(context), style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                  const SizedBox(height: 12),
                  ...past.map((order) => _buildOrderCard(order)),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = (order['status'] ?? 'pending').toString();
    final items = order['items'] as List<dynamic>? ?? [];
    final kitchenName = (order['kitchen_name'] ?? 'Kitchen').toString();
    final orderId = (order['id'] ?? '').toString();
    final createdAtStr = order['created_at']?.toString();
    final createdAt = createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;

    // Build items summary (if available)
    String summaryText = kitchenName;
    if (items.isNotEmpty) {
      final names = items.map((i) {
        final m = i is Map ? i : {};
        return '${m['quantity'] ?? 1} x ${m['name'] ?? 'Item'}';
      }).take(3).join(', ');
      summaryText = names + (items.length > 3 ? ' +${items.length - 3} ${'more_items'.tr(context)}' : '');
    }

    String timeStr = '';
    if (createdAt != null) {
      final now = DateTime.now();
      final diff = now.difference(createdAt);
      if (diff.inMinutes < 60) {
        timeStr = '${diff.inMinutes}${'ago_min'.tr(context)}';
      } else if (diff.inHours < 24) {
        timeStr = '${diff.inHours}${'ago_hour'.tr(context)}';
      } else {
        timeStr = '${diff.inDays}${'ago_day'.tr(context)}';
      }
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => OrderTrackingScreen(orderId: orderId, kitchenName: kitchenName),
        ));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${'order_id_prefix'.tr(context)}${orderId.length > 8 ? orderId.substring(0, 8) : orderId}',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _statusColor(status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              summaryText,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.grey.shade600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '\u20B9${(order['total'] ?? order['total_amount'] ?? 0)}',
                  style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A)),
                ),
                Text(timeStr, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
