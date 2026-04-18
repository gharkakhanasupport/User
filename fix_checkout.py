import re

path = r'd:\GKK APP\GKK ADMIN ALL APP\USER\lib\screens\checkout_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    orig_content = f.read()

content = orig_content

# 1. Imports
if 'package:razorpay_flutter/razorpay_flutter.dart' not in content:
    content = content.replace("import 'order_confirmation_screen.dart';", "import 'order_confirmation_screen.dart';\nimport 'package:razorpay_flutter/razorpay_flutter.dart';\nimport '../services/payment_service.dart';")

# 2. Variables
content = content.replace('bool _payWithWallet = true;', '''String _selectedPaymentMethod = 'wallet';
  final _paymentService = PaymentService();''')

# 3. initState & dispose
init_code = '''
  @override
  void initState() {
    super.initState();
    _paymentService.onSuccess = _handlePaymentSuccess;
    _paymentService.onFailure = _handlePaymentError;
    _loadData();
  }
'''
content = re.sub(r'  @override\s*void initState\(\) \{\s*super\.initState\(\);\s*_loadData\(\);\s*\}', init_code.strip() + '\n', content)

dispose_code = '''
  @override
  void dispose() {
    _paymentService.dispose();
    _nameCtrl.dispose();
'''
content = content.replace('''  @override
  void dispose() {
    _nameCtrl.dispose();''', dispose_code)

# 4. _handlePaymentCallbacks
callbacks = '''
  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    _finalizeOrder('razorpay');
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (mounted) {
      setState(() => _isPlacing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment failed: '), backgroundColor: Colors.red),
      );
    }
  }

'''
content = content.replace('  Future<void> _placeOrder() async {', callbacks + '  Future<void> _placeOrder() async {')

# 5. Place order modifications
place_order_code = '''
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

      if (_selectedPaymentMethod == 'wallet') {
        if (_walletBalance < _verifiedTotal) {
          if (!mounted) return;
          setState(() => _isPlacing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Insufficient wallet balance (\u20B9). Need \u20B9.'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        // Debit wallet first
        final debited = await _walletService.payFromWallet(_verifiedTotal, 'split_order_');
        if (!debited) throw Exception('Wallet debit failed');
        await _finalizeOrder('wallet');
      } else {
        _paymentService.openCheckout(
          amount: _verifiedTotal,
          kitchenName: 'Ghar Ka Khana',
          userEmail: user.email ?? 'customer@example.com',
          userPhone: user.phone ?? user.userMetadata?['phone'] ?? '9999999999',
          description: 'Food Order Checkout',
          notes: {
            'order_type': 'split_order',
            'user_id': user.id,
          },
        );
      }
    } catch (e) {
      debugPrint('CheckoutScreen: placeOrder error: ');
      if (!mounted) return;
      setState(() => _isPlacing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order failed: '), backgroundColor: Colors.red),
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
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'pincode': _pincodeCtrl.text.trim(),
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
'''

# The rest of _placeOrder body replacing:
content = re.sub(r'  Future<void> _placeOrder\(\) async \{.*?\s*// Call atomic RPC', place_order_code + '\n      // Call atomic RPC', content, flags=re.DOTALL)

content = content.replace("'p_payment_method': _payWithWallet ? 'wallet' : 'razorpay',", "'p_payment_method': paymentMethod,")

content = re.sub(r'// Success — clear cart and navigate\s*CartService\.instance\.clearCart\(\);\s*', '''// Success — clear cart and navigate
      CartService.instance.clearCart();
      setState(() => _isPlacing = false);
''', content)

content = re.sub(r'  Widget _buildPaymentToggle\(\) \{.*?\n  \}', '''
  Widget _buildPaymentToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)],
      ),
      child: Column(
        children: [
          _buildPaymentTile('wallet', 'Ghar Ka Khana Wallet', Icons.account_balance_wallet, subtitle: _walletBalance < _verifiedTotal ? 'Insufficient balance (\u20B9)' : 'Balance: \u20B9'),
          const Divider(height: 1),
          _buildPaymentTile('gpay', 'Google Pay', Icons.g_mobiledata, logoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c5/Google_Pay_%28GPay%29_Logo_%282020%29.svg/512px-Google_Pay_%28GPay%29_Logo_%282020%29.svg.png'),
          const Divider(height: 1),
          _buildPaymentTile('phonepe', 'PhonePe', Icons.payment, logoUrl: 'https://download.logo.wine/logo/PhonePe/PhonePe-Logo.wine.png'),
          const Divider(height: 1),
          _buildPaymentTile('paytm', 'Paytm', Icons.account_balance_wallet, logoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/cd/Paytm_logo.svg/512px-Paytm_logo.svg.png'),
          const Divider(height: 1),
          _buildPaymentTile('razorpay', 'Credit / Debit Cards & Netbanking', Icons.credit_card),
        ],
      ),
    );
  }

  Widget _buildPaymentTile(String val, String title, IconData fallbackIcon, {String? subtitle, String? logoUrl}) {
    final isSelected = _selectedPaymentMethod == val;
    return InkWell(
      onTap: () => setState(() => _selectedPaymentMethod = val),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: logoUrl != null && logoUrl.isNotEmpty
                  ? Image.network(
                      logoUrl,
                      errorBuilder: (ctx, err, stack) => Icon(fallbackIcon, color: Colors.grey.shade700),
                    )
                  : Icon(fallbackIcon, color: Colors.grey.shade700),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                  if (subtitle != null)
                    Text(subtitle, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: subtitle.contains('Insufficient') ? Colors.red : Colors.grey.shade600))
                ],
              ),
            ),
            Radio<String>(
              value: val,
              groupValue: _selectedPaymentMethod,
              onChanged: (v) => setState(() => _selectedPaymentMethod = v!),
              activeColor: const Color(0xFF16A34A),
            ),
          ],
        ),
      ),
    );
  }
''', content, flags=re.DOTALL)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Checkout Screen Updated!")
