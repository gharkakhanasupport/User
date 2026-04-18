import re

path = r'd:\GKK APP\GKK ADMIN ALL APP\USER\lib\screens\cart_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Update vars
content = content.replace('bool _payWithWallet = true; // true=wallet, false=direct Razorpay', 
'''String _selectedPaymentMethod = 'wallet';''')

# 2. _handlePayment logic update
handle_pay_new = '''
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
'''

content = re.sub(r'  Future<void> _handlePayment\(int grandTotal\) async \{.*?    \}\n  \}', handle_pay_new.strip(), content, flags=re.DOTALL)


# 3. Replace Payment Method Selector in UI
payment_ui = '''
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        _buildPaymentTile('wallet', 'Ghar Ka Khana Wallet', Icons.account_balance_wallet, subtitle: _walletBalance < grandTotal ? 'Insufficient balance' : 'Balance: \u20B9'),
                        const Divider(height: 1),
                        _buildPaymentTile('gpay', 'Google Pay', Icons.g_mobiledata, logoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c5/Google_Pay_%28GPay%29_Logo_%282020%29.svg/512px-Google_Pay_%28GPay%29_Logo_%282020%29.svg.png'),
                        const Divider(height: 1),
                        _buildPaymentTile('phonepe', 'PhonePe', Icons.payment, logoUrl: 'https://download.logo.wine/logo/PhonePe/PhonePe-Logo.wine.png'),
                        const Divider(height: 1),
                        _buildPaymentTile('paytm', 'Paytm', Icons.account_balance_wallet, logoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/cd/Paytm_logo.svg/512px-Paytm_logo.svg.png'),
                        const Divider(height: 1),
                        _buildPaymentTile('razorpay', 'Credit / Debit Cards & Others', Icons.credit_card),
                      ],
                    ),
                  ),
'''

content = re.sub(r'                  // Payment method selector\s*Row\(.*\),.*\),.*\],.*\),.*\),.*\n.*\n.*\n.*\n.*\n.*\n.*\n.*\n.*\n.*\n.*\n.*\n.*\n.*\n.*\n.*\n.*\n.*\n.*\n.*\n.*\n.*\n.*\n.*\n.*\n.*\n.*\n.*\n.*\n.*\n.*\n.*\n.*\n.*\n.*\n.*\n.*\n.*\n.*\n.*\n.*\n.*\n.*\n.*\n', payment_ui, content)

# 4. Add _buildPaymentTile method safely to the end of _buildBody
build_tile = '''
  Widget _buildPaymentTile(String val, String title, IconData fallbackIcon, {String? subtitle, String? logoUrl}) {
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
              child: logoUrl != null && logoUrl.isNotEmpty
                  ? Image.network(
                      logoUrl,
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
            Radio<String>(
              value: val,
              groupValue: _selectedPaymentMethod,
              onChanged: (v) => setState(() => _selectedPaymentMethod = v!),
              activeColor: const Color(0xFF16A34A),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
'''
content = re.sub(r'\}\s*$', build_tile, content)

# replace instances of _payWithWallet in build
content = content.replace('!_payWithWallet', "(_selectedPaymentMethod != 'wallet')")
content = content.replace('_payWithWallet', "(_selectedPaymentMethod == 'wallet')")


with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Cart Screen Updated!")
