import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/order_service.dart';
import '../widgets/delivery_radar.dart';
import '../core/localization.dart';
import '../utils/maps_launcher.dart';
import '../utils/error_handler.dart';
import '../widgets/live_tracking_map.dart';
import '../widgets/skeleton_loaders.dart';

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

  double _calculateItemTotal(List<Map<String, dynamic>> items) {
    double total = 0;
    for (var item in items) {
      final price = (item['price'] ?? 0) as num;
      final qty = (item['quantity'] ?? 1) as num;
      total += price.toDouble() * qty.toDouble();
    }
    return total;
  }

  double _calculateDeliveryFee(Map<String, dynamic> order, double itemTotal) {
    if (order.containsKey('delivery_fee') && order['delivery_fee'] != null) {
      return (order['delivery_fee'] as num).toDouble();
    }
    final total = _parseDouble(order['total'] ?? order['total_amount']) ?? 0.0;
    final diff = total - itemTotal;
    return diff > 0 ? diff : 0.0;
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
            return const SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  OrderSkeleton(),
                  OrderSkeleton(),
                  OrderSkeleton(),
                ],
              ),
            );
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
          double? agentLat = _parseDouble(order['agent_latitude']);
          double? agentLng = _parseDouble(order['agent_longitude']);
          
          // Fallback to legacy current_location map if new fields are missing
          if (agentLat == null || agentLng == null) {
            final currentLoc = order['current_location'];
            if (currentLoc is Map) {
              agentLat = _parseDouble(currentLoc['lat']);
              agentLng = _parseDouble(currentLoc['lng']);
            }
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

                // Refund Section (Shown for cancelled/rejected orders)
                if (isRejected || status == 'cancelled' || status == 'failed')
                  _buildRefundSection(order),

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

                // LIVE DELIVERY RADAR & MAP — shown during ready / out_for_delivery
                if (showRadar) ...[
                  if (deliveryPartnerName.isNotEmpty) ...[
                    _buildPartnerCard(order),
                    const SizedBox(height: 16),
                  ],
                  if (pickupLat != null && pickupLng != null && deliveryLat != null && deliveryLng != null) ...[
                    LiveTrackingMap(
                      pickupLat: pickupLat,
                      pickupLng: pickupLng,
                      deliveryLat: deliveryLat,
                      deliveryLng: deliveryLng,
                      agentLat: agentLat,
                      agentLng: agentLng,
                      kitchenName: widget.kitchenName,
                    ),
                    const SizedBox(height: 16),
                  ],
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 8, bottom: 24),
                          child: Text('Order Progress', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B))),
                        ),
                        ...List.generate(_statusSteps.length, (i) {
                          final stepStatus = _statusSteps[i];
                          final isCompleted = i <= currentStep;
                          final isActive = i == currentStep;
                          final isLast = i == _statusSteps.length - 1;

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                children: [
                                  // Stepper Dot
                                  Container(
                                    width: 20,
                                    height: 20,
                                    margin: const EdgeInsets.only(top: 2),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isCompleted ? const Color(0xFF16A34A) : Colors.white,
                                      border: Border.all(
                                        color: isCompleted ? const Color(0xFF16A34A) : Colors.grey.shade400,
                                        width: 2,
                                      ),
                                    ),
                                    child: isCompleted 
                                      ? const Icon(Icons.check, size: 12, color: Colors.white)
                                      : null,
                                  ),
                                  if (!isLast)
                                    Container(
                                      width: 2,
                                      height: 50,
                                      margin: const EdgeInsets.symmetric(vertical: 4),
                                      decoration: BoxDecoration(
                                        color: i < currentStep ? const Color(0xFF16A34A) : Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(1),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _statusTitle(stepStatus),
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 15,
                                              fontWeight: isCompleted ? FontWeight.w700 : FontWeight.w500,
                                              color: isCompleted ? const Color(0xFF1E293B) : Colors.grey.shade500,
                                            ),
                                          ),
                                          if (i == 0 && createdAt != null)
                                            Text(
                                              '${createdAt.day}/${createdAt.month}/${createdAt.year}',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 12,
                                                color: Colors.grey.shade500,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                        ],
                                      ),
                                      if (isCompleted || isActive) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          _statusSubtitle(stepStatus),
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 13,
                                            color: isActive ? const Color(0xFF16A34A) : Colors.grey.shade600,
                                            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                                          ),
                                        ),
                                        if (i == 0 && createdAt != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            '${createdAt.hour > 12 ? createdAt.hour - 12 : createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')} ${createdAt.hour >= 12 ? 'PM' : 'AM'}',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ]
                                      ]
                                    ],
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

                // Order Items & Billing
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text('Item Details', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B))),
                      ),
                      ...items.map((itemMap) {
                        final name = itemMap['name'] ?? 'Item';
                        final qty = itemMap['quantity'] ?? 1;
                        final price = itemMap['price'] ?? 0;
                        final imageUrl = itemMap['image_url'];
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade200),
                                  image: imageUrl != null 
                                      ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover) 
                                      : null,
                                ),
                                child: imageUrl == null 
                                    ? Icon(Icons.fastfood, color: Colors.grey.shade300, size: 32) 
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('$name', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B))),
                                    const SizedBox(height: 6),
                                    Text('Qty: $qty', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 6),
                                    Text('\u20B9${((price as num) * (qty as num)).toStringAsFixed(2)}', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      
                      const SizedBox(height: 8),
                      // Dashed Divider
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: List.generate(
                            150 ~/ 3,
                            (index) => Expanded(
                              child: Container(
                                color: index % 2 == 0 ? Colors.transparent : Colors.grey.shade300,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text('Bill Details', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B))),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Item Total', style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                                Text('\u20B9${_calculateItemTotal(items).toStringAsFixed(2)}', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Delivery Fee', style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                                Text('\u20B9${_calculateDeliveryFee(order, _calculateItemTotal(items)).toStringAsFixed(2)}', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                              ],
                            ),
                            if (order.containsKey('platform_fee') && order['platform_fee'] != null) ...[
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Platform Fee', style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                                  Text('\u20B9${(order['platform_fee'] as num).toStringAsFixed(2)}', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                                ],
                              ),
                            ],
                            if (order.containsKey('discount') && order['discount'] != null && (order['discount'] as num) > 0) ...[
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Discount', style: GoogleFonts.plusJakartaSans(fontSize: 14, color: const Color(0xFF16A34A), fontWeight: FontWeight.w500)),
                                  Text('-\u20B9${(order['discount'] as num).toStringAsFixed(2)}', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF16A34A))),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Grand Total Block
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Grand Total', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B))),
                            Text('\u20B9${double.tryParse(totalAmount)?.toStringAsFixed(2) ?? totalAmount}', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B))),
                          ],
                        ),
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
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
            color: displayColor.withValues(alpha: 0.15),
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
            color: displayColor.withValues(alpha: 0.1),
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
          color: const Color(0xFF16A34A).withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16A34A).withValues(alpha: 0.08),
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
                  color: const Color(0xFF16A34A).withValues(alpha: 0.1),
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
                border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.2)),
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
                    border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.4)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF16A34A).withValues(alpha: 0.06),
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

  /// Delivery partner info card — shows agent name and vehicle details.
  Widget _buildPartnerCard(Map<String, dynamic> order) {
    final name = order['delivery_partner_name'] ?? 'Delivery Partner';
    final phone = order['delivery_partner_phone'] ?? '';
    final vehicleNum = order['vehicle_number'] ?? '';
    final vehicleType = order['vehicle_type'] ?? 'Delivery Vehicle';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFE8722A).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.delivery_dining_rounded, color: Color(0xFFE8722A), size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '$vehicleType • $vehicleNum',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (phone.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF16A34A)),
              onPressed: () => MapsLauncher.call(phone),
            ),
        ],
      ),
    );
  }

  /// Refund section — allows users to initiate a refund for cancelled orders.
  Widget _buildRefundSection(Map<String, dynamic> order) {
    final refundStatus = (order['refund_status'] ?? 'none').toString();
    final isRefunded = refundStatus == 'refunded';
    final amount = (order['total'] ?? order['total_amount'] ?? 0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isRefunded ? const Color(0xFFF0FDF4) : Colors.red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRefunded ? const Color(0xFF16A34A).withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isRefunded ? const Color(0xFF16A34A).withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isRefunded ? Icons.account_balance_wallet : Icons.info_outline_rounded,
                  color: isRefunded ? const Color(0xFF16A34A) : Colors.red,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isRefunded ? 'Refund Successful' : 'Eligible for Refund',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isRefunded ? const Color(0xFF16A34A) : Colors.red.shade700,
                      ),
                    ),
                    Text(
                      isRefunded 
                        ? '\u20B9$amount has been credited to your GKK Wallet' 
                        : 'Your order was cancelled. You can refund the amount to your wallet.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: isRefunded ? const Color(0xFF16A34A).withValues(alpha: 0.8) : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isRefunded) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _handleRefund(order),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text(
                  'Refund \u20B9$amount to Wallet',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleRefund(Map<String, dynamic> order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirm Refund', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        content: Text('The amount will be credited to your GKK Wallet instantly. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Refund Now'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator(color: Color(0xFF16A34A))),
    );

    try {
      final success = await _orderService.initiateRefund(order);
      if (!mounted) return;
      Navigator.pop(context); // Pop loader

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Refund successful! Amount added to your wallet.'),
            backgroundColor: Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Refund failed. Please try again or contact support.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ErrorHandler.showGracefulError(context, e);
      }
    }
  }
}
