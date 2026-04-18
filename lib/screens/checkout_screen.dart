import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/cart_service.dart';
import '../services/user_service.dart';
import '../services/wallet_service.dart';
import '../models/cart_item.dart';
import '../utils/supabase_config.dart';
import 'order_confirmation_screen.dart';

/// Checkout screen with price verification, delivery address, and payment.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _supabase = Supabase.instance.client;
  final _userService = UserService();
  final _walletService = WalletService();
  final _formKey = GlobalKey<FormState>();

  // Delivery address controllers
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  bool _isLoading = true;
  bool _isPlacing = false;
  bool _payWithWallet = true;
  double _walletBalance = 0.0;

  // Price verification
  final Map<String, double> _verifiedPrices = {};
  final Map<String, bool> _availability = {};
  List<String> _priceChanges = [];
  List<String> _unavailableItems = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _pincodeCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadUserProfile(),
      _verifyPrices(),
      _loadWalletBalance(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadUserProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      final data = await _userService.getUserData(user.id);
      if (data != null && mounted) {
        _nameCtrl.text = data['name'] ?? user.userMetadata?['full_name'] ?? '';
        _phoneCtrl.text = data['phone'] ?? user.phone ?? '';
        _addressCtrl.text = data['address'] ?? '';
        _cityCtrl.text = data['city'] ?? '';
        _pincodeCtrl.text = data['pincode'] ?? '';
      }
    } catch (e) {
      debugPrint('CheckoutScreen: loadUserProfile error: $e');
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
          .select('id, price, is_available')
          .inFilter('id', dishIds);

      final priceChanges = <String>[];
      final unavailable = <String>[];

      for (final row in data) {
        final id = row['id'].toString();
        final dbPrice = (row['price'] ?? 0).toDouble();
        final isAvailable = row['is_available'] ?? true;

        _verifiedPrices[id] = dbPrice;
        _availability[id] = isAvailable;

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

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;
    if (_unavailableItems.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please remove unavailable items before placing order'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isPlacing = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Not logged in');

      final cart = CartService.instance;
      final groups = cart.cartByKitchen;

      // Build delivery address
      final deliveryAddress = {
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'pincode': _pincodeCtrl.text.trim(),
      };

      // Build p_orders payload with DB-verified prices
      final ordersPayload = groups.values.map((group) {
        return {
          'cook_id': group.cookId,
          'kitchen_name': group.kitchenName,
          'delivery_fee': 0,
          'note': _noteCtrl.text.trim().isNotEmpty ? _noteCtrl.text.trim() : null,
          'items': group.items
              .where((i) => _availability[i.dishId] != false) // skip unavailable
              .map((item) => {
                    'menu_item_id': item.dishId,
                    'dish_name': item.dishName,
                    'price_at_order': _verifiedPrices[item.dishId] ?? item.price,
                    'quantity': item.quantity,
                    'image_url': item.imageUrl,
                  })
              .toList(),
        };
      }).toList();

      // Wallet payment check
      if (_payWithWallet) {
        if (_walletBalance < _verifiedTotal) {
          if (!mounted) return;
          setState(() => _isPlacing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Insufficient wallet balance (\u20B9${_walletBalance.toStringAsFixed(0)}). Need \u20B9${_verifiedTotal.toStringAsFixed(0)}.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        // Debit wallet first
        final debited = await _walletService.payFromWallet(
          _verifiedTotal,
          'split_order_${DateTime.now().millisecondsSinceEpoch}',
        );
        if (!debited) throw Exception('Wallet debit failed');
      }

      // Call atomic RPC
      final result = await _supabase.rpc('place_split_order', params: {
        'p_user_id': user.id,
        'p_delivery_address': deliveryAddress,
        'p_payment_method': _payWithWallet ? 'wallet' : 'razorpay',
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
              'customer_name': _nameCtrl.text.trim(),
              'customer_phone': _phoneCtrl.text.trim(),
              'delivery_address': _addressCtrl.text.trim(),
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
    } catch (e) {
      debugPrint('CheckoutScreen: placeOrder error: $e');
      if (!mounted) return;
      setState(() => _isPlacing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order failed: $e'), backgroundColor: Colors.red),
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

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Price change warnings
              if (_priceChanges.isNotEmpty) _buildPriceWarning(),
              // Unavailable items
              if (_unavailableItems.isNotEmpty) _buildUnavailableWarning(),
              // Order summary
              _buildSectionTitle('Order Summary'),
              const SizedBox(height: 8),
              ...groups.values.map((g) => _buildGroupSummary(g)),
              const SizedBox(height: 20),
              // Delivery address
              _buildSectionTitle('Delivery Address'),
              const SizedBox(height: 8),
              _buildAddressForm(),
              const SizedBox(height: 20),
              // Note
              _buildSectionTitle('Order Note (optional)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _noteCtrl,
                maxLines: 2,
                decoration: _inputDeco('Any special instructions...'),
              ),
              const SizedBox(height: 20),
              // Payment method
              _buildSectionTitle('Payment Method'),
              const SizedBox(height: 8),
              _buildPaymentToggle(),
              const SizedBox(height: 100),
            ],
          ),
        ),
        _buildPlaceOrderBar(),
      ],
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

  Widget _buildSectionTitle(String title) {
    return Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold));
  }

  Widget _buildGroupSummary(KitchenCartGroup group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.kitchenName,
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF16A34A)),
          ),
          const SizedBox(height: 8),
          ...group.items.map((item) {
            final verifiedPrice = _verifiedPrices[item.dishId] ?? item.price;
            final isAvailable = _availability[item.dishId] != false;
            return Opacity(
              opacity: isAvailable ? 1.0 : 0.4,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Text('${item.quantity}x ', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13)),
                    Expanded(child: Text(item.dishName, style: GoogleFonts.plusJakartaSans(fontSize: 13))),
                    Text(
                      '\u20B9${(verifiedPrice * item.quantity).toStringAsFixed(0)}',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 6),
          Divider(color: Colors.grey.shade200, height: 1),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Subtotal', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
              Text(
                '\u20B9${group.items.where((i) => _availability[i.dishId] != false).fold<double>(0, (s, i) => s + (_verifiedPrices[i.dishId] ?? i.price) * i.quantity).toStringAsFixed(0)}',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddressForm() {
    return Form(
      key: _formKey,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)],
        ),
        child: Column(
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: _inputDeco('Full Name'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _phoneCtrl,
              decoration: _inputDeco('Phone Number'),
              keyboardType: TextInputType.phone,
              validator: (v) => (v == null || v.trim().length < 10) ? 'Valid phone number required' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _addressCtrl,
              decoration: _inputDeco('Delivery Address'),
              maxLines: 2,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cityCtrl,
                    decoration: _inputDeco('City'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _pincodeCtrl,
                    decoration: _inputDeco('Pincode'),
                    keyboardType: TextInputType.number,
                    validator: (v) => (v == null || v.trim().length < 5) ? 'Valid pincode required' : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.plusJakartaSans(color: Colors.grey.shade400, fontSize: 14),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _buildPaymentToggle() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)],
      ),
      child: Column(
        children: [
          RadioListTile<bool>(
            value: true,
            // ignore: deprecated_member_use
            groupValue: _payWithWallet,
            // ignore: deprecated_member_use
            onChanged: (v) => setState(() => _payWithWallet = v!),
            title: Text('Wallet (\u20B9${_walletBalance.toStringAsFixed(0)})', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
            subtitle: _walletBalance < _verifiedTotal
                ? Text(
                    'Insufficient balance',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.red),
                  )
                : null,
            activeColor: const Color(0xFF16A34A),
            dense: true,
          ),
          RadioListTile<bool>(
            value: false,
            // ignore: deprecated_member_use
            groupValue: _payWithWallet,
            // ignore: deprecated_member_use
            onChanged: (v) => setState(() => _payWithWallet = v!),
            title: Text('Razorpay (UPI/Card)', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
            activeColor: const Color(0xFF16A34A),
            dense: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceOrderBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Total', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey)),
                Text(
                  '\u20B9${_verifiedTotal.toStringAsFixed(0)}',
                  style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isPlacing ? null : _placeOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                child: _isPlacing
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Place Order', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
