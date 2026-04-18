import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/wallet_service.dart';

class MyWalletScreen extends StatefulWidget {
  const MyWalletScreen({super.key});

  @override
  State<MyWalletScreen> createState() => _MyWalletScreenState();
}

class _MyWalletScreenState extends State<MyWalletScreen> {
  final _walletService = WalletService();
  late Razorpay _razorpay;
  double _balance = 0.0;
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;
  double _pendingAddAmount = 0;
  final TextEditingController _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (_) {});
    _loadWallet();
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _loadWallet() async {
    setState(() => _isLoading = true);
    await _walletService.ensureWalletExists();
    final balance = await _walletService.getBalance();
    final transactions = await _walletService.getTransactions();
    if (mounted) {
      setState(() {
        _balance = balance;
        _transactions = transactions;
        _isLoading = false;
      });
    }
  }

  void _onPaymentSuccess(PaymentSuccessResponse response) async {
    final success = await _walletService.addMoney(_pendingAddAmount, response.paymentId ?? 'unknown');
    if (success && mounted) {
      _loadWallet();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('\u20B9${_pendingAddAmount.toStringAsFixed(0)} added to wallet!'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
    }
  }

  void _onPaymentError(PaymentFailureResponse response) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment failed: ${response.message}'), backgroundColor: Colors.red),
      );
    }
  }

  void _triggerPaymentIntent(String appPackageName, String appName) {
    Navigator.pop(context); // Close sheet
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount'), backgroundColor: Colors.red),
      );
      return;
    }
    _pendingAddAmount = amount;
    
    // Razorpay standard payload with UPI prefill and specific app intent
    var options = {
      'key': (() { try { return dotenv.env['RAZORPAY_API_KEY'] ?? 'rzp_test_ScbcaPgSgcDyMe'; } catch (_) { return 'rzp_test_ScbcaPgSgcDyMe'; } })(),
      'amount': (amount * 100).toInt(),
      'name': 'GKK Wallet',
      'description': 'Add money to wallet',
      'theme': {'color': '#16A34A'},
      'method': {
        'upi': true,
        'netbanking': false,
        'card': false,
        'wallet': false,
        'emi': false
      },
      'prefill': {
         'method': 'upi',
      },
      // App-specific intent configuration if applicable (Razorpay parses some of these automatically)
      '_[upi_app_package_name]': appPackageName.isEmpty ? null : appPackageName,
      'app': appPackageName.isEmpty ? null : appPackageName
    };
    
    // Clean nulls
    options.removeWhere((key, value) => value == null);

    _razorpay.open(options);
  }

  Widget _buildUpiAppButton(String name, String pkg, IconData icon, Color color) {
    return GestureDetector(
      onTap: () => _triggerPaymentIntent(pkg, name),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(name, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  void _showAddMoneySheet() {
    _amountController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 24, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Top-Up Wallet', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B))),
            Text('Quick, secure and zero fees', style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.grey.shade500)),
            const SizedBox(height: 24),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                prefixText: '\u20B9 ',
                hintText: 'Enter amount',
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF16A34A), width: 2)),
              ),
              style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              children: [100, 200, 500, 1000].map((amt) => ActionChip(
                label: Text('+\u20B9$amt'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                onPressed: () => _amountController.text = amt.toString(),
              )).toList(),
            ),
            const SizedBox(height: 32),
            Text('Pay Instantly With', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildUpiAppButton('GPay', 'com.google.android.apps.nbu.paisa.user', Icons.g_mobiledata, Colors.blue.shade700),
                _buildUpiAppButton('PhonePe', 'com.phonepe.app', Icons.payment, Colors.purple),
                _buildUpiAppButton('Paytm', 'net.one97.paytm', Icons.account_balance_wallet, Colors.lightBlue),
                _buildUpiAppButton('BHIM', 'in.org.npci.upiapp', Icons.security, Colors.green.shade700),
                _buildUpiAppButton('Cred', 'com.dreamplug.androidapp', Icons.credit_card, Colors.black87),
                _buildUpiAppButton('Other UPI', '', Icons.apps, Colors.grey.shade700),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('My Wallet', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF16A34A)))
          : RefreshIndicator(
              onRefresh: _loadWallet,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Balance Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF1E293B), Color(0xFF334155)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 10))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), shape: BoxShape.circle),
                                child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 24),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                                child: Text('GKK Wallet', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text('Available Balance', style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.white.withValues(alpha: 0.7))),
                          const SizedBox(height: 4),
                          StreamBuilder<double>(
                            stream: _walletService.getBalanceStream(),
                            initialData: _balance,
                            builder: (context, snapshot) {
                              final bal = snapshot.data ?? _balance;
                              return Text(
                                '\u20B9 ${bal.toStringAsFixed(2)}',
                                style: GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -1),
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: _showAddMoneySheet,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF16A34A),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.add, size: 18, color: Colors.white),
                                        const SizedBox(width: 8),
                                        Text('Add Money', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Transaction History
                    Text('Transaction History', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                    const SizedBox(height: 16),

                    if (_transactions.isEmpty)
                      Center(
                        child: Column(
                          children: [
                            const SizedBox(height: 40),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                              child: Icon(Icons.history, size: 48, color: Colors.grey.shade400),
                            ),
                            const SizedBox(height: 16),
                            Text('No transactions yet', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                            const SizedBox(height: 8),
                            Text('Add money to get started', style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.grey.shade400)),
                          ],
                        ),
                      )
                    else
                      ...List.generate(_transactions.length, (i) => _buildTransactionTile(_transactions[i])),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTransactionTile(Map<String, dynamic> txn) {
    final type = txn['transaction_type'] ?? '';
    final amount = (txn['amount'] ?? 0).toDouble();
    final description = txn['description'] ?? type;
    final createdAt = DateTime.tryParse(txn['created_at'] ?? '');

    IconData icon;
    Color color;
    String prefix;
    switch (type) {
      case 'top_up':
        icon = Icons.arrow_downward_rounded;
        color = const Color(0xFF16A34A);
        prefix = '+';
        break;
      case 'order_payment':
        icon = Icons.arrow_upward_rounded;
        color = Colors.red;
        prefix = '-';
        break;
      case 'refund':
        icon = Icons.replay_rounded;
        color = Colors.blue;
        prefix = '+';
        break;
      default:
        icon = Icons.swap_horiz;
        color = Colors.grey;
        prefix = '';
    }

    String timeStr = '';
    if (createdAt != null) {
      final diff = DateTime.now().difference(createdAt);
      if (diff.inMinutes < 60) {
        timeStr = '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        timeStr = '${diff.inHours}h ago';
      } else {
        timeStr = '${createdAt.day}/${createdAt.month}/${createdAt.year}';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(description, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600)),
                if (timeStr.isNotEmpty)
                  Text(timeStr, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Text(
            '$prefix\u20B9${amount.toStringAsFixed(0)}',
            style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
