import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/cart_service.dart';
import '../services/order_service.dart';
import '../services/coupon_service.dart';
import '../models/cart_item.dart';
import '../models/saved_address.dart';
import 'address_edit_screen.dart';
import 'payment_method_screen.dart';
import '../core/localization.dart';
import 'package:flutter/services.dart';
import '../utils/error_handler.dart';

/// Checkout screen with price verification, delivery address, and payment.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _supabase = Supabase.instance.client;
  final _noteCtrl = TextEditingController();
  final _couponCtrl = TextEditingController();
  final _orderService = OrderService();
  final _couponService = CouponService();

  // Core state
  bool _isLoading = true;
  bool _isContinuing = false;

  // Delivery address state
  SavedAddress? _selectedAddress;
  List<SavedAddress> _allAddresses = [];
  bool _isAddressLoading = true;

  // Price verification
  final Map<String, double> _verifiedPrices = {};
  final Map<String, bool> _availability = {};
  final Map<String, Map<String, double>> _kitchenCoords = {}; // cookId -> {lat, lng}
  final Map<String, bool> _isVegMap = {};
  List<String> _priceChanges = [];
  List<String> _unavailableItems = [];

  // Coupon state
  Map<String, dynamic>? _appliedCoupon;
  double _couponDiscount = 0.0;
  bool _isApplyingCoupon = false;
  String? _couponError;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _couponCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadSavedAddresses(),
      _verifyPrices(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadSavedAddresses() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      final data = await _supabase
          .from('saved_addresses')
          .select()
          .eq('user_id', user.id)
          .order('is_default', ascending: false);
      
      if (mounted) {
        setState(() {
          _allAddresses = (data as List).map((e) => SavedAddress.fromJson(e)).toList();
          if (_allAddresses.isNotEmpty) {
            _selectedAddress = _allAddresses.first;
          }
          _isAddressLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAddressLoading = false);
        ErrorHandler.showGracefulError(context, e);
      }
    }
  }


  Future<void> _verifyPrices() async {
    final cart = CartService.instance;
    final dishIds = cart.items.map((i) => i.dishId).toSet().toList();
    if (dishIds.isEmpty) return;

    try {
      // 1. Fetch current prices from menu_items
      final data = await _supabase
          .from('menu_items')
          .select() // Use select() to be more robust against missing columns
          .inFilter('id', dishIds);

      final priceChanges = <String>[];
      final unavailable = <String>[];
      final cookIds = <String>{};

      for (final row in data) {
        final id = row['id'].toString();
        final dbPrice = (row['price'] ?? 0).toDouble();
        final isAvailable = row['is_available'] ?? true;
        final isVeg = row['is_veg'] ?? true;
        final cookId = row['cook_id']?.toString();

        if (cookId != null) cookIds.add(cookId);

        _verifiedPrices[id] = dbPrice;
        _availability[id] = isAvailable;
        _isVegMap[id] = isVeg;

        // Check availability
        if (!isAvailable) {
          final item = cart.items.cast<CartItem?>().firstWhere((i) => i!.dishId == id, orElse: () => null);
          if (item != null) unavailable.add(item.dishName);
        }

        // Check price changes
        for (final item in cart.items.where((i) => i.dishId == id)) {
          if (item.price != dbPrice) {
            priceChanges.add(
              '${item.dishName}: \u20B9${item.price.toStringAsFixed(0)} → \u20B9${dbPrice.toStringAsFixed(0)}',
            );
          }
        }
      }

      // 2. Fetch Kitchen Coordinates for Radar
      if (cookIds.isNotEmpty) {
        final kitchenData = await _supabase
            .from('kitchens')
            .select('cook_id, latitude, longitude')
            .inFilter('cook_id', cookIds.toList());
        
        for (var k in (kitchenData as List)) {
          final cId = k['cook_id'].toString();
          final lat = k['latitude'] != null ? (k['latitude'] as num).toDouble() : null;
          final lng = k['longitude'] != null ? (k['longitude'] as num).toDouble() : null;
          if (lat != null && lng != null) {
            _kitchenCoords[cId] = {'lat': lat, 'lng': lng};
          }
        }
      }

      _priceChanges = priceChanges;
      _unavailableItems = unavailable;
    } catch (e) {
      if (mounted) ErrorHandler.showGracefulError(context, e);
    }
  }

  double get _verifiedTotal {
    double total = 0;
    for (final item in CartService.instance.items) {
      final price = _verifiedPrices[item.dishId] ?? item.price;
      if (_availability[item.dishId] != false) {
        total += price * item.quantity;
      }
    }
    return total;
  }

  double get _grandTotal {
    final subtotal = _verifiedTotal;
    if (subtotal == 0) return 0;
    const deliveryPartnerFee = 39.0;
    final supportFee = subtotal * 0.05; // 5% Home Chef Support Fee
    // No GST (turnover < 20L)
    return subtotal + deliveryPartnerFee + supportFee - _couponDiscount;
  }

  /// Apply coupon code
  Future<void> _applyCoupon() async {
    final code = _couponCtrl.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isApplyingCoupon = true;
      _couponError = null;
    });

    try {
      final coupon = await _couponService.validateCoupon(code);

      if (coupon == null) {
        setState(() {
          _couponError = 'Invalid or expired coupon code';
          _isApplyingCoupon = false;
        });
        return;
      }

      final discountPercent = coupon['discount_percent'] as int;
      final discount = _couponService.calculateDiscount(_verifiedTotal, discountPercent);

      setState(() {
        _appliedCoupon = coupon;
        _couponDiscount = discount;
        _isApplyingCoupon = false;
        _couponError = null;
      });

      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 Coupon applied! You save ₹${discount.toStringAsFixed(0)}'),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _couponError = 'Failed to apply coupon';
        _isApplyingCoupon = false;
      });
    }
  }

  /// Remove applied coupon
  void _removeCoupon() {
    setState(() {
      _appliedCoupon = null;
      _couponDiscount = 0.0;
      _couponCtrl.clear();
      _couponError = null;
    });
  }


  /// Navigate to payment method selection screen, with active order guard.
  Future<void> _continueToPayment() async {
    if (_selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or add a delivery address'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_unavailableItems.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please remove unavailable items before placing order'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isContinuing = true);

    // Active order guard
    try {
      final hasActive = await _orderService.hasActiveOrder();
      if (hasActive) {
        if (!mounted) return;
        setState(() => _isContinuing = false);
        _showActiveOrderDialog();
        return;
      }

      // Create Draft Order
      final user = Supabase.instance.client.auth.currentUser;
      final cart = CartService.instance;
      final allItems = cart.items.where((i) => _availability[i.dishId] != false).toList();
      if (allItems.isEmpty) throw Exception('No items');

      final cookId = allItems.first.cookId;
      final kitchenName = allItems.first.kitchenName;
      final coords = _kitchenCoords[cookId];

      final itemsPayload = allItems.map((item) => {
        'menu_item_id': item.dishId,
        'name': item.dishName,
        'quantity': item.quantity,
        'price': _verifiedPrices[item.dishId] ?? item.price,
        'image_url': item.imageUrl,
      }).toList();

      final result = await _orderService.createDraftOrder(
        cookId: cookId,
        customerName: _selectedAddress!.name ?? user?.userMetadata?['full_name'] ?? 'Guest',
        customerPhone: _selectedAddress!.phone ?? user?.phone ?? '',
        deliveryAddress: _selectedAddress!.fullAddress,
        items: itemsPayload,
        totalAmount: _grandTotal,
        kitchenName: kitchenName,
        pickupLat: coords?['lat'],
        pickupLng: coords?['lng'],
        deliveryLat: _selectedAddress!.latitude,
        deliveryLng: _selectedAddress!.longitude,
      );

      if (!mounted) return;
      setState(() => _isContinuing = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentMethodScreen(
            orderId: result['id'].toString(),
            grandTotal: _grandTotal,
            subtotal: _verifiedTotal,
            address: _selectedAddress!,
            kitchenName: kitchenName,
            note: _noteCtrl.text.trim().isNotEmpty ? _noteCtrl.text.trim() : null,
          ),
        ),
      );

    } catch (e) {
      if (!mounted) return;
      setState(() => _isContinuing = false);
      ErrorHandler.showGracefulError(context, e);
    }
  }

  void _showActiveOrderDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.delivery_dining_rounded, color: Colors.orange.shade700),
            const SizedBox(width: 10),
            Expanded(
              child: Text('active_order_title'.tr(context),
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
        content: Text(
          'active_order_msg'.tr(context),
          style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.grey.shade700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold, color: const Color(0xFF16A34A))),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Checkout', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF16A34A)))
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final cart = CartService.instance;
    final groups = cart.cartByKitchen;

    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  const SizedBox(height: 16),
                  
                  // 1. Delivery Address Section (Zomato style)
                  _buildPremiumAddressSection(),
                  const SizedBox(height: 20),

                  // Price change warnings
                  if (_priceChanges.isNotEmpty) _buildPriceWarning(),
                  // Unavailable items
                  if (_unavailableItems.isNotEmpty) _buildUnavailableWarning(),

                  // 2. Order items Summary
                  _buildSectionHeader(Icons.shopping_bag_outlined, 'order_summary'.tr(context)),
                  const SizedBox(height: 12),
                  ...groups.values.map((g) => _buildGroupSummary(g)),
                  const SizedBox(height: 20),

                  // 3. Special Instructions
                  _buildSectionHeader(Icons.note_alt_outlined, 'special_instructions'.tr(context)),
                  const SizedBox(height: 12),
                  _buildInstructionsCard(),
                  const SizedBox(height: 24),

                  // 4. Coupon Section
                  _buildSectionHeader(Icons.local_offer_outlined, 'Apply Coupon'),
                  const SizedBox(height: 12),
                  _buildCouponSection(),
                  const SizedBox(height: 24),

                  // 5. Bill Summary
                  _buildSectionHeader(Icons.receipt_long_outlined, 'bill_summary'.tr(context)),
                  const SizedBox(height: 12),
                  _buildBillSummary(cart),
                  _buildProfessionalNote(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildPlaceOrderBar(),
        ),
      ],
    );
  }

  Widget _buildPremiumAddressSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: _isAddressLoading 
        ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF16A34A))))
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Color(0xFF16A34A), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'delivering_to'.tr(context),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _showAddressSelector,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF16A34A),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      _selectedAddress == null ? 'ADD'.tr(context) : 'CHANGE'.tr(context),
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_selectedAddress != null) ...[
                Text(
                  _selectedAddress!.label.tr(context),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedAddress!.fullAddress,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
              ] else
                Text(
                  'no_address_selected'.tr(context),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: Colors.red.shade400,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
    );
  }

  Widget _buildInstructionsCard() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
      ),
      child: TextField(
        controller: _noteCtrl,
        maxLines: 2,
        style: GoogleFonts.plusJakartaSans(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'cooking_instructions_hint'.tr(context),
          hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.grey.shade400),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(12),
        ),
      ),
    );
  }

  Widget _buildCouponSection() {
    if (_appliedCoupon != null) {
      // Show applied coupon
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF16A34A), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.local_offer, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _appliedCoupon!['code'] ?? '',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF16A34A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_appliedCoupon!['discount_percent']}% off · You save ₹${_couponDiscount.toStringAsFixed(0)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _removeCoupon,
              icon: Icon(Icons.close, color: Colors.grey.shade500, size: 20),
              tooltip: 'Remove coupon',
            ),
          ],
        ),
      );
    }

    // Show coupon input
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _couponCtrl,
                  textCapitalization: TextCapitalization.characters,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter coupon code',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.normal,
                    ),
                    prefixIcon: Icon(Icons.local_offer_outlined, color: Colors.grey.shade400, size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ElevatedButton(
                  onPressed: _isApplyingCoupon ? null : _applyCoupon,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isApplyingCoupon
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('APPLY', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
                ),
              ),
            ],
          ),
          if (_couponError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                _couponError!,
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.red.shade600),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBillSummary(CartService cart) {
    final subtotal = _verifiedTotal;
    const deliveryPartnerFee = 39.0;
    final supportFee = subtotal * 0.05; // 5% Home Chef Support Fee
    final total = subtotal + deliveryPartnerFee + supportFee - _couponDiscount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
      ),
      child: Column(
        children: [
          _buildBillRow('item_total'.tr(context), subtotal),
          const SizedBox(height: 12),
          _buildBillRow('delivery_partner_fee'.tr(context), deliveryPartnerFee, isGreen: true),
          const SizedBox(height: 12),
          _buildBillRow(
            'home_chef_support_fee'.tr(context), 
            supportFee,
            subtitle: 'support_fee_desc'.tr(context),
          ),
          if (_couponDiscount > 0) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.local_offer, size: 14, color: Color(0xFF16A34A)),
                    const SizedBox(width: 6),
                    Text(
                      'Coupon (${_appliedCoupon?['code'] ?? ''})',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: const Color(0xFF16A34A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Text(
                  '-₹${_couponDiscount.toStringAsFixed(0)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          _buildTaxExemptNote(),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, thickness: 0.5),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'grand_total'.tr(context),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '\u20B9${total.toStringAsFixed(0)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalNote() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_outlined, color: Colors.blue.shade700, size: 18),
              const SizedBox(width: 8),
              Text(
                'authentic_experience'.tr(context),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'checkout_note_desc'.tr(context),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: Colors.blue.shade900,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxExemptNote() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 14, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'tax_exempt_note'.tr(context),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                color: Colors.blueGrey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillRow(String label, double value, {bool isGreen = false, String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              '\u20B9${value.toStringAsFixed(0)}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isGreen ? const Color(0xFF16A34A) : Colors.black,
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              color: Colors.grey.shade400,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade800),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: Colors.grey.shade800,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  void _showAddressSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (context, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'select_address'.tr(context),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_location_alt_outlined, color: Color(0xFF16A34A)),
                      onPressed: () async {
                        Navigator.pop(context);
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AddressEditScreen()),
                        );
                        if (result == true) {
                          _loadSavedAddresses();
                        }
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: _allAddresses.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final addr = _allAddresses[index];
                    final isSelected = _selectedAddress?.id == addr.id;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedAddress = addr);
                        Navigator.pop(context);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF16A34A) : Colors.grey.shade200,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              addr.type.toLowerCase() == 'home' ? Icons.home_outlined : 
                              addr.type.toLowerCase() == 'work' ? Icons.work_outline : Icons.location_on_outlined,
                              color: isSelected ? const Color(0xFF16A34A) : Colors.grey,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    addr.label.tr(context),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    addr.fullAddress,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle, color: Color(0xFF16A34A)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceWarning() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber, color: Colors.amber, size: 18),
              const SizedBox(width: 6),
              Text('Prices Updated', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.amber.shade800)),
            ],
          ),
          const SizedBox(height: 6),
          ...(_priceChanges.map((c) => Text(c, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.amber.shade900)))),
        ],
      ),
    );
  }

  Widget _buildUnavailableWarning() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 18),
              const SizedBox(width: 6),
              Text('Items Unavailable', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.red.shade800)),
            ],
          ),
          const SizedBox(height: 6),
          ...(_unavailableItems.map((n) => Text(n, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.red.shade900)))),
        ],
      ),
    );
  }

  Widget _buildGroupSummary(KitchenCartGroup group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.restaurant, size: 16, color: Color(0xFF16A34A)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    group.kitchenName,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.5),
          ...group.items.map((item) {
            final verifiedPrice = _verifiedPrices[item.dishId] ?? item.price;
            final isAvailable = _availability[item.dishId] != false;
            return Opacity(
              opacity: isAvailable ? 1.0 : 0.4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        border: Border.all(color: (_isVegMap[item.dishId] ?? true) ? Colors.green : Colors.red),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: Container(
                        decoration: BoxDecoration(
                          color: (_isVegMap[item.dishId] ?? true) ? Colors.green : Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item.quantity} x ${item.dishName}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (!isAvailable)
                            Text(
                              'Out of stock',
                              style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      '\u20B9${(verifiedPrice * item.quantity).toStringAsFixed(0)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
  Widget _buildPlaceOrderBar() {
    final subtotal = _verifiedTotal;
    const deliveryPartnerFee = 39.0;
    final supportFee = subtotal * 0.05;
    final total = subtotal + deliveryPartnerFee + supportFee - _couponDiscount;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'total_to_pay'.tr(context).toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Colors.grey.shade500,
                  letterSpacing: 1.1,
                ),
              ),
              Text(
                '\u20B9${total.toStringAsFixed(0)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: ElevatedButton(
              onPressed: (_isContinuing || _isLoading || _selectedAddress == null)
                ? null
                : () {
                    HapticFeedback.mediumImpact();
                    _continueToPayment();
                  },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isContinuing
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'continue_btn'.tr(context).toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, letterSpacing: 1),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
