import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import 'my_wallet_screen.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.walletBgLight,
      body: SafeArea(
        child: Column(
          children: [
            // Sticky Header
            _buildHeader(context),
            
            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroCard(),
                    _buildExtraWalletButton(context),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Active Subscription'),
                    const SizedBox(height: 12),
                    _buildSubscriptionCard(),
                    const SizedBox(height: 24),
                    _buildDailyCreditCard(),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Meal Costs (Per Plate)'),
                    const SizedBox(height: 12),
                    _buildMealCostsCard(),
                    const SizedBox(height: 24),
                    _buildTransactionHeader(),
                    const SizedBox(height: 12),
                    _buildTransactionList(),
                    const SizedBox(height: 24),
                    _buildHowItWorksCard(),
                    const SizedBox(height: 24),
                    _buildActionButtons(),
                  ],
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
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
                border: Border.all(color: Colors.transparent),
              ),
              child: const Icon(Icons.arrow_back, color: Color(0xFF121712)),
            ),
          ),
          Column(
            children: [
              Text(
                'Wallet',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF121712),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.walletPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Home Tokens',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.walletPrimary,
                  ),
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: () => _showHowItWorksModal(context),
            icon: const Icon(Icons.info_outline, color: Color(0xFF121712)),
          ),
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
      child: Column(
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
            'Total Home Token Balance',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '₹3,240',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Text(
              'Safe & ready for your daily meals & subscriptions',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white.withOpacity(0.8),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtraWalletButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MyWalletScreen()),
        );
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
                    'My Cash Wallet',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    'Add money for one-time orders',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: Colors.grey.shade500,
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
                'View',
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

  Widget _buildSubscriptionCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                height: 100,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  image: DecorationImage(
                    image: NetworkImage('https://lh3.googleusercontent.com/aida-public/AB6AXuDS0BD3-8uc_Qrb7yIEKjRtVBOU14QLEfRS8zWC2i53Xi2W7ye8FWUdscyqfNw9xk-e7vVPSDWvJcDBnDEjk4C96sm3Tj-5gpR0FNUcg4co_npeBMPP64dlmaZSMz10qwbZO58vbOLBU4k0xcgbrZwF-Nx2wIBPQ5MJqKMp9UJ5ZRoMMlJJ-rvgLwtZyYW5-_KMHQCgVVLpcwdf0ZkilqYWiUYgod8C7zlqZl761TtwfyGcCnZZzDtiYwJkrvyXKxtSMUgrVPM25BC-'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: AppColors.walletPrimary, shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      Text(
                        'ACTIVE',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.walletPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Aunty's Kitchen",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF121712),
                          ),
                        ),
                        Text(
                          "Monthly Thali Plan",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "₹5000",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.walletPrimary,
                          ),
                        ),
                        Text(
                          "/ month",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildTag('Breakfast'),
                    const SizedBox(width: 8),
                    _buildTag('Lunch'),
                    const SizedBox(width: 8),
                    _buildTag('Dinner'),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.currency_rupee, size: 16, color: AppColors.walletSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        "Your ₹5000 is converted into Home Tokens and credited to your wallet daily in small parts.",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyCreditCard() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle('Daily Token Credit'),
            Text('Calculation', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade50, Colors.lime.shade50],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.walletPrimary.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: Icon(Icons.calendar_today, color: AppColors.walletPrimary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tokens added daily',
                            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey.shade600),
                          ),
                          RichText(
                            text: TextSpan(
                              style: GoogleFonts.plusJakartaSans(color: const Color(0xFF121712)),
                              children: [
                                TextSpan(text: '₹166.67', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                TextSpan(text: ' / day', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.walletPrimary, borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      'TODAY ADDED',
                      style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.walletPrimary.withOpacity(0.1)),
                ),
                child: Text(
                  '₹5000 (Plan) ÷ 30 Days = ₹166.67 Daily Credit',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMealCostsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _buildMealRow(Icons.bakery_dining, 'Breakfast', '₹40 Tokens'),
          const Divider(height: 1),
          _buildMealRow(Icons.rice_bowl, 'Lunch', '₹70 Tokens'),
          const Divider(height: 1),
          _buildMealRow(Icons.dinner_dining, 'Dinner', '₹55 Tokens'),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(Icons.verified_user, size: 16, color: Colors.grey.shade400),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey.shade500),
                      children: [
                        const TextSpan(text: 'Trust Guarantee: Tokens are transferred to the kitchen '),
                        TextSpan(
                          text: 'only after successful delivery.',
                          style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealRow(IconData icon, String name, String price) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.walletSecondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: AppColors.walletSecondary),
              ),
              const SizedBox(width: 12),
              Text(
                name,
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500, color: const Color(0xFF121712)),
              ),
            ],
          ),
          Text(
            price,
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: AppColors.walletSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildSectionTitle('Wallet Activity'),
        Text(
          'View All',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.walletPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionList() {
    return Column(
      children: [
        _buildTransactionItem(
          icon: Icons.add_circle,
          iconColor: AppColors.walletPrimary,
          bgColor: Colors.green.shade50,
          title: 'Daily Token Credit',
          subtitle: 'Today, 6:00 AM',
          amount: '+₹166.67',
          amountColor: AppColors.walletPrimary,
        ),
        const SizedBox(height: 12),
        _buildTransactionItem(
          icon: Icons.remove_circle,
          iconColor: AppColors.walletSecondary,
          bgColor: Colors.orange.shade50,
          title: "Lunch - Aunty's Kitchen",
          subtitle: 'Yesterday, 1:30 PM',
          amount: '-₹70.00',
          amountColor: AppColors.walletSecondary,
        ),
        const SizedBox(height: 12),
        _buildTransactionItem(
          icon: Icons.remove_circle,
          iconColor: AppColors.walletSecondary,
          bgColor: Colors.orange.shade50,
          title: "Breakfast - Aunty's Kitchen",
          subtitle: 'Yesterday, 8:30 AM',
          amount: '-₹40.00',
          amountColor: AppColors.walletSecondary,
        ),
      ],
    );
  }
  
  Widget _buildTransactionItem({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
    required String amount,
    required Color amountColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF121712)),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey.shade400),
                  ),
                ],
              ),
            ],
          ),
          Text(
            amount,
            style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: amountColor),
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
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Text(
            'How Home Tokens Work',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF121712)),
          ),
          const SizedBox(height: 16),
          Stack(
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: 14,
                left: 20,
                right: 20,
                child: Container(height: 2, color: Colors.grey.shade300),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStep(1, 'Subscribe & Pay\nMonthly', AppColors.walletPrimary),
                  _buildStep(2, 'Tokens Added\nDaily', AppColors.walletPrimary),
                  _buildStep(3, 'Pay Kitchen After\nDelivery', AppColors.walletSecondary),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep(int number, String text, Color color) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
          ),
          child: Center(
            child: Text(
              number.toString(),
              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.grey.shade600, height: 1.2),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: Icon(Icons.settings, color: AppColors.walletPrimary),
            label: Text('Manage Plans', style: TextStyle(color: AppColors.walletPrimary)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: AppColors.walletPrimary, width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.support_agent, color: Colors.grey),
            label: Text('Help & Support', style: TextStyle(color: Colors.grey.shade700)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: Colors.grey.shade300, width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.grey.shade600),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF121712),
      ),
    );
  }
  void _showHowItWorksModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                width: 48,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'How Home Tokens Work',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF121712),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  // Hero Icon
                  Center(
                    child: Container(
                      width: 96,
                      height: 96,
                      margin: const EdgeInsets.symmetric(vertical: 24),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(Icons.account_balance_wallet, size: 48, color: AppColors.walletPrimary),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.walletSecondary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.currency_rupee, size: 14, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Steps
                  _buildModalStep(
                    icon: Icons.home_work,
                    iconColor: AppColors.walletPrimary,
                    title: 'Subscribe to a Kitchen',
                    description: 'Choose your favorite kitchen\'s plan and subscribe monthly. Your payment is securely converted into Home Tokens.',
                    isLast: false,
                  ),
                  _buildModalStep(
                    icon: Icons.calendar_today,
                    iconColor: const Color(0xFF2DA832),
                    title: 'Tokens Added Daily',
                    description: 'Each day, a portion of your subscription amount is automatically credited to your wallet as Home Tokens.',
                    isLast: false,
                  ),
                  _buildModalStep(
                    icon: Icons.soup_kitchen,
                    iconColor: AppColors.walletSecondary,
                    title: 'Pay Per Meal Automatically',
                    description: 'Tokens are debited only after a successful meal delivery. The kitchen gets paid, and you enjoy Ghar Ka Khana!',
                    isLast: true,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Trust Badge
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.verified_user, color: Color(0xFF2DA832), size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Fairness Guarantee',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF121712),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'If a meal is skipped or cancelled, your tokens remain safe in your wallet.',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
            
            // Footer Button
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.walletPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                    shadowColor: AppColors.walletPrimary.withOpacity(0.4),
                  ),
                  child: Text(
                    'Got it',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModalStep({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: iconColor.withOpacity(0.2)),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Colors.grey.shade200,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF121712),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
