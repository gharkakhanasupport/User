import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import 'my_wallet_screen.dart';
import '../services/wallet_service.dart';
import '../core/localization.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  Locale? _lastLocale;
  bool _isLoading = true;
  final WalletService _walletService = WalletService();
  double _walletBalance = 0.0;
  List<Map<String, dynamic>> _transactions = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newLocale = Localizations.localeOf(context);
    if (_lastLocale != null && _lastLocale != newLocale) {
      if (mounted) setState(() {});
    }
    _lastLocale = newLocale;
  }


  @override
  void initState() {
    super.initState();
    _loadWalletData();
  }

  Future<void> _loadWalletData() async {
    setState(() => _isLoading = true);
    final bal = await _walletService.getBalance();
    final txns = await _walletService.getTransactions();
    if (mounted) {
      setState(() {
        _walletBalance = bal;
        _transactions = txns;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.walletBgLight,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadWalletData,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeroCard(),
                            const SizedBox(height: 16),
                            _buildActionButtons(context),
                            _buildExtraWalletButton(context),
                            const SizedBox(height: 24),
                            _buildSectionTitle('recent_transactions'.tr(context)),
                            const SizedBox(height: 12),
                            _buildTransactionsList(),
                            const SizedBox(height: 24),
                            _buildHowItWorksCard(),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 48),
          Text(
            'wallet'.tr(context),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF121712),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.walletPrimary, AppColors.walletSecondary],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.walletPrimary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: StreamBuilder<double>(
        stream: _walletService.getBalanceStream(),
        initialData: _walletBalance,
        builder: (context, snapshot) {
          final balance = snapshot.data ?? _walletBalance;
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                'wallet_balance_title'.tr(context),
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '\u20B9${balance.toStringAsFixed(2)}',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Text(
                  'use_wallet_desc'.tr(context),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            icon: Icons.add_circle_outline,
            label: 'add_money'.tr(context),
            color: AppColors.walletPrimary,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyWalletScreen()),
              );
              _loadWalletData();
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            icon: Icons.history,
            label: 'all_transactions'.tr(context),
            color: const Color(0xFF1E293B),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyWalletScreen()),
              );
              _loadWalletData();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExtraWalletButton(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MyWalletScreen()),
        );
        _loadWalletData();
      },
      child: Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wallet, color: Color(0xFF1E293B)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'my_cash_wallet'.tr(context),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    'manage_wallet_desc'.tr(context),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'view'.tr(context),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsList() {
    if (_transactions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              Icon(Icons.receipt_long, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text(
                'no_transactions'.tr(context),
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.grey.shade500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'add_money_desc'.tr(context),
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.grey.shade400,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Show latest 5 transactions
    final recentTxns = _transactions.take(5).toList();
    return Column(
      children: [
        ...recentTxns.map((txn) => _buildTransactionCard(txn)),
        if (_transactions.length > 5)
          GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyWalletScreen()),
              );
              _loadWalletData();
            },
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                "${'view_all_txns'.tr(context).replaceAll('%s', _transactions.length.toString())} \u2192",
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.walletPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> txn) {
    final type = txn['transaction_type'] ?? '';
    final amount = (txn['amount'] ?? 0.0).toDouble();
    final createdAt = txn['created_at'];
    String dateStr = '';
    if (createdAt != null) {
      final date = DateTime.tryParse(createdAt.toString());
      if (date != null) {
        final now = DateTime.now();
        if (date.year == now.year && date.month == now.month && date.day == now.day) {
          dateStr = '${'today_at'.tr(context)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
        } else {
          dateStr = '${date.day}/${date.month}/${date.year}';
        }
      }
    }

    IconData icon;
    Color iconColor;
    Color bgColor;
    String prefix;

    switch (type) {
      case 'top_up':
        icon = Icons.add_circle;
        iconColor = Colors.green;
        bgColor = Colors.green.shade50;
        prefix = '+';
        break;
      case 'order_payment':
        icon = Icons.shopping_bag;
        iconColor = Colors.red;
        bgColor = Colors.red.shade50;
        prefix = '-';
        break;
      case 'cod_payment':
        icon = Icons.payments_rounded;
        iconColor = Colors.orange.shade700;
        bgColor = Colors.orange.shade50;
        prefix = '';
        break;
      case 'online_payment':
        icon = Icons.credit_card_rounded;
        iconColor = Colors.blue.shade700;
        bgColor = Colors.blue.shade50;
        prefix = '';
        break;
      case 'refund':
        icon = Icons.replay;
        iconColor = Colors.blue;
        bgColor = Colors.blue.shade50;
        prefix = '+';
        break;
      default:
        icon = Icons.swap_horiz;
        iconColor = Colors.grey;
        bgColor = Colors.grey.shade50;
        prefix = '';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (txn['description'] ?? type).toString().tr(context),
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: const Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (dateStr.isNotEmpty)
                  Text(
                    dateStr,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '$prefix\u20B9${amount.toStringAsFixed(0)}',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: prefix == '+' ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorksCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text('how_it_works'.tr(context),
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStep(1, 'step_add_money'.tr(context)),
              _buildStep(2, 'step_order_food'.tr(context)),
              _buildStep(3, 'step_pay_instantly'.tr(context)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep(int num, String text) {
    return Column(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: AppColors.walletPrimary,
          child: Text(num.toString(),
              style: const TextStyle(fontSize: 10, color: Colors.white)),
        ),
        const SizedBox(height: 4),
        Text(text, style: const TextStyle(fontSize: 10)),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold));
  }
}
