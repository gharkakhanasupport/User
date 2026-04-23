import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/order_service.dart';
import '../widgets/delivery_radar.dart';
import '../core/localization.dart';
import '../utils/maps_launcher.dart';
import '../utils/error_handler.dart';

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
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final items = await _orderService.getOrderItems(widget.orderId);
      if (mounted) {
        setState(() {
          _items = items;
        });
      }
    } catch (e) {
      if (mounted) ErrorHandler.showGracefulError(context, e);
    }
  }

  static const _statusSteps = [
    'pending',
    'confirmed',
    'preparing',
    'ready',
    'out_for_delivery',
    'delivered',
  ];

  int _statusIndex(String status) {
    // Treat 'accepted' as 'confirmed' and 'completed' as 'delivered' for UI
    String mappedStatus = status;
    if (status == 'accepted') mappedStatus = 'confirmed';
    if (status == 'completed') mappedStatus = 'delivered';
    
    final idx = _statusSteps.indexOf(mappedStatus);
    return idx >= 0 ? idx : 0;
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_top_rounded;
      case 'accepted':
      case 'confirmed':
        return Icons.thumb_up_alt_rounded;
      case 'preparing':
        return Icons.restaurant_rounded;
      case 'ready':
        return Icons.check_circle_rounded;
      case 'out_for_delivery':
        return Icons.delivery_dining_rounded;
      case 'delivered':
      case 'completed':
        return Icons.done_all_rounded;
      case 'rejected':
      case 'cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  /// Generate a new OTP for this order and store it in both DBs.
  Future<void> _generateOtp() async {
    try {
      final otp = await _orderService.generateDeliveryOtp(widget.orderId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ OTP $otp generated! Share it with your delivery partner.'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
    } catch (e) {
      if (mounted) ErrorHandler.showGracefulError(context, e);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
      case 'confirmed':
        return Colors.blue;
      case 'preparing':
        return Colors.amber.shade700;
      case 'ready':
        return const Color(0xFF16A34A);
      case 'out_for_delivery':
        return const Color(0xFFE8722A);
      case 'delivered':
      case 'completed':
        return const Color(0xFF16A34A);
      case 'rejected':
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
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
      case 'delivered':
      case 'completed':
        return 'order_delivered'.tr(context);
      case 'rejected':
      case 'cancelled':
        return 'order_cancelled'.tr(context);
      default:
        return 'processing'.tr(context);
    }
  }

  String _statusSubtitle(String status) {
    switch (status) {
      case 'pending':
        return 'waiting_accept'.tr(context);
      case 'accepted':
        return 'kitchen_accepted'.tr(context);
      case 'preparing':
        return 'food_cooking'.tr(context);
      case 'ready':
        return 'pickup_ready'.tr(context);
      case 'out_for_delivery':
        return 'food_on_way'.tr(context);
      case 'delivered':
      case 'completed':
        return 'delivered_enjoy'.tr(context);
      case 'rejected':
        return 'rejected_msg'.tr(context);
      default:
        return 'please_wait'.tr(context);
    }
  }

  double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // This will trigger a rebuild and re-evaluation of localized strings when locale changes
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('track_order'.tr(context), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
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
                  Text('order_not_found'.tr(context), style: GoogleFonts.plusJakartaSans(fontSize: 16, color: Colors.grey)),
                ],
              ),
            );
          }

          final order = snapshot.data!.first;
          final status = (order['status'] ?? 'pending').toString();
          final isRejected = status == 'rejected';
          final currentStep = _statusIndex(status);
          final items = _items;
          final totalAmount = (order['total'] ?? order['total_amount'] ?? 0).toString();
          final deliveryAddress = (order['delivery_address'] ?? 'Not provided').toString();
          final createdAt = DateTime.tryParse(order['created_at'] ?? '');

          // Delivery tracking fields (may be null if backend columns not yet present)
          final pickupLat = _parseDouble(order['pickup_lat']);
          final pickupLng = _parseDouble(order['pickup_lng']);
          final deliveryLat = _parseDouble(order['delivery_lat']);
          final deliveryLng = _parseDouble(order['delivery_lng']);
          final currentLoc = order['current_location'];
          double? agentLat;
          double? agentLng;
          if (currentLoc is Map) {
            agentLat = _parseDouble(currentLoc['lat']);
            agentLng = _parseDouble(currentLoc['lng']);
          }
          final deliveryPartnerName = (order['delivery_partner_name'] ?? '').toString();
          final deliveryPartnerPhone = (order['delivery_partner_phone'] ?? '').toString();
          final kitchenPhone = (order['kitchen_phone'] ?? order['restaurant_phone'] ?? '').toString();
          final showRadar = status == 'out_for_delivery' || status == 'ready';

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
                    color: _statusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _statusColor(status).withOpacity(0.3)),
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
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: widget.orderId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Order ID copied!'),
                              duration: Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Order ID: #${widget.orderId.length > 8 ? widget.orderId.substring(0, 8) : widget.orderId}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(Icons.copy_rounded, size: 14, color: Colors.grey.shade400),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ETA Timeline Card
                if (!isRejected)
                  _buildEtaTimelineCard(status, createdAt),

                const SizedBox(height: 16),

                // Contact buttons — Call kitchen (always), Call partner (when assigned)
                if (kitchenPhone.isNotEmpty || deliveryPartnerPhone.isNotEmpty) ...[
                  Row(
                    children: [
                      if (kitchenPhone.isNotEmpty)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => MapsLauncher.call(kitchenPhone),
                            icon: const Icon(Icons.restaurant, size: 18),
                            label: const Text('Call Kitchen'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      if (kitchenPhone.isNotEmpty && deliveryPartnerPhone.isNotEmpty)
                        const SizedBox(width: 8),
                      if (deliveryPartnerPhone.isNotEmpty)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => MapsLauncher.call(deliveryPartnerPhone),
                            icon: const Icon(Icons.two_wheeler, size: 18),
                            label: const Text('Call Partner'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // LIVE DELIVERY RADAR — shown during ready / out_for_delivery
                if (showRadar) ...[
                  DeliveryRadarCard(
                    pickupLat: pickupLat,
                    pickupLng: pickupLng,
                    deliveryLat: deliveryLat,
                    deliveryLng: deliveryLng,
                    agentLat: agentLat,
                    agentLng: agentLng,
                    partnerName: deliveryPartnerName.isEmpty ? null : deliveryPartnerName,
                    otp: null, // OTP hidden from customer — they must enter it from partner
                    isOnTheWay: status == 'out_for_delivery',
                  ),
                  const SizedBox(height: 16),
                ],

                // Delivery OTP — shown when order is out for delivery
                if (status == 'out_for_delivery') ...[
                  _buildOtpDisplayCard(order),
                  const SizedBox(height: 16),
                ],

                // Progress Stepper (not shown for rejected)
                if (!isRejected) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('order_progress'.tr(context), style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold)),
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
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A).withOpacity(0.1),
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
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('order_details'.tr(context), style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      ...items.map((itemMap) {
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
                                  color: const Color(0xFF16A34A).withOpacity(0.1),
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
                          Text('total'.tr(context), style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold)),
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
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
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
                            Text('delivery_address_title'.tr(context), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13)),
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
                    child: Text('back_home'.tr(context), style: GoogleFonts.plusJakartaSans(color: const Color(0xFF16A34A), fontWeight: FontWeight.w600)),
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

  Widget _buildEtaTimelineCard(String status, DateTime? createdAt) {
    // Calculate dynamic ETAs
    final bool packagingDone = ['ready', 'out_for_delivery', 'delivered', 'completed'].contains(status);
    final bool deliveryDone = ['delivered', 'completed'].contains(status);
    final bool isDelivering = status == 'out_for_delivery';

    String packagingEta = '~10-15 min';
    String deliveryEta = '~10-15 min';

    if (packagingDone) {
      packagingEta = 'Done ✓';
    }
    if (deliveryDone) {
      deliveryEta = 'Delivered ✓';
    } else if (isDelivering) {
      deliveryEta = '~5-10 min';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 18, color: Color(0xFF16A34A)),
              const SizedBox(width: 8),
              Text(
                'estimated_time'.tr(context),
                style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Packaging row
          _buildEtaRow(
            icon: Icons.restaurant_rounded,
            title: 'packaging_time'.tr(context),
            eta: packagingEta,
            isDone: packagingDone,
            isActive: !packagingDone && ['pending', 'confirmed', 'preparing'].contains(status),
            color: Colors.deepOrange,
          ),
          // Connecting line
          Padding(
            padding: const EdgeInsets.only(left: 15),
            child: Container(
              width: 2,
              height: 20,
              color: packagingDone ? const Color(0xFF16A34A) : Colors.grey.shade200,
            ),
          ),
          // Delivery row
          _buildEtaRow(
            icon: Icons.delivery_dining_rounded,
            title: 'delivery_time'.tr(context),
            eta: deliveryEta,
            isDone: deliveryDone,
            isActive: isDelivering,
            color: const Color(0xFF7C3AED),
          ),
        ],
      ),
    );
  }

  Widget _buildEtaRow({
    required IconData icon,
    required String title,
    required String eta,
    required bool isDone,
    required bool isActive,
    required Color color,
  }) {
    final displayColor = isDone
        ? const Color(0xFF16A34A)
        : isActive
            ? color
            : Colors.grey.shade400;

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: displayColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: displayColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: isActive || isDone ? Colors.black87 : Colors.grey.shade500,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: displayColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            eta,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: displayColor,
            ),
          ),
        ),
      ],
    );
  }

  /// OTP display card — shows auto-generated OTP or a Generate button.
  Widget _buildOtpDisplayCard(Map<String, dynamic> order) {
    final otp = order['delivery_otp']?.toString();
    final hasOtp = otp != null && otp.length == 4;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF16A34A).withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16A34A).withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.lock_rounded, color: Color(0xFF16A34A), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Delivery Verification',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (hasOtp) ...[
            // Show OTP in large prominent digits
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF16A34A).withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: otp.split('').map((digit) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: 48,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF16A34A).withOpacity(0.4)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF16A34A).withOpacity(0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      digit,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF16A34A),
                      ),
                    ),
                  ),
                )).toList(),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Share this OTP with your delivery partner',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'They will enter this code to confirm your delivery',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: Colors.grey.shade400,
              ),
            ),
          ] else ...[
            // No OTP yet — show generate button
            Text(
              'Generate a one-time code for delivery verification',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _generateOtp,
                icon: const Icon(Icons.vpn_key_rounded, color: Colors.white, size: 18),
                label: Text(
                  'Generate OTP',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
