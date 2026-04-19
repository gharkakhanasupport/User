import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../services/wallet_service.dart';
import '../services/payment_service.dart';

class MyWalletScreen extends StatefulWidget {
  const MyWalletScreen({super.key});

  @override
  State<MyWalletScreen> createState() => _MyWalletScreenState();
}

class _MyWalletScreenState extends State<MyWalletScreen> {
  final _walletService = WalletService();
  final _paymentService = PaymentService();
  double _balance = 0.0;
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;
  bool _isProcessingPayment = false;
  double _pendingAddAmount = 0;
  String? _walletId;
  final TextEditingController _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _paymentService.onSuccess = _onPaymentSuccess;
    _paymentService.onFailure = _onPaymentError;
    _paymentService.onExternalWallet = (response) {
      if (mounted) setState(() => _isProcessingPayment = false);
    };
    _loadWallet();
  }

  @override
  void dispose() {
    _paymentService.dispose();
    super.dispose();
  }

  Future<void> _loadWallet() async {
    setState(() => _isLoading = true);
    await _walletService.ensureWalletExists();
    final balance = await _walletService.getBalance();
    final transactions = await _walletService.getTransactions();
    final walletId = await _walletService.getWalletId();
    if (mounted) {
      setState(() {
        _balance = balance;
        _transactions = transactions;
        _walletId = walletId;
        _isLoading = false;
      });
    }
  }

  void _onPaymentSuccess(PaymentSuccessResponse response) async {
    if (mounted) setState(() => _isProcessingPayment = false);
    
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
    if (mounted) setState(() => _isProcessingPayment = false);
    debugPrint('Razorpay Payment ERROR: code=${response.code}, message=${response.message}');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment failed (${response.code}): ${response.message ?? "Unknown error"}'), backgroundColor: Colors.red),
      );
    }
  }

  void _startPaymentFlow() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter an amount')));
      return;
    }

    final amount = double.tryParse(amountText) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid amount')));
      return;
    }

    Navigator.pop(context); // Close bottom sheet
    setState(() {
      _isProcessingPayment = true;
      _pendingAddAmount = amount;
    });

    try {
      await _paymentService.openCheckout(
        amount: amount,
        kitchenName: 'Ghar Ka Khana',
        userEmail: 'user@gharkakhana.com',
        userPhone: '',
        description: 'Add Rs.${amount.toStringAsFixed(0)} to GKK Wallet',
        notes: {
          'order_type': 'top_up',
          'wallet_id': _walletId ?? '',
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment failed: $e')));
        setState(() => _isProcessingPayment = false);
      }
    } finally {
      // Note: _isProcessingPayment is set to false in onPaymentSuccess/Error or finally if catch hits
      if (mounted && !_isProcessingPayment) setState(() {}); 
    }
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
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startPaymentFlow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text('Proceed to Pay', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shield_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text('Secure 128-bit SSL Payment', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey)),
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
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF16A34A)))
              : RefreshIndicator(
                  onRefresh: _loadWallet,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Wallet Balance Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF16A34A), Color(0xFF15803D)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF16A34A).withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Available Balance',
                                    style: GoogleFonts.plusJakartaSans(color: Colors.white.withValues(alpha: 0.8), fontSize: 14, fontWeight: FontWeight.w500),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(100)),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.security, size: 12, color: Colors.white),
                                        const SizedBox(width: 4),
                                        Text('Secure', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '\u20B9${_balance.toStringAsFixed(2)}',
                                style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
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
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.add, size: 18, color: Color(0xFF16A34A)),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Add Money',
                                              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A)),
                                            ),
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
                        Text(
                          'Transaction History',
                          style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                        ),
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
                                Text(
                                  'No transactions yet',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Add money to get started',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.grey.shade400),
                                ),
                              ],
                            ),
                          )
                        else
                          ...List.generate(_transactions.length, (i) => _buildTransactionTile(_transactions[i])),
                      ],
                    ),
                  ),
                ),
          if (_isProcessingPayment)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Color(0xFF16A34A)),
                      const SizedBox(height: 16),
                      Text('Setting up payment...', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                      const SizedBox(height: 4),
                      Text('Please do not go back', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ),
        ],
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
