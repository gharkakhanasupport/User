import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/order_service.dart';
import '../services/cart_service.dart';
import '../services/wallet_service.dart';
import '../services/payment_service.dart';
import '../core/localization.dart';
import '../models/saved_address.dart';
import 'order_tracking_screen.dart';
import '../utils/error_handler.dart';

/// Payment method selection screen.
/// Receives checkout data and lets user pick Razorpay / Wallet / COD.
class PaymentMethodScreen extends StatefulWidget {
  final String orderId;
  final double grandTotal;
  final double subtotal;
  final SavedAddress address;
  final String kitchenName;
  final String? note;

  const PaymentMethodScreen({
    super.key,
    required this.orderId,
    required this.grandTotal,
    required this.subtotal,
    required this.address,
    required this.kitchenName,
    this.note,
  });

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final _paymentService = PaymentService();
  final _walletService = WalletService();

  String? _selectedMethod;
  bool _isProcessing = false;
  double _walletBalance = 0.0;
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;
  Timer? _countdownTimer;
  int _secondsRemaining = 300; // 5 minutes

  @override
  void initState() {
    super.initState();
    _startTimer();
    _paymentService.onSuccess = _onRazorpaySuccess;
    _paymentService.onFailure = _onRazorpayFailure;
    _loadWalletBalance();

    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
  }

  void _startTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _countdownTimer?.cancel();
          _handleTimeout();
        }
      });
    });
  }

  Future<void> _handleTimeout() async {
    if (_isProcessing) return; // Don't timeout if payment is in progress
    setState(() => _isProcessing = true);
    await OrderService().cancelDraftOrder(widget.orderId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payment time expired. Order cancelled.'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.pop(context); // Go back to Checkout
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _paymentService.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadWalletBalance() async {
    final bal = await _walletService.getBalance();
    if (mounted) setState(() => _walletBalance = bal);
  }

  void _selectMethod(String method) {
    HapticFeedback.selectionClick();
    setState(() => _selectedMethod = method);
    _slideCtrl.forward();
  }

  // ── Payment handlers ──

  void _onRazorpaySuccess(dynamic response) {
    _finalizeOrder('razorpay');
  }

  void _onRazorpayFailure(dynamic response) {
    if (mounted) {
      setState(() => _isProcessing = false);
      ErrorHandler.showGracefulError(context, 'payment_failed'.tr(context));
    }
  }

  Future<void> _handlePay() async {
    if (_selectedMethod == null || _isProcessing) return;
    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    if (_selectedMethod == 'razorpay') {
      final user = _supabase.auth.currentUser;
      _paymentService.openCheckout(
        amount: widget.grandTotal,
        kitchenName: 'Ghar Ka Khana',
        userEmail: user?.email ?? '',
        userPhone: widget.address.phone ?? user?.phone ?? '',
        description: 'Food Order',
        notes: {
          'user_id': user?.id ?? '',
          'address_id': widget.address.id,
        },
      );
    } else if (_selectedMethod == 'wallet') {
      if (_walletBalance < widget.grandTotal) {
        setState(() => _isProcessing = false);
        _showInsufficientDialog();
        return;
      }
      await _finalizeOrder('wallet');
    } else if (_selectedMethod == 'cod') {
      await _finalizeOrder('cod');
    }
  }

  void _showInsufficientDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.account_balance_wallet, color: Colors.orange.shade700),
            const SizedBox(width: 10),
            Text('Insufficient Balance',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Text(
          'Your wallet balance (₹${_walletBalance.toStringAsFixed(0)}) is not enough for ₹${widget.grandTotal.toStringAsFixed(0)}. Please add money or choose a different payment method.',
          style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.grey.shade700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF16A34A))),
          ),
        ],
      ),
    );
  }

  Future<void> _finalizeOrder(String paymentMethod) async {
    try {
      await _finalizeSingleOrder(paymentMethod);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ErrorHandler.showGracefulError(context, e);
    }
  }

  Future<void> _finalizeSingleOrder(String paymentMethod) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not logged in');
    
    final orderService = OrderService();
    await orderService.confirmOrder(
      orderId: widget.orderId,
      paymentMethod: paymentMethod,
      totalAmount: widget.grandTotal,
    );

    CartService.instance.clearCart();
    if (!mounted) return;
    _navigateToTracking(widget.orderId, widget.kitchenName);
  }

  Future<void> _onBack() async {
    if (_isProcessing) return;
    final cancel = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Cancel Payment?', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to go back? This will cancel your current order.', style: GoogleFonts.plusJakartaSans()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('NO', style: GoogleFonts.plusJakartaSans(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('YES, CANCEL', style: GoogleFonts.plusJakartaSans(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    
    if (cancel == true) {
      setState(() => _isProcessing = true);
      await OrderService().cancelDraftOrder(widget.orderId);
      if (mounted) Navigator.pop(context);
    }
  }



  void _navigateToTracking(String orderId, String kitchenName) {
    setState(() => _isProcessing = false);
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => OrderTrackingScreen(orderId: orderId, kitchenName: kitchenName),
      ),
      (route) => route.isFirst,
    );
  }

  // ── UI ──

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _onBack();
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _onBack(),
          ),
          title: Text('select_payment'.tr(context),
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          actions: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  '${(_secondsRemaining ~/ 60).toString().padLeft(2, '0')}:${(_secondsRemaining % 60).toString().padLeft(2, '0')}',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _secondsRemaining < 60 ? Colors.red : Colors.orange.shade700,
                  ),
                ),
              ),
            ),
          ],
        ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 140),
            children: [
              // Order total summary
              _buildTotalCard(),
              const SizedBox(height: 24),

              // Payment methods header
              Text(
                'select_payment_method'.tr(context).toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Colors.grey.shade600,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),

              // Payment option cards
              _buildPaymentCard(
                id: 'razorpay',
                icon: Icons.credit_card_rounded,
                title: 'pay_now'.tr(context),
                subtitle: 'pay_now_desc'.tr(context),
                color: Colors.blue,
                gradient: const [Color(0xFF2563EB), Color(0xFF3B82F6)],
              ),
              const SizedBox(height: 12),
              _buildPaymentCard(
                id: 'wallet',
                icon: Icons.account_balance_wallet_rounded,
                title: 'gkk_wallet'.tr(context),
                subtitle: '₹${_walletBalance.toStringAsFixed(0)} ${'available'.tr(context)}',
                color: const Color(0xFF16A34A),
                gradient: const [Color(0xFF16A34A), Color(0xFF22C55E)],
                badge: _walletBalance >= widget.grandTotal ? null : 'LOW',
              ),
              const SizedBox(height: 12),
              _buildPaymentCard(
                id: 'cod',
                icon: Icons.payments_rounded,
                title: 'cash_on_delivery'.tr(context),
                subtitle: 'cod_desc'.tr(context),
                color: Colors.orange,
                gradient: [Colors.orange.shade600, Colors.orange.shade400],
              ),

              const SizedBox(height: 24),
              // Security note
              _buildSecurityNote(),
            ],
          ),

          // Bottom pay button (slides up when method selected)
          if (_selectedMethod != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SlideTransition(
                position: _slideAnim,
                child: _buildPayButton(),
              ),
            ),
        ],
      ),
    ));
  }

  Widget _buildTotalCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF334155)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('total_to_pay'.tr(context).toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white60, letterSpacing: 1)),
              const SizedBox(height: 4),
              Text('₹${widget.grandTotal.toStringAsFixed(0)}',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard({
    required String id,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required List<Color> gradient,
    String? badge,
  }) {
    final isSelected = _selectedMethod == id;
    return GestureDetector(
      onTap: () => _selectMethod(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 4))]
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(title,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black87)),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(badge,
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9, fontWeight: FontWeight.w800, color: Colors.red)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            // Radio
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isSelected ? color : Colors.grey.shade300, width: 2),
                color: isSelected ? color : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_rounded, size: 18, color: Colors.blue.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'secure_payment_note'.tr(context),
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.blue.shade800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayButton() {
    String label;
    Color bgColor;
    IconData btnIcon;

    switch (_selectedMethod) {
      case 'razorpay':
        label = '${'pay_now'.tr(context)} ₹${widget.grandTotal.toStringAsFixed(0)}';
        bgColor = const Color(0xFF2563EB);
        btnIcon = Icons.credit_card_rounded;
        break;
      case 'wallet':
        label = '${'pay_wallet'.tr(context)} ₹${widget.grandTotal.toStringAsFixed(0)}';
        bgColor = const Color(0xFF16A34A);
        btnIcon = Icons.account_balance_wallet_rounded;
        break;
      case 'cod':
        label = 'place_order'.tr(context);
        bgColor = Colors.orange.shade700;
        btnIcon = Icons.payments_rounded;
        break;
      default:
        label = 'pay_now'.tr(context);
        bgColor = Colors.grey;
        btnIcon = Icons.payment;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, -5)),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _handlePay,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          minimumSize: const Size(double.infinity, 56),
        ),
        child: _isProcessing
            ? const SizedBox(
                height: 22, width: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(btnIcon, size: 20),
                  const SizedBox(width: 10),
                  Text(label,
                      style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5)),
                ],
              ),
      ),
    );
  }
}
