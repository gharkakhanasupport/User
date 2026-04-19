import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/cart_service.dart';
import '../services/wallet_service.dart';
import '../models/cart_item.dart';
import 'my_wallet_screen.dart';
import '../utils/supabase_config.dart';
import 'order_confirmation_screen.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../services/payment_service.dart';
import '../models/saved_address.dart';
import 'address_edit_screen.dart';
import '../core/localization.dart';

/// Checkout screen with price verification, delivery address, and payment.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _supabase = Supabase.instance.client;
  final _walletService = WalletService();
  final _noteCtrl = TextEditingController();

  // Core state
  bool _isLoading = true;
  bool _isPlacing = false;
  String _selectedPaymentMethod = 'wallet';
  final _paymentService = PaymentService();
  double _walletBalance = 0.0;

  // Delivery address state
  SavedAddress? _selectedAddress;
  List<SavedAddress> _allAddresses = [];
  bool _isAddressLoading = true;

  // Price verification
  final Map<String, double> _verifiedPrices = {};
  final Map<String, bool> _availability = {};
  final Map<String, bool> _isVegMap = {};
  List<String> _priceChanges = [];
  List<String> _unavailableItems = [];

@override
  void initState() {
    super.initState();
    _paymentService.onSuccess = _handlePaymentSuccess;
    _paymentService.onFailure = _handlePaymentError;
    _loadData();
  }



  @override
  void dispose() {
    _paymentService.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadSavedAddresses(),
      _verifyPrices(),
      _loadWalletBalance(),
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
      debugPrint('CheckoutScreen: loadSavedAddresses error: $e');
      if (mounted) setState(() => _isAddressLoading = false);
    }
  }


  Future<void> _loadWalletBalance() async {
    _walletBalance = await _walletService.getBalance();
  }

  Future<void> _verifyPrices() async {
    final cart = CartService.instance;
    final dishIds = cart.items.map((i) => i.dishId).toSet().toList();
    if (dishIds.isEmpty) return;

    try {
      // Fetch current prices from menu_items
      final data = await _supabase
          .from('menu_items')
          .select('id, price, is_available, is_veg')
          .inFilter('id', dishIds);

      final priceChanges = <String>[];
      final unavailable = <String>[];

      for (final row in data) {
        final id = row['id'].toString();
        final dbPrice = (row['price'] ?? 0).toDouble();
        final isAvailable = row['is_available'] ?? true;
        final isVeg = row['is_veg'] ?? true;

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

      _priceChanges = priceChanges;
      _unavailableItems = unavailable;
    } catch (e) {
      debugPrint('CheckoutScreen: verifyPrices error: $e');
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
    final govTaxes = subtotal * 0.05;
    return subtotal + deliveryPartnerFee + govTaxes;
  }


  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    _finalizeOrder('razorpay');
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (mounted) {
      setState(() => _isPlacing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: ${response.message ?? "Unknown error"}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }


  Future<void> _placeOrder() async {
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

    setState(() => _isPlacing = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Not logged in');

      final total = _grandTotal;

      if (_selectedPaymentMethod == 'wallet') {
        // We now handle wallet debit ATOMICALLY inside the RPC
        await _finalizeOrder('wallet');
      } else if (_selectedPaymentMethod == 'cod') {
        await _finalizeOrder('cod');
      } else {
        // Razorpay / Online
        _paymentService.openCheckout(
          amount: total,
          kitchenName: 'Ghar Ka Khana',
          userEmail: user.email ?? '',
          userPhone: _selectedAddress?.phoneNumber ?? user.phone ?? '',
          description: 'Food Order',
          notes: {
            'user_id': user.id,
            'address_id': _selectedAddress?.id ?? '',
          },
        );
      }
    } catch (e) {
      debugPrint('CheckoutScreen: placeOrder error: $e');
      if (!mounted) return;
      setState(() => _isPlacing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order failed: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _finalizeOrder(String paymentMethod) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Not logged in');
      final cart = CartService.instance;
      final groups = cart.cartByKitchen;
      final deliveryAddress = {
        'name': _selectedAddress?.fullName ?? user.userMetadata?['full_name'] ?? 'Guest',
        'phone': _selectedAddress?.phoneNumber ?? user.phone ?? '',
        'address': _selectedAddress?.fullAddress ?? _selectedAddress?.streetAddress ?? '',
        'city': _selectedAddress?.city ?? '',
        'pincode': _selectedAddress?.pincode ?? '',
        'label': _selectedAddress?.label ?? 'Home',
      };
      final ordersPayload = groups.values.map((group) {
        return {
          'cook_id': group.cookId,
          'kitchen_name': group.kitchenName,
          'delivery_fee': 0,
          'note': _noteCtrl.text.trim().isNotEmpty ? _noteCtrl.text.trim() : null,
          'items': group.items.where((i) => _availability[i.dishId] != false).map((item) => {
            'menu_item_id': item.dishId,
            'dish_name': item.dishName,
            'price_at_order': _verifiedPrices[item.dishId] ?? item.price,
            'quantity': item.quantity,
            'image_url': item.imageUrl,
          }).toList(),
        };
      }).toList();

      // Call atomic RPC (now handles wallet debit and kitchen updates)
      final result = await _supabase.rpc('place_split_order', params: {
        'p_user_id': user.id,
        'p_delivery_address': deliveryAddress,
        'p_payment_method': paymentMethod,
        'p_orders': ordersPayload,
      });

      // Dual-write to Kitchen DB for each sub-order
      try {
        final resultList = result is List ? result : [result];
        for (final orderInfo in resultList) {
          final orderId = orderInfo['order_id']?.toString() ?? '';
          final cookId = orderInfo['cook_id']?.toString() ?? '';
          final total = (orderInfo['total'] ?? 0).toDouble();

          // Find matching group for items
          final matchingGroup = groups.values.cast<KitchenCartGroup?>().firstWhere(
                (g) => g!.cookId == cookId,
                orElse: () => null,
              );

          if (matchingGroup != null) {
            final items = matchingGroup.items.map((i) => {
                  'menu_item_id': i.dishId,
                  'name': i.dishName,
                  'quantity': i.quantity,
                  'price': _verifiedPrices[i.dishId] ?? i.price,
                }).toList();

            await KitchenDbConfig.client.from('orders').upsert({
              'id': orderId,
              'cook_id': cookId,
              'customer_id': user.id,
              'customer_name': _selectedAddress?.fullName ?? user.userMetadata?['full_name'] ?? 'Guest',
              'customer_phone': _selectedAddress?.phoneNumber ?? user.phone ?? '',
              'delivery_address': _selectedAddress?.fullAddress ?? _selectedAddress?.streetAddress ?? '',
              'items': items,
              'total_amount': total,
              'status': 'pending',
            });
          }
        }
      } catch (e) {
        debugPrint('CheckoutScreen: Kitchen DB sync failed: $e');
      }

      // Success — clear cart and navigate
      CartService.instance.clearCart();
      setState(() => _isPlacing = false);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrderConfirmationScreen(
            orderResults: result is List
                ? List<Map<String, dynamic>>.from(result)
                : [Map<String, dynamic>.from(result)],
          ),
        ),
      );
    } on PostgrestException catch (e) {
      debugPrint('CheckoutScreen: RPC Error: ${e.message} (${e.code})');
      if (!mounted) return;
      setState(() => _isPlacing = false);
      
      String errorMsg = e.message;
      if (errorMsg.contains('INSUFFICIENT_FUNDS')) {
        errorMsg = 'Insufficient wallet balance for this order.';
      } else if (errorMsg.contains('WALLET_NOT_FOUND')) {
        errorMsg = 'No wallet found for your account.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order failed: $errorMsg'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      debugPrint('CheckoutScreen: finalizeOrder error: $e');
      if (!mounted) return;
      setState(() => _isPlacing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order failed: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
      );
    }
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

                  // 4. Bill Summary
                  _buildSectionHeader(Icons.receipt_long_outlined, 'bill_summary'.tr(context)),
                  const SizedBox(height: 12),
                  _buildBillSummary(cart),
                  const SizedBox(height: 24),

                  // 5. Payment method
                  _buildSectionHeader(Icons.payment_rounded, 'payment_method'.tr(context)),
                  const SizedBox(height: 12),
                  _buildPaymentToggle(),
                  const SizedBox(height: 120), // Padding for sticky button
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
                  _selectedAddress!.label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedAddress!.fullAddress ?? _selectedAddress!.streetAddress,
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

  Widget _buildBillSummary(CartService cart) {
    final subtotal = _verifiedTotal;
    const deliveryPartnerFee = 39.0;
    final govTaxes = subtotal * 0.05; // 5% GST
    final total = subtotal + deliveryPartnerFee + govTaxes;

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
          _buildBillRow('gov_taxes_rest_charges'.tr(context), govTaxes),
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

  Widget _buildBillRow(String label, double value, {bool isGreen = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          '\u20B9${value.toStringAsFixed(0)}',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isGreen ? const Color(0xFF16A34A) : Colors.black,
          ),
        ),
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
                                    addr.label,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    addr.fullAddress ?? addr.streetAddress,
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

  Widget _buildPaymentToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
      ),
      child: Column(
        children: [
          _buildPaymentTile(
            'wallet',
            'GKK Wallet',
            _walletBalance < _verifiedTotal 
                ? 'Insufficient balance (\u20B9${_walletBalance.toStringAsFixed(0)})'
                : 'Balance: \u20B9${_walletBalance.toStringAsFixed(0)}',
            Icons.account_balance_wallet_outlined,
            showAddMoney: _walletBalance < _verifiedTotal,
          ),
          const Divider(height: 1, indent: 60),
          _buildPaymentTile(
            'razorpay',
            'Online Payment',
            'UPI, Cards, Netbanking',
            Icons.speed_outlined,
          ),
          const Divider(height: 1, indent: 60),
          _buildPaymentTile(
            'cod',
            'Cash on Delivery',
            'Pay at your doorstep',
            Icons.handshake_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentTile(String value, String title, String subtitle, IconData icon, {bool showAddMoney = false}) {
    final isSelected = _selectedPaymentMethod == value;
    final isWallet = value == 'wallet';
    final isDisabled = isWallet && _walletBalance < _verifiedTotal;

    return InkWell(
      onTap: isDisabled ? null : () => setState(() => _selectedPaymentMethod = value),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF16A34A).withValues(alpha: 0.1) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: isSelected ? const Color(0xFF16A34A) : Colors.grey),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isDisabled ? Colors.grey : Colors.black,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: isDisabled ? Colors.red.shade300 : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            if (showAddMoney) ...[
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MyWalletScreen())).then((_) => _loadWalletBalance());
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  backgroundColor: const Color(0xFF16A34A).withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('ADD', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A))),
              ),
              const SizedBox(width: 8),
            ],
            if (isSelected)
              const Icon(Icons.radio_button_checked, color: Color(0xFF16A34A))
            else
              Icon(Icons.radio_button_off, color: isDisabled ? Colors.grey.shade200 : Colors.grey.shade300),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceOrderBar() {
    final subtotal = _verifiedTotal;
    const deliveryPartnerFee = 39.0;
    final govTaxes = subtotal * 0.05;
    final total = subtotal + deliveryPartnerFee + govTaxes;

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
              onPressed: (_isPlacing || _isLoading || _selectedAddress == null) ? null : _placeOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isPlacing
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'place_order'.tr(context).toUpperCase(),
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
