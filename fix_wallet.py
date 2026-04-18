import re

def fix_wallet_screen():
    path = r'd:\GKK APP\GKK ADMIN ALL APP\USER\lib\screens\my_wallet_screen.dart'
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Replace grid view with list view
    new_ui = '''
            const SizedBox(height: 32),
            Text('Pay Instantly With', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
              ),
              child: Column(
                children: [
                  _buildUpiAppListTile('Google Pay', 'com.google.android.apps.nbu.paisa.user', 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c5/Google_Pay_%28GPay%29_Logo_%282020%29.svg/512px-Google_Pay_%28GPay%29_Logo_%282020%29.svg.png', Icons.g_mobiledata),
                  const Divider(height: 1, indent: 56),
                  _buildUpiAppListTile('PhonePe', 'com.phonepe.app', 'https://download.logo.wine/logo/PhonePe/PhonePe-Logo.wine.png', Icons.payment),
                  const Divider(height: 1, indent: 56),
                  _buildUpiAppListTile('Paytm', 'net.one97.paytm', 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/cd/Paytm_logo.svg/512px-Paytm_logo.svg.png', Icons.account_balance_wallet),
                  const Divider(height: 1, indent: 56),
                  _buildUpiAppListTile('Other UPI Apps', '', '', Icons.apps),
                  const Divider(height: 1, indent: 56),
                  _buildUpiAppListTile('Cards / Netbanking', '', '', Icons.credit_card),
                ],
              ),
            ),
'''

    content = re.sub(r'const SizedBox\(height: 32\),\s*Text\(\'Pay Instantly With\'.*?GridView\.count\(.*?\]\s*,\s*\),', new_ui.strip(), content, flags=re.DOTALL)

    # replace _buildUpiAppButton with _buildUpiAppListTile
    new_tile = '''
  Widget _buildUpiAppListTile(String name, String pkg, String logoUrl, IconData fallbackIcon) {
    return InkWell(
      onTap: () => _triggerPaymentIntent(pkg, name),
      borderRadius: BorderRadius.circular(16),
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
              child: logoUrl.isNotEmpty
                  ? Image.network(
                      logoUrl,
                      errorBuilder: (ctx, err, stack) => Icon(fallbackIcon, color: Colors.grey.shade700),
                    )
                  : Icon(fallbackIcon, color: Colors.grey.shade700),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(name, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
'''
    content = re.sub(r'Widget _buildUpiAppButton.*?\}\s*\}', new_tile.strip() + '\n\n  void _showAddMoneySheet', content, flags=re.DOTALL)
    
    # Remove upiPackageName condition to fix Razorpay testing mode
    content = re.sub(r'if \(appPackageName\.isNotEmpty\) \{.*?\}', '', content, flags=re.DOTALL)

    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

fix_wallet_screen()
print('Wallet screen updated.')
