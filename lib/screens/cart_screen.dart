import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../services/coupon_service.dart';
import '../services/payment_service.dart';
import '../services/order_service.dart';
import '../services/user_service.dart';
import '../services/wallet_service.dart';
import '../core/localization.dart';
import 'order_tracking_screen.dart';

class CartScreen extends StatefulWidget {
  final Map<String, int> cartItems;
  final Map<String, int> itemPrices;
  final Map<String, String> itemImages;
  final Map<String, String> itemNames;
  final String kitchenName;
  final String cookId;

  const CartScreen({
    super.key,
    required this.cartItems,
    required this.itemPrices,
    required this.itemImages,
    required this.itemNames,
    required this.kitchenName,
    required this.cookId,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  Locale? _lastLocale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newLocale = Localizations.localeOf(context);
    if (_lastLocale != null && _lastLocale != newLocale) {
      if (mounted) setState(() {});
    }
    _lastLocale = newLocale;
  }

  late Map<String, int> _cartItems;
  final _couponController = TextEditingController();
  final _couponService = CouponService();
  final _paymentService = PaymentService();
  final _orderService = OrderService();
  final _userService = UserService();
  final _walletService = WalletService();
  bool _isPlacingOrder = false;
  String _selectedPaymentMethod = 'wallet';
  double _walletBalance = 0.0;
  int _pendingGrandTotal = 0; // For add-money-then-pay flow
  bool _razorpayIsTopUp = false; // true=wallet top-up, false=direct payment

  Map<String, dynamic>? _appliedCoupon;
  bool _isApplyingCoupon = false;
  String? _couponError;

  @override
  void initState() {
    super.initState();
    _cartItems = Map.from(widget.cartItems);
    _setupPaymentHandlers();
    _loadWalletBalance();
  }

  Future<void> _loadWalletBalance() async {
    final bal = await _walletService.getBalance();
    if (mounted) setState(() => _walletBalance = bal);
  }

  void _setupPaymentHandlers() {
    _paymentService.onSuccess = (PaymentSuccessResponse response) async {
      if (_razorpayIsTopUp) {
        // Wallet top-up flow: add money to wallet, then debit wallet, then place order
        final addSuccess = await _walletService.addMoney(_pendingGrandTotal.toDouble(), response.paymentId ?? 'unknown');
        if (addSuccess) {
          await _loadWalletBalance();
          await _processWalletOrderPayment(_pendingGrandTotal);
        } else {
          if (mounted) {
            setState(() => _isPlacingOrder = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('pay_failed'.tr(context)), backgroundColor: Colors.red),
            );
          }
        }
      } else {
        // Direct Razorpay flow: place order immediately (no wallet involved)
        await _processDirectOrderPayment(response.paymentId ?? 'unknown');
      }
    };
    _paymentService.onFailure = (PaymentFailureResponse response) {
      if (mounted) {
        setState(() => _isPlacingOrder = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'pay_failed'.tr(context)}: ${response.message}'), backgroundColor: Colors.red),
        );
      }
    };
  }

  /// Called when user taps Pay — routes to wallet or direct Razorpay
Future<void> _handlePayment(int grandTotal) async {
    final user = Supabase.instance.client.auth.currentUser;
    final userId = user?.id ?? '';

    if (_selectedPaymentMethod == 'wallet') {
      // Wallet flow
      if (_walletBalance >= grandTotal) {
        setState(() => _isPlacingOrder = true);
        await _processWalletOrderPayment(grandTotal);
      } else {
        // Insufficient — top up via Razorpay
        final deficit = grandTotal - _walletBalance;
        final addAmount = ((deficit / 10).ceil() * 10).toInt();
        _pendingGrandTotal = grandTotal;
        _razorpayIsTopUp = true;
        setState(() => _isPlacingOrder = true);

        _paymentService.openCheckout(
          amount: addAmount.toDouble(),
          kitchenName: 'GKK Wallet Top-up',
          userEmail: user?.email ?? 'customer@example.com',
          userPhone: user?.phone ?? user?.userMetadata?['phone'] ?? '9999999999',
          description: 'Deficit Top-up for Order',
          notes: {
            'order_type': 'wallet_topup',
            'user_id': userId,
            'is_deficit_topup': 'true',
            'pending_total': grandTotal.toString(),
          },
        );
      }
    } else {
        String? upiPackageName;
        if (_selectedPaymentMethod == 'gpay') upiPackageName = 'com.google.android.apps.nbu.paisa.user';
        if (_selectedPaymentMethod == 'phonepe') upiPackageName = 'com.phonepe.app';
        if (_selectedPaymentMethod == 'paytm') upiPackageName = 'net.one97.paytm';
        
      _pendingGrandTotal = grandTotal;
      _razorpayIsTopUp = false;
      setState(() => _isPlacingOrder = true);

      _paymentService.openCheckout(
        amount: grandTotal.toDouble(),
        kitchenName: widget.kitchenName,
        userEmail: user?.email ?? 'customer@example.com',
        userPhone: user?.phone ?? user?.userMetadata?['phone'] ?? '9999999999',
        description: 'Food Order from ',
        upiPackageName: upiPackageName,
        notes: {
          'order_type': 'direct_order',
          'user_id': userId,
          'cook_id': widget.cookId,
        },
      );
    }
  }

  /// Direct Razorpay payment — place order without wallet
  Future<void> _processDirectOrderPayment(String paymentId) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final userId = user?.id ?? '';
      final userData = await _userService.getUserData(userId);

      final customerName = userData?['name'] ?? user?.userMetadata?['full_name'] ?? 'Customer';
      final customerPhone = userData?['phone'] ?? user?.phone ?? user?.userMetadata?['phone'] ?? '';
      final deliveryAddress = userData?['address'] ?? 'Not provided';

      final items = <Map<String, dynamic>>[];
      _cartItems.forEach((itemId, qty) {
        final price = widget.itemPrices[itemId] ?? 0;
        items.add({
          'menu_item_id': itemId,
          'name': widget.itemNames[itemId] ?? 'Unknown Item',
          'quantity': qty,
          'price': price,
        });
      });

      final orderResult = await _orderService.placeSingleOrder(
        cookId: widget.cookId,
        customerName: customerName,
        customerPhone: customerPhone,
        deliveryAddress: deliveryAddress,
        items: items,
        totalAmount: _pendingGrandTotal.toDouble(),
        paymentMethod: _selectedPaymentMethod, // Pass selected payment method
      );

      final orderId = orderResult['id']?.toString() ?? '';

      if (!mounted) return;
      setState(() => _isPlacingOrder = false);
      _showOrderSuccessDialog(orderId, viaWallet: false);
    } catch (e) {
      debugPrint('Direct order payment failed: $e');
      if (!mounted) return;
      setState(() => _isPlacingOrder = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${'order_failed'.tr(context)}: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 4)),
      );
    }
  }

  /// Process wallet deduction + order placement (called after wallet has sufficient funds)
  Future<void> _processWalletOrderPayment(int grandTotal) async {
    final insufficientWalletError = 'insufficient_wallet'.tr(context);
    try {
      // Get user details
      final user = Supabase.instance.client.auth.currentUser;
      final userId = user?.id ?? '';
      final userData = await _userService.getUserData(userId);

      final customerName = userData?['name'] ?? user?.userMetadata?['full_name'] ?? 'Customer';
      final customerPhone = userData?['phone'] ?? user?.phone ?? user?.userMetadata?['phone'] ?? '';
      final deliveryAddress = userData?['address'] ?? 'Not provided';

      // Build items
      final items = <Map<String, dynamic>>[];
      _cartItems.forEach((itemId, qty) {
        final price = widget.itemPrices[itemId] ?? 0;
        items.add({
          'menu_item_id': itemId,
          'name': widget.itemNames[itemId] ?? 'Unknown Item',
          'quantity': qty,
          'price': price,
        });
      });

      // Debit wallet FIRST — if this fails, no order is created
      final tempOrderRef = 'pre_${DateTime.now().millisecondsSinceEpoch}';
      final debited = await _walletService.payFromWallet(grandTotal.toDouble(), tempOrderRef);
      if (!debited) {
        throw Exception(insufficientWalletError);
      }

      // Place the order only after successful debit
      final orderResult = await _orderService.placeSingleOrder(
        cookId: widget.cookId,
        customerName: customerName,
        customerPhone: customerPhone,
        deliveryAddress: deliveryAddress,
        items: items,
        totalAmount: grandTotal.toDouble(),
        paymentMethod: 'wallet',
      );

      final orderId = orderResult['id']?.toString() ?? '';

      await _loadWalletBalance();

      if (!mounted) return;
      setState(() => _isPlacingOrder = false);

      // Show success dialog
      _showOrderSuccessDialog(orderId);
    } catch (e) {
      debugPrint('Wallet order payment failed: $e');
      if (!mounted) return;
      setState(() => _isPlacingOrder = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${'order_failed'.tr(context)}: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 4)),
      );
    }
  }

  void _showOrderSuccessDialog(String orderId, {bool viaWallet = true}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 64),
            const SizedBox(height: 16),
            Text('order_placed'.tr(context), style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(viaWallet ? 'paid_wallet'.tr(context) : 'paid_razorpay'.tr(context), textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                if (orderId.isNotEmpty) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => OrderTrackingScreen(orderId: orderId, kitchenName: widget.kitchenName)),
                  );
                } else {
                  Navigator.of(context).pop(<String, int>{});
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(double.infinity, 48),
              ),
              child: Text('track_order'.tr(context), style: const TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop(<String, int>{});
              },
              child: Text('back_home'.tr(context), style: const TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  void _updateQty(String id, int delta) {
    setState(() {
      final newQty = (_cartItems[id] ?? 0) + delta;
      if (newQty <= 0) {
        _cartItems.remove(id);
      } else {
        _cartItems[id] = newQty;
      }
    });
  }

  @override
  void dispose() {
    _couponController.dispose();
    _paymentService.dispose();
    super.dispose();
  }

  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) {
      setState(() => _couponError = 'enter_coupon'.tr(context));
      return;
    }

    setState(() {
      _isApplyingCoupon = true;
      _couponError = null;
    });

    final coupon = await _couponService.validateCoupon(code);
    
    setState(() {
      _isApplyingCoupon = false;
      if (coupon != null) {
        _appliedCoupon = coupon;
        _couponError = null;
      } else {
        _couponError = 'coupon_invalid'.tr(context);
        _appliedCoupon = null;
      }
    });
  }

  void _removeCoupon() {
    setState(() {
      _appliedCoupon = null;
      _couponController.clear();
      _couponError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    int itemTotal = 0;
    _cartItems.forEach((key, quantity) {
      itemTotal += (widget.itemPrices[key] ?? 0) * quantity;
    });

    const int deliveryFee = 30;
    const int taxes = 15;
    
    // Calculate discount
    int discountAmount = 0;
    if (_appliedCoupon != null) {
      final discountPercent = _appliedCoupon!['discount_percent'] as int;
      discountAmount = (itemTotal * discountPercent / 100).round();
    }
    
    final int grandTotal = itemTotal + deliveryFee + taxes - discountAmount;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () {
            Navigator.pop(context, _cartItems);
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.kitchenName,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
            ),
            Text(
              'delivery_time'.tr(context),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFF1F5F9), height: 1),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Items List
                  ..._cartItems.entries.where((e) => e.value > 0).map((entry) {
                    final id = entry.key;
                    final name = widget.itemNames[id] ?? 'Dish';
                    final quantity = entry.value;
                    final price = widget.itemPrices[id] ?? 0;
                    final image = widget.itemImages[id];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Row(
                        children: [
                          if (image != null)
                            Container(
                              width: 48, height: 48,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(image: NetworkImage(image), fit: BoxFit.cover),
                              ),
                            )
                          else
                            Container(
                              width: 16,
                              height: 16,
                              margin: const EdgeInsets.only(top: 4, right: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFF16A34A)),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Icon(Icons.circle, size: 8, color: Color(0xFF16A34A)),
                            ),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF1E293B),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '₹${price * quantity}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF1E293B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      _buildQtyBtn(Icons.remove, () => _updateQty(id, -1)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        child: Text(
                                          '$quantity',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF16A34A),
                                          ),
                                        ),
                                      ),
                                      _buildQtyBtn(Icons.add, () => _updateQty(id, 1)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const Divider(height: 32, thickness: 8, color: Color(0xFFF8FAFC)),

                  // Coupon Section
                  Text(
                    'offers_benefits'.tr(context),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Applied Coupon Display
                  if (_appliedCoupon != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF16A34A)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Color(0xFF16A34A)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'coupon_applied'.tr(context),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF16A34A),
                                  ),
                                ),
                                Text(
                                  '${_appliedCoupon!['code']} - ${_appliedCoupon!['discount_percent']}% ${'off'.tr(context)}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: const Color(0xFF16A34A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _removeCoupon,
                            icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _couponError != null ? Colors.red : const Color(0xFFE2E8F0),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.local_offer, color: Color(0xFFC2941B), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _couponController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: InputDecoration(
                                hintText: 'hint_coupon'.tr(context),
                                hintStyle: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  color: const Color(0xFF94A3B8),
                                ),
                                border: InputBorder.none,
                              ),
                              onChanged: (_) => setState(() => _couponError = null),
                            ),
                          ),
                          _isApplyingCoupon
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : TextButton(
                                  onPressed: _applyCoupon,
                                  child: Text(
                                    'add'.tr(context),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF16A34A),
                                    ),
                                  ),
                                ),
                        ],
                      ),
                    ),
                    if (_couponError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _couponError!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ],

                  const Divider(height: 32, thickness: 8, color: Color(0xFFF8FAFC)),

                  // Bill Details
                  Text(
                    'bill_details'.tr(context),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildBillRow('item_total'.tr(context), '₹$itemTotal'),
                  _buildBillRow('delivery_fee'.tr(context), '₹$deliveryFee'),
                  _buildBillRow('taxes_charges'.tr(context), '₹$taxes'),
                  if (_appliedCoupon != null)
                    _buildBillRow(
                      'coupon_discount'.tr(context),
                      '-₹$discountAmount',
                      valueColor: const Color(0xFF16A34A),
                    ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(),
                  ),
                  _buildBillRow('to_pay'.tr(context), '₹$grandTotal', isBold: true),
                ],
              ),
            ),
          ),

          // Sticky Payment Footer
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4)),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Payment method selector
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
                    ),
                    child: Column(
                      children: [
                        _buildPaymentTile('wallet', 'Wallet Balance', Icons.account_balance_wallet, subtitle: _walletBalance >= grandTotal ? 'Available: \u20B9${_walletBalance.toStringAsFixed(0)}' : 'Insufficient balance (\u20B9${_walletBalance.toStringAsFixed(0)})'),
                        const Divider(height: 1, indent: 56),
                        _buildPaymentTile('gpay', 'Google Pay', Icons.g_mobiledata, assetPath: 'assets/payment_logos/gpay.png'),
                        const Divider(height: 1, indent: 56),
                        _buildPaymentTile('phonepe', 'PhonePe', Icons.payment, assetPath: 'assets/payment_logos/phonepe.png'),
                        const Divider(height: 1, indent: 56),
                        _buildPaymentTile('paytm', 'Paytm', Icons.account_balance_wallet, assetPath: 'assets/payment_logos/paytm.png'),
                        const Divider(height: 1, indent: 56),
                        _buildPaymentTile('razorpay', 'Cards / Netbanking / Other UPI', Icons.credit_card, assetPath: 'assets/payment_logos/razorpay.png'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Pay button
                  ElevatedButton(
                    onPressed: _isPlacingOrder ? null : () => _handlePayment(grandTotal),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (_selectedPaymentMethod == 'wallet') ? const Color(0xFF16A34A) : Colors.blue,
                      disabledBackgroundColor: Colors.grey,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 56),
                      elevation: 0,
                    ),
                    child: _isPlacingOrder
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('\u20B9$grandTotal', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                    Text('total_capital'.tr(context), style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.8))),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 16),
                                child: Text(
                                  (_selectedPaymentMethod == 'wallet')
                                    ? (_walletBalance >= grandTotal ? 'pay_wallet'.tr(context) : 'add_pay'.tr(context))
                                    : 'pay_razorpay'.tr(context),
                                  style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: isBold ? const Color(0xFF1E293B) : const Color(0xFF64748B),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: valueColor ?? (isBold ? const Color(0xFF1E293B) : const Color(0xFF64748B)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Icon(icon, size: 16, color: const Color(0xFF16A34A)),
      ),
    );
  }

  Widget _buildPaymentTile(String val, String title, IconData fallbackIcon, {String? subtitle, String? assetPath}) {
    return InkWell(
      onTap: () => setState(() => _selectedPaymentMethod = val),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: assetPath != null
                  ? Image.asset(
                      assetPath,
                      fit: BoxFit.contain,
                      errorBuilder: (ctx, err, stack) => Icon(fallbackIcon, color: Colors.grey.shade700, size: 20),
                    )
                  : Icon(fallbackIcon, color: Colors.grey.shade700, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                  if (subtitle != null)
                    Text(subtitle, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: subtitle.contains('Insufficient') ? Colors.red : Colors.grey.shade600))
                ],
              ),
            ),
            Icon(
              _selectedPaymentMethod == val ? Icons.radio_button_checked : Icons.radio_button_off,
              color: _selectedPaymentMethod == val ? const Color(0xFF16A34A) : Colors.grey.shade400,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
