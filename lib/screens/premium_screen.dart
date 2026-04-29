import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../services/payment_service.dart';
import '../services/subscription_service.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final _paymentService = PaymentService();
  final _subscriptionService = SubscriptionService();
  bool _isProcessing = false;
  int _selectedPlanIndex = 1; // Default to 15 days (most popular)

  // Active subscription state
  List<Map<String, dynamic>> _activeSubscriptions = [];
  bool _isLoadingSubs = true;

  final List<Map<String, dynamic>> _plans = [
    {
      'days': 7,
      'title': 'Weekly Tiffin',
      'subtitle': 'Perfect for trying out',
      'price': 699,
      'perMeal': 99,
      'color': const Color(0xFF3B82F6),
      'icon': Icons.calendar_view_week_rounded,
      'popular': false,
      'savings': '5%',
    },
    {
      'days': 15,
      'title': 'Half-Month Plan',
      'subtitle': 'Best value for regulars',
      'price': 1349,
      'perMeal': 89,
      'color': const Color(0xFF16A34A),
      'icon': Icons.calendar_month_rounded,
      'popular': true,
      'savings': '15%',
    },
    {
      'days': 30,
      'title': 'Monthly Mega',
      'subtitle': 'Maximum savings',
      'price': 2499,
      'perMeal': 83,
      'color': const Color(0xFFEAB308),
      'icon': Icons.star_rounded,
      'popular': false,
      'savings': '22%',
    },
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _setupPaymentHandlers();
    _loadActiveSubscriptions();
  }

  Future<void> _loadActiveSubscriptions() async {
    setState(() => _isLoadingSubs = true);
    try {
      final subs = await _subscriptionService.getActiveSubscriptions();
      if (mounted) {
        setState(() {
          _activeSubscriptions = subs;
          _isLoadingSubs = false;
        });
      }
    } catch (e) {
      debugPrint('PremiumScreen: Failed to load subs: $e');
      if (mounted) setState(() => _isLoadingSubs = false);
    }
  }

  void _setupPaymentHandlers() {
    _paymentService.onSuccess = (PaymentSuccessResponse response) async {
      final plan = _plans[_selectedPlanIndex];
      try {
        await _subscriptionService.createSubscription(
          planName: plan['title'],
          days: plan['days'],
          price: (plan['price'] as int).toDouble(),
          perMealPrice: (plan['perMeal'] as int).toDouble(),
          paymentId: response.paymentId ?? 'unknown',
        );

        await _loadActiveSubscriptions();

        if (mounted) {
          setState(() => _isProcessing = false);
          _showSuccessDialog(plan);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Subscription failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    };

    _paymentService.onFailure = (PaymentFailureResponse response) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message ?? 'Payment failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    };
  }

  void _handleSubscribe() {
    final plan = _plans[_selectedPlanIndex];
    final user = Supabase.instance.client.auth.currentUser;

    setState(() => _isProcessing = true);

    _paymentService.openCheckout(
      amount: (plan['price'] as int).toDouble(),
      kitchenName: 'GKK Tiffin Subscription',
      userEmail: user?.email ?? 'customer@example.com',
      userPhone:
          user?.phone ?? user?.userMetadata?['phone'] ?? '9999999999',
      description: '${plan['title']} - ${plan['days']} Days Plan',
      notes: {
        'order_type': 'tiffin_subscription',
        'plan': plan['title'],
        'days': plan['days'].toString(),
        'user_id': user?.id ?? '',
      },
    );
  }

  void _showSuccessDialog(Map<String, dynamic> plan) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withOpacity( 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF16A34A), size: 56),
            ),
            const SizedBox(height: 20),
            Text(
              'Subscribed! 🎉',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your ${plan['title']} (${plan['days']} days) is now active.\nEnjoy fresh home-cooked meals daily!',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  'Got it!',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _paymentService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedPlan = _plans[_selectedPlanIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Text(
          'Tiffin Subscriptions',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF121712),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  Lottie.network(
                    'https://assets10.lottiefiles.com/packages/lf20_m6cuL6.json',
                    width: 160,
                    height: 160,
                    repeat: true,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.lunch_dining,
                        size: 80,
                        color: Color(0xFF16A34A)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ghar Ka Khana, Daily.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF121712),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Subscribe once. Enjoy fresh meals everyday.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            // Active Subscriptions
            if (!_isLoadingSubs && _activeSubscriptions.isNotEmpty) ...[
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Active Plans',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._activeSubscriptions.map((sub) => _buildActiveSubCard(sub)),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Plan Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose Your Plan',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ...List.generate(_plans.length, (index) {
                    final plan = _plans[index];
                    final isSelected = _selectedPlanIndex == index;

                    return GestureDetector(
                      onTap: () =>
                          setState(() => _selectedPlanIndex = index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (plan['color'] as Color).withOpacity( 0.05)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? plan['color'] as Color
                                : Colors.grey.shade200,
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: [
                            if (isSelected)
                              BoxShadow(
                                color: (plan['color'] as Color)
                                    .withOpacity( 0.18),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              )
                            else
                              BoxShadow(
                                color: Colors.black.withOpacity( 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                          ],
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(18),
                              child: Row(
                                children: [
                                  // Radio
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? plan['color'] as Color
                                            : Colors.grey.shade400,
                                        width: isSelected ? 6 : 2,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // Plan Icon
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: (plan['color'] as Color)
                                          .withOpacity( 0.1),
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      plan['icon'] as IconData,
                                      color: plan['color'] as Color,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          plan['title'] as String,
                                          style:
                                              GoogleFonts.plusJakartaSans(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected
                                                ? plan['color'] as Color
                                                : Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${plan['days']} days • ₹${plan['perMeal']}/meal',
                                          style:
                                              GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Price
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '₹${plan['price']}',
                                        style:
                                            GoogleFonts.plusJakartaSans(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color:
                                              const Color(0xFF16A34A)
                                                  .withOpacity( 0.1),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Save ${plan['savings']}',
                                          style:
                                              GoogleFonts.plusJakartaSans(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                const Color(0xFF16A34A),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Popular badge
                            if (plan['popular'] == true)
                              Positioned(
                                top: -10,
                                right: 20,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEAB308),
                                    borderRadius:
                                        BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFEAB308)
                                            .withOpacity( 0.4),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    'MOST POPULAR',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),

            // What you get
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Column(
                  children: [
                    _buildBenefitRow(Icons.restaurant_menu_rounded,
                        'Fresh Ghar Ka Khana daily'),
                    _buildBenefitRow(Icons.delivery_dining_rounded,
                        'Delivery included in all plans'),
                    _buildBenefitRow(
                        Icons.cancel_rounded, 'Cancel anytime, no lock-in'),
                    _buildBenefitRow(Icons.support_agent_rounded,
                        'Priority customer support'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 130), // padding for bottom bar
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity( 0.06),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Total Payable',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${selectedPlan['price']}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            '/${selectedPlan['days']} days',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _isProcessing ? 1.0 : _pulseAnimation.value,
                    child: child,
                  );
                },
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _handleSubscribe,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selectedPlan['color'] as Color,
                    disabledBackgroundColor: Colors.grey.shade400,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(
                          'Pay & Subscribe',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF16A34A), size: 20),
          const SizedBox(width: 12),
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSubCard(Map<String, dynamic> sub) {
    final endDate = DateTime.tryParse(sub['end_date'] ?? '');
    final daysLeft = endDate != null
        ? endDate.difference(DateTime.now()).inDays
        : 0;
    final mealsLeft = sub['meals_remaining'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDCFCE7), Color(0xFFF0FDF4)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: Color(0xFF16A34A), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sub['plan_name'] ?? 'Tiffin Plan',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF14532D),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$daysLeft days left • $mealsLeft meals remaining',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: const Color(0xFF166534),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'ACTIVE',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
